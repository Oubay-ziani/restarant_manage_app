import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../../tables/providers/tables_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../menu/providers/menu_provider.dart';

class OrdersRepository {
  final FirestoreService _firestoreService;
  static const String _collectionPath = 'orders';

  OrdersRepository(this._firestoreService);

  // Stream active unpaid orders for a specific table
  Stream<List<OrderModel>> streamActiveTableOrders(int tableNumber) {
    return _firestoreService.streamCollection<OrderModel>(
      collectionPath: _collectionPath,
      builder: (data, id) => OrderModel.fromMap(data, id),
      queryBuilder: (query) => query
          .where('tableNumber', isEqualTo: tableNumber)
          .where('status', isEqualTo: 'unpaid'),
    ).map((list) {
      final sorted = List<OrderModel>.from(list);
      sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return sorted;
    });
  }

  // Stream all orders sorted by newest first
  Stream<List<OrderModel>> streamAllOrders() {
    return _firestoreService.streamCollection<OrderModel>(
      collectionPath: _collectionPath,
      builder: (data, id) => OrderModel.fromMap(data, id),
      queryBuilder: (query) => query.orderBy('timestamp', descending: true),
    );
  }

  // Generates a sequential order number e.g. 20260803-001
  Future<String> generateOrderNumber() async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    
    // Count orders created today
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection(_collectionPath)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final int sequentialNumber = snapshot.docs.length + 1;
    final String seqStr = sequentialNumber.toString().padLeft(3, '0');
    
    return '$dateStr-$seqStr';
  }

  // Create new order
  Future<String> createOrder(OrderModel order, TablesRepository tablesRepo) async {
    final orderNum = await generateOrderNumber();
    final newOrderMap = order.toMap();
    newOrderMap['orderNumber'] = orderNum;

    final docId = await _firestoreService.addDocument(
      collectionPath: _collectionPath,
      data: newOrderMap,
    );

    // Occupy table and update status
    await tablesRepo.recalculateTableStats(order.tableNumber);
    return docId;
  }

  // Update existing unpaid order details
  Future<void> updateOrder(OrderModel order, TablesRepository tablesRepo) async {
    await _firestoreService.updateDocument(
      collectionPath: _collectionPath,
      docId: order.id,
      data: order.toMap(),
    );
    await tablesRepo.recalculateTableStats(order.tableNumber);
  }

  // Duplicate an existing order
  Future<void> duplicateOrder(OrderModel originalOrder, TablesRepository tablesRepo) async {
    final orderNum = await generateOrderNumber();
    final duplicated = OrderModel(
      id: '',
      orderNumber: orderNum,
      tableNumber: originalOrder.tableNumber,
      timestamp: DateTime.now(),
      items: originalOrder.items,
      notes: originalOrder.notes != null ? '${originalOrder.notes} (Duplicate)' : 'Duplicated order',
      total: originalOrder.total,
      status: 'unpaid',
    );

    await _firestoreService.addDocument(
      collectionPath: _collectionPath,
      data: duplicated.toMap(),
    );

    await tablesRepo.recalculateTableStats(originalOrder.tableNumber);
  }

  // Cancel order (keeping it in history for statistics audit)
  Future<void> cancelOrder({
    required OrderModel order,
    required TablesRepository tablesRepo,
    required String? cashierName,
  }) async {
    // If order was paid, we need to subtract its items and revenue from today's statistics
    if (order.status == 'paid') {
      await _subtractOrderFromStatistics(order);
    }

    await _firestoreService.updateDocument(
      collectionPath: _collectionPath,
      docId: order.id,
      data: {
        'status': 'cancelled',
        'notes': order.notes != null ? '${order.notes} [Cancelled by $cashierName]' : 'Cancelled by $cashierName',
      },
    );

    await tablesRepo.recalculateTableStats(order.tableNumber);
  }

  // Delete order completely
  Future<void> deleteOrder({
    required OrderModel order,
    required TablesRepository tablesRepo,
  }) async {
    if (order.status == 'paid') {
      await _subtractOrderFromStatistics(order);
    }

    await _firestoreService.deleteDocument(
      collectionPath: _collectionPath,
      docId: order.id,
    );

    await tablesRepo.recalculateTableStats(order.tableNumber);
  }

  // Transfer an order from one table to another
  Future<void> transferOrderToTable({
    required OrderModel order,
    required int newTableNumber,
    required TablesRepository tablesRepo,
  }) async {
    final oldTableNumber = order.tableNumber;

    // Update the order document with the new table number
    await _firestoreService.updateDocument(
      collectionPath: _collectionPath,
      docId: order.id,
      data: {
        'tableNumber': newTableNumber,
        'notes': order.notes != null && order.notes!.isNotEmpty
            ? '${order.notes} [نقل من طاولة $oldTableNumber]'
            : 'نقل من طاولة $oldTableNumber',
      },
    );

    // Update stats on BOTH tables
    await tablesRepo.recalculateTableStats(oldTableNumber);
    await tablesRepo.recalculateTableStats(newTableNumber);
  }

  // Assign a pending order (tableNumber == -1) to a real table
  Future<void> assignPendingOrderToTable({
    required OrderModel order,
    required int targetTableNumber,
    required TablesRepository tablesRepo,
  }) async {
    await _firestoreService.updateDocument(
      collectionPath: _collectionPath,
      docId: order.id,
      data: {'tableNumber': targetTableNumber},
    );
    // Only recalc the target table (pending orders don't have a table to recalc from)
    await tablesRepo.recalculateTableStats(targetTableNumber);
  }

  // Merge two unpaid orders on the same table
  Future<void> mergeOrders({
    required OrderModel primaryOrder,
    required OrderModel secondaryOrder,
    required TablesRepository tablesRepo,
  }) async {
    if (primaryOrder.tableNumber != secondaryOrder.tableNumber) {
      throw Exception('Cannot merge orders of different tables.');
    }

    // Merge items
    final Map<String, OrderItemModel> itemsMap = {};
    for (final item in primaryOrder.items) {
      itemsMap[item.menuItemId] = item;
    }

    for (final item in secondaryOrder.items) {
      if (itemsMap.containsKey(item.menuItemId)) {
        final existing = itemsMap[item.menuItemId]!;
        itemsMap[item.menuItemId] = existing.copyWith(
          quantity: existing.quantity + item.quantity,
        );
      } else {
        itemsMap[item.menuItemId] = item;
      }
    }

    final mergedItems = itemsMap.values.toList();
    final double mergedTotal = primaryOrder.total + secondaryOrder.total;
    final String mergedNotes = [
      if (primaryOrder.notes != null && primaryOrder.notes!.isNotEmpty) primaryOrder.notes,
      if (secondaryOrder.notes != null && secondaryOrder.notes!.isNotEmpty) secondaryOrder.notes,
    ].join(' | ');

    // 1. Update primary order with combined list
    await _firestoreService.updateDocument(
      collectionPath: _collectionPath,
      docId: primaryOrder.id,
      data: {
        'items': mergedItems.map((e) => e.toMap()).toList(),
        'total': mergedTotal,
        'notes': mergedNotes,
      },
    );

    // 2. Mark secondary order as merged (cancelled to keep database audit clean)
    await _firestoreService.updateDocument(
      collectionPath: _collectionPath,
      docId: secondaryOrder.id,
      data: {
        'status': 'cancelled',
        'notes': 'Merged into order #${primaryOrder.orderNumber}',
      },
    );

    await tablesRepo.recalculateTableStats(primaryOrder.tableNumber);
  }

  // Split bill: splits off selected items from original order into a new unpaid order
  Future<void> splitBill({
    required OrderModel originalOrder,
    required List<OrderItemModel> splitItems,
    required TablesRepository tablesRepo,
  }) async {
    // 1. Calculate new order total
    double splitTotal = 0.0;
    for (final item in splitItems) {
      splitTotal += item.subtotal;
    }

    // 2. Create the split order document
    final splitOrderNumber = await generateOrderNumber();
    final splitOrder = OrderModel(
      id: '',
      orderNumber: splitOrderNumber,
      tableNumber: originalOrder.tableNumber,
      timestamp: DateTime.now(),
      items: splitItems,
      notes: 'Split from order #${originalOrder.orderNumber}',
      total: splitTotal,
      status: 'unpaid',
      originalOrderId: originalOrder.id,
    );

    await _firestoreService.addDocument(
      collectionPath: _collectionPath,
      data: splitOrder.toMap(),
    );

    // 3. Update original order: subtract quantities or delete items
    final List<OrderItemModel> updatedOriginalItems = [];
    for (final origItem in originalOrder.items) {
      // Find matching item in split items
      final splitMatch = splitItems.firstWhere(
        (e) => e.menuItemId == origItem.menuItemId,
        orElse: () => OrderItemModel(menuItemId: '', name: '', price: 0, quantity: 0),
      );

      final newQty = origItem.quantity - splitMatch.quantity;
      if (newQty > 0) {
        updatedOriginalItems.add(origItem.copyWith(quantity: newQty));
      }
    }

    double newOriginalTotal = 0.0;
    for (final item in updatedOriginalItems) {
      newOriginalTotal += item.subtotal;
    }

    // If original order is now empty, cancel/delete it, otherwise update
    if (updatedOriginalItems.isEmpty) {
      await _firestoreService.updateDocument(
        collectionPath: _collectionPath,
        docId: originalOrder.id,
        data: {
          'status': 'cancelled',
          'notes': 'Fully split into order #$splitOrderNumber',
          'total': 0.0,
          'items': [],
        },
      );
    } else {
      await _firestoreService.updateDocument(
        collectionPath: _collectionPath,
        docId: originalOrder.id,
        data: {
          'items': updatedOriginalItems.map((e) => e.toMap()).toList(),
          'total': newOriginalTotal,
        },
      );
    }

    await tablesRepo.recalculateTableStats(originalOrder.tableNumber);
  }

  // Complete Payment: Mark order paid and update DailyStatistics
  Future<void> processPayment({
    required OrderModel order,
    required String paymentMethod, // "cash", "card", "mixed"
    required String cashierName,
    required TablesRepository tablesRepo,
  }) async {
    final now = DateTime.now();

    // 1. Update order status to paid
    await _firestoreService.updateDocument(
      collectionPath: _collectionPath,
      docId: order.id,
      data: {
        'status': 'paid',
        'paymentMethod': paymentMethod,
        'paidAt': Timestamp.fromDate(now),
        'cashierName': cashierName,
      },
    );

    // 2. Add to Daily Statistics aggregation
    await _addOrderToStatistics(order);

    // 3. Recalculate Table Stats
    await tablesRepo.recalculateTableStats(order.tableNumber);
  }

  // Statistics helper: Add paid order quantities & revenue
  Future<void> _addOrderToStatistics(OrderModel order) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final statsRef = FirebaseFirestore.instance.collection('daily_statistics').doc(todayStr);

    // Look for carry-over by checking previous days one by one (no index needed)
    DocumentSnapshot? carryOverDoc;
    for (int i = 1; i <= 7; i++) {
      final prevStr = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      final doc = await FirebaseFirestore.instance
          .collection('daily_statistics')
          .doc(prevStr)
          .get();
      if (doc.exists && doc.data() != null) {
        final double rev = (doc.data()!['revenue'] as num?)?.toDouble() ?? 0.0;
        if (rev > 0) {
          carryOverDoc = doc;
          break;
        }
      }
    }

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(statsRef);

      Map<String, dynamic> carryData = {};
      if (carryOverDoc != null) {
        final freshCarrySnap = await transaction.get(carryOverDoc.reference);
        if (freshCarrySnap.exists && freshCarrySnap.data() != null) {
          carryData = Map<String, dynamic>.from(freshCarrySnap.data()! as Map<String, dynamic>);
        }
      }

      if (!snapshot.exists) {
        final double carryRevenue = (carryData['revenue'] as num?)?.toDouble() ?? 0.0;
        final int carryOrders = (carryData['ordersCount'] as num?)?.toInt() ?? 0;
        final int carryPaid = (carryData['paidOrdersCount'] as num?)?.toInt() ?? 0;
        final int carryCancelled = (carryData['cancelledOrdersCount'] as num?)?.toInt() ?? 0;
        final Map<String, dynamic> carrySoldRaw = carryData['soldQuantities'] as Map<String, dynamic>? ?? {};
        final Map<String, int> sold = Map<String, int>.from(carrySoldRaw.map((k, v) => MapEntry(k, (v as num).toInt())));

        for (final item in order.items) {
          sold[item.menuItemId] = (sold[item.menuItemId] ?? 0) + item.quantity;
        }

        transaction.set(statsRef, {
          'revenue': carryRevenue + order.total,
          'ordersCount': carryOrders + 1,
          'paidOrdersCount': carryPaid + 1,
          'cancelledOrdersCount': carryCancelled,
          'soldQuantities': sold,
        });

        if (carryOverDoc != null) {
          transaction.update(carryOverDoc.reference, {
            'revenue': 0.0,
            'ordersCount': 0,
            'paidOrdersCount': 0,
            'cancelledOrdersCount': 0,
            'soldQuantities': {},
          });
        }
      } else {
        final data = snapshot.data()!;
        final double revenue = (data['revenue'] as num).toDouble() + order.total;
        final int orders = (data['ordersCount'] as num).toInt() + 1;
        final int paid = (data['paidOrdersCount'] as num).toInt() + 1;

        final Map<String, dynamic> rawSold = data['soldQuantities'] as Map<String, dynamic>? ?? {};
        final Map<String, int> sold = Map<String, int>.from(rawSold.map((k, v) => MapEntry(k, (v as num).toInt())));

        for (final item in order.items) {
          sold[item.menuItemId] = (sold[item.menuItemId] ?? 0) + item.quantity;
        }

        transaction.update(statsRef, {
          'revenue': revenue,
          'ordersCount': orders,
          'paidOrdersCount': paid,
          'soldQuantities': sold,
        });
      }
    });
  }

  // Statistics helper: Subtract cancelled order metrics if previously paid
  Future<void> _subtractOrderFromStatistics(OrderModel order) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final statsRef = FirebaseFirestore.instance.collection('daily_statistics').doc(todayStr);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(statsRef);
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final double revenue = (data['revenue'] as num).toDouble() - order.total;
        final int paid = (data['paidOrdersCount'] as num).toInt() - 1;
        final int cancelled = (data['cancelledOrdersCount'] as num).toInt() + 1;

        final Map<String, dynamic> rawSold = data['soldQuantities'] as Map<String, dynamic>? ?? {};
        final Map<String, int> sold = Map<String, int>.from(rawSold.map((k, v) => MapEntry(k, (v as num).toInt())));

        for (final item in order.items) {
          final current = sold[item.menuItemId] ?? 0;
          final updated = current - item.quantity;
          sold[item.menuItemId] = updated > 0 ? updated : 0;
        }

        transaction.update(statsRef, {
          'revenue': revenue > 0 ? revenue : 0.0,
          'paidOrdersCount': paid > 0 ? paid : 0,
          'cancelledOrdersCount': cancelled,
          'soldQuantities': sold,
        });
      }
    });
  }
}

// Riverpod Providers
final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  return OrdersRepository(firestore);
});

final activeTableOrdersStreamProvider = StreamProvider.family<List<OrderModel>, int>((ref, tableNum) {
  return ref.watch(ordersRepositoryProvider).streamActiveTableOrders(tableNum);
});

final allOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(ordersRepositoryProvider).streamAllOrders();
});

// Stream for pending (unassigned) orders — tableNumber == -1
final pendingOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(ordersRepositoryProvider).streamActiveTableOrders(-1);
});
