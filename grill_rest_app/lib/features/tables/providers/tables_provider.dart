import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/table_model.dart';
import '../../menu/providers/menu_provider.dart';
import '../../../core/services/firestore_service.dart';

class TablesRepository {
  final FirestoreService _firestoreService;
  static const String _collectionPath = 'tables';

  TablesRepository(this._firestoreService);

  Stream<List<TableModel>> streamTables() {
    return _firestoreService.streamCollection<TableModel>(
      collectionPath: _collectionPath,
      builder: (data, id) => TableModel.fromMap(data, id),
      queryBuilder: (query) => query.orderBy('number', descending: false),
    );
  }

  // Pre-populates table 0 (Emporter) + 40 tables if collection is fresh
  Future<void> initializeTables() async {
    try {
      final colRef = _firestoreService.getColRef(_collectionPath);
      final emporterDoc = await colRef.doc('table_0').get();
      if (!emporterDoc.exists) {
        await colRef.doc('table_0').set(TableModel(
          id: 'table_0',
          number: 0,
          status: 'empty',
          unpaidOrdersCount: 0,
          currentTotal: 0.0,
          lastOrderTime: null,
        ).toMap());
      }
      
      final snapshot = await colRef.limit(2).get();
      if (snapshot.docs.length <= 1) {
        debugPrint('Initializing BBQ tables 1..40 in Firestore...');
        await _firestoreService.runBatch((batch) async {
          for (int i = 1; i <= 40; i++) {
            final docRef = colRef.doc('table_$i');
            final newTable = TableModel(
              id: 'table_$i',
              number: i,
              status: 'empty',
              unpaidOrdersCount: 0,
              currentTotal: 0.0,
              lastOrderTime: null,
            );
            batch.set(docRef, newTable.toMap());
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize tables: $e');
    }
  }

  Future<void> updateTable(TableModel table) async {
    await _firestoreService.setDocument(
      collectionPath: _collectionPath,
      docId: table.id,
      data: table.toMap(),
    );
  }

  // Triggered when a new order is added or state changes
  Future<void> recalculateTableStats(int tableNumber) async {
    final docId = 'table_$tableNumber';
    
    // Find all active (unpaid) orders for this table
    final ordersQuery = await FirebaseFirestore.instance
        .collection('orders')
        .where('tableNumber', isEqualTo: tableNumber)
        .where('status', isEqualTo: 'unpaid')
        .get();

    final unpaidCount = ordersQuery.docs.length;
    double total = 0.0;
    DateTime? lastOrder;

    for (final doc in ordersQuery.docs) {
      final data = doc.data();
      total += (data['total'] as num?)?.toDouble() ?? 0.0;
      
      final ts = data['timestamp'];
      if (ts is Timestamp) {
        final orderDate = ts.toDate();
        if (lastOrder == null || orderDate.isAfter(lastOrder)) {
          lastOrder = orderDate;
        }
      }
    }

    String status = 'empty';
    if (unpaidCount > 0) {
      status = 'unpaid';
    } else {
      final paidQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('tableNumber', isEqualTo: tableNumber)
          .where('status', isEqualTo: 'paid')
          .get();
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final hasRecentPaid = paidQuery.docs.any((doc) {
        final paidAt = (doc.data()['paidAt'] as Timestamp?)?.toDate();
        return paidAt != null && paidAt.isAfter(oneHourAgo);
      });
      if (hasRecentPaid) {
        status = 'paid';
      }
    }

    final tableRef = _firestoreService.getDocRef(_collectionPath, docId);
    await tableRef.set({
      'number': tableNumber,
      'status': status,
      'unpaidOrdersCount': unpaidCount,
      'currentTotal': total,
      'lastOrderTime': lastOrder != null ? Timestamp.fromDate(lastOrder) : null,
    }, SetOptions(merge: true));
  }

  // Force reset all tables (used in end business day)
  Future<void> resetAllTables() async {
    final colRef = _firestoreService.getColRef(_collectionPath);
    await _firestoreService.runBatch((batch) async {
      for (int i = 0; i <= 40; i++) {
        final docRef = colRef.doc('table_$i');
        batch.set(docRef, {
          'number': i,
          'status': 'empty',
          'unpaidOrdersCount': 0,
          'currentTotal': 0.0,
          'lastOrderTime': null,
        }, SetOptions(merge: true));
      }
    });
  }
}

// Riverpod Providers
final tablesRepositoryProvider = Provider<TablesRepository>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  return TablesRepository(firestore);
});

final tablesStreamProvider = StreamProvider<List<TableModel>>((ref) {
  final repo = ref.watch(tablesRepositoryProvider);
  // Auto initialize on stream creation
  repo.initializeTables();
  return repo.streamTables();
});
