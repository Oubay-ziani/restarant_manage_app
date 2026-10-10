import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../settings/models/settings_model.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../providers/orders_provider.dart';
import '../../menu/providers/menu_provider.dart';
import '../../tables/providers/tables_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/print_service.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isEditing = false;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Quantity updates directly in editing state
  Future<void> _updateItemQty(OrderModel order, int index, int change) async {
    final List<OrderItemModel> items = List.from(order.items);
    final item = items[index];
    final newQty = item.quantity + change;

    if (newQty <= 0) {
      items.removeAt(index);
    } else {
      items[index] = item.copyWith(quantity: newQty);
    }

    double newTotal = 0.0;
    for (final it in items) {
      newTotal += it.subtotal;
    }

    final updatedOrder = order.copyWith(
      items: items,
      total: newTotal,
    );

    final tablesRepo = ref.read(tablesRepositoryProvider);
    await ref.read(ordersRepositoryProvider).updateOrder(updatedOrder, tablesRepo);
  }

  // Set direct quantity via keyboard
  Future<void> _setDirectItemQty(OrderModel order, int index, int newQty) async {
    final List<OrderItemModel> items = List.from(order.items);
    if (newQty <= 0) {
      items.removeAt(index);
    } else {
      items[index] = items[index].copyWith(quantity: newQty);
    }

    double newTotal = 0.0;
    for (final it in items) {
      newTotal += it.subtotal;
    }

    final updatedOrder = order.copyWith(
      items: items,
      total: newTotal,
    );

    final tablesRepo = ref.read(tablesRepositoryProvider);
    await ref.read(ordersRepositoryProvider).updateOrder(updatedOrder, tablesRepo);
  }

  // Dialog to type exact item quantity directly
  void _showTypeQtyDialog(OrderModel order, int index) {
    final item = order.items[index];
    final ctrl = TextEditingController(text: item.quantity.toString());
    final l10n = ref.read(l10nProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.translate('quantity'),
            prefixIcon: const Icon(Icons.edit_note),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(ctrl.text.trim());
              if (parsed != null) {
                Navigator.pop(context);
                _setDirectItemQty(order, index, parsed);
              }
            },
            child: Text(l10n.translate('confirm')),
          ),
        ],
      ),
    );
  }

  // Direct 1-Click Cash Payment
  Future<void> _processDirectCashPayment(OrderModel order) async {
    final l10n = ref.read(l10nProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final tablesRepo = ref.read(tablesRepositoryProvider);
      final cashier = ref.read(currentAdminUserProvider).value?.name ?? 'Admin';

      await ref.read(ordersRepositoryProvider).processPayment(
            order: order,
            paymentMethod: 'cash',
            cashierName: cashier,
            tablesRepo: tablesRepo,
          );

      final settings = ref.read(settingsProvider).value ?? SettingsModel.defaultConfig();
      final printerBytes = PrintService().generateCustomerReceipt(
        restaurantName: settings.restaurantName,
        orderNumber: order.orderNumber,
        tableNumber: order.tableNumber,
        dateTime: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
        items: order.items.map((e) => {'name': e.name, 'quantity': e.quantity, 'price': e.price}).toList(),
        total: order.total,
        paperWidth: settings.paperWidth,
        currency: settings.currency,
        cashierName: cashier,
        taxPercent: settings.taxPercentage,
        servicePercent: settings.serviceCharge,
      );

      if (settings.wifiPrinterIp != null && settings.wifiPrinterIp!.isNotEmpty) {
        await PrintService().printViaWifi(
          ip: settings.wifiPrinterIp!,
          port: settings.wifiPrinterPort,
          bytes: printerBytes,
        );
      } else if (settings.bluetoothAddress != null) {
        await PrintService().printViaBluetooth(
          macAddress: settings.bluetoothAddress!,
          bytes: printerBytes,
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close loader
        context.pop(); // Return to main screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('success_operation')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('error_occurred')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add new item to existing order modal
  void _showAddItemModal(OrderModel order) {
    final l10n = ref.read(l10nProvider);
    final menuItems = ref.read(menuItemsStreamProvider).value ?? [];
    final activeMenuItems = menuItems.where((e) => e.isActive).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('add_item'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  itemCount: activeMenuItems.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final menuItem = activeMenuItems[index];
                    final currentLang = ref.watch(localeProvider).languageCode;

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Image.network(
                            menuItem.displayImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              child: const Icon(Icons.restaurant, color: AppTheme.primaryColor),
                            ),
                          ),
                        ),
                      ),
                      title: Text(menuItem.getName(currentLang), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${menuItem.price.toStringAsFixed(0)} ${l10n.translate('currency')}'),
                      trailing: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                      onTap: () async {
                        Navigator.pop(context);
                        
                        // Check if item already exists in order
                        final List<OrderItemModel> updatedItems = List.from(order.items);
                        final existingIdx = updatedItems.indexWhere((e) => e.menuItemId == menuItem.id);

                        if (existingIdx != -1) {
                          final current = updatedItems[existingIdx];
                          updatedItems[existingIdx] = current.copyWith(quantity: current.quantity + 1);
                        } else {
                          updatedItems.add(
                            OrderItemModel(
                              menuItemId: menuItem.id,
                              name: menuItem.getName(currentLang),
                              price: menuItem.price,
                              quantity: 1,
                            ),
                          );
                        }

                        double newTotal = 0.0;
                        for (final it in updatedItems) {
                          newTotal += it.subtotal;
                        }

                        final updatedOrder = order.copyWith(items: updatedItems, total: newTotal);
                        final tablesRepo = ref.read(tablesRepositoryProvider);
                        await ref.read(ordersRepositoryProvider).updateOrder(updatedOrder, tablesRepo);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Print support triggers
  Future<void> _printReceipt(OrderModel order, {required bool isKitchen}) async {
    final settings = ref.read(settingsProvider).value ?? SettingsModel.defaultConfig();
    final l10n = ref.read(l10nProvider);

    List<int> bytes;
    if (isKitchen) {
      bytes = PrintService().generateKitchenTicket(
        orderNumber: order.orderNumber,
        tableNumber: order.tableNumber,
        dateTime: DateFormat('HH:mm').format(order.timestamp),
        items: order.items.map((e) => {'name': e.name, 'quantity': e.quantity}).toList(),
        notes: order.notes,
        paperWidth: settings.paperWidth,
      );
    } else {
      bytes = PrintService().generateCustomerReceipt(
        restaurantName: settings.restaurantName,
        orderNumber: order.orderNumber,
        tableNumber: order.tableNumber,
        dateTime: DateFormat('yyyy-MM-dd HH:mm').format(order.timestamp),
        items: order.items.map((e) => {'name': e.name, 'quantity': e.quantity, 'price': e.price}).toList(),
        total: order.total,
        paperWidth: settings.paperWidth,
        currency: settings.currency,
        cashierName: order.cashierName,
        taxPercent: settings.taxPercentage,
        servicePercent: settings.serviceCharge,
      );
    }

    bool success = false;
    if (settings.wifiPrinterIp != null && settings.wifiPrinterIp!.isNotEmpty) {
      success = await PrintService().printViaWifi(
        ip: settings.wifiPrinterIp!,
        port: settings.wifiPrinterPort,
        bytes: bytes,
      );
    } else if (settings.bluetoothAddress != null) {
      success = await PrintService().printViaBluetooth(
        macAddress: settings.bluetoothAddress!,
        bytes: bytes,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.translate('success_operation') : 'Printer unavailable.'),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
    }
  }

  // Split Bill sliding selector
  void _showSplitBillModal(OrderModel order) {
    final l10n = ref.read(l10nProvider);
    final currency = l10n.translate('currency');
    final Map<String, int> splitCart = {}; // menuItemId -> qty to split

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('split_bill'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.translate('split_instructions'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.separated(
                      itemCount: order.items.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = order.items[index];
                        final splitQty = splitCart[item.menuItemId] ?? 0;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${item.price.toStringAsFixed(0)} $currency (Max: ${item.quantity})'),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () {
                                    if (splitQty > 0) {
                                      setModalState(() {
                                        splitCart[item.menuItemId] = splitQty - 1;
                                      });
                                    }
                                  },
                                ),
                                Text('$splitQty', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    if (splitQty < item.quantity) {
                                      setModalState(() {
                                        splitCart[item.menuItemId] = splitQty + 1;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  // Split Action Trigger
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.translate('cancel')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final List<OrderItemModel> itemsToSplit = [];
                            splitCart.forEach((itemId, qty) {
                              if (qty > 0) {
                                final original = order.items.firstWhere((e) => e.menuItemId == itemId);
                                itemsToSplit.add(
                                  OrderItemModel(
                                    menuItemId: itemId,
                                    name: original.name,
                                    price: original.price,
                                    quantity: qty,
                                  ),
                                );
                              }
                            });

                            if (itemsToSplit.isEmpty) return;

                            Navigator.pop(context);
                            
                            // Show loader
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator()),
                            );

                            try {
                              final tablesRepo = ref.read(tablesRepositoryProvider);
                              await ref.read(ordersRepositoryProvider).splitBill(
                                    originalOrder: order,
                                    splitItems: itemsToSplit,
                                    tablesRepo: tablesRepo,
                                  );

                              if (context.mounted) {
                                Navigator.pop(context); // Close loader
                                context.pop(); // return to tables grid
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.translate('success_operation')),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.translate('error_occurred')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                          child: Text(l10n.translate('split_bill')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Merge unpaid orders selector
  void _showMergeOrdersModal(OrderModel order) {
    final l10n = ref.read(l10nProvider);
    final currency = l10n.translate('currency');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final activeOrdersAsync = ref.watch(activeTableOrdersStreamProvider(order.tableNumber));

            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('merge_orders'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Expanded(
                    child: activeOrdersAsync.when(
                      data: (orders) {
                        // Filter out THIS primary order
                        final mergeable = orders.where((e) => e.id != order.id).toList();

                        if (mergeable.isEmpty) {
                          return Center(
                            child: Text(
                              l10n.translate('no_data'),
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: mergeable.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final otherOrder = mergeable[index];
                            return ListTile(
                              title: Text(l10n.translate('order_no').replaceAll('{number}', otherOrder.orderNumber)),
                              subtitle: Text('${otherOrder.items.length} items | ${DateFormat('HH:mm').format(otherOrder.timestamp)}'),
                              trailing: Text(
                                '${otherOrder.total.toStringAsFixed(0)} $currency',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _confirmMerge(order, otherOrder, l10n);
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text(l10n.translate('error_loading'))),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmMerge(OrderModel primary, OrderModel secondary, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('merge_orders')),
          content: Text(l10n.translate('merge_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // Show loader
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final tablesRepo = ref.read(tablesRepositoryProvider);
                  await ref.read(ordersRepositoryProvider).mergeOrders(
                        primaryOrder: primary,
                        secondaryOrder: secondary,
                        tablesRepo: tablesRepo,
                      );

                  if (context.mounted) {
                    Navigator.pop(context); // Close loader
                    context.pop(); // Return to grid
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.translate('success_operation')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.translate('error_occurred')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(l10n.translate('confirm')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final currency = l10n.translate('currency');

    return Directionality(
      textDirection: l10n.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.translate('view_orders'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.orderId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: Text(l10n.translate('no_data')));
            }

            final order = OrderModel.fromMap(
              snapshot.data!.data() as Map<String, dynamic>,
              snapshot.data!.id,
            );

            // Populate controller notes if not editing yet
            if (!_isEditing) {
              _notesController.text = order.notes ?? '';
            }

            final isUnpaid = order.status == 'unpaid';

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Details Summary Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      l10n.translate('order_no').replaceAll('{number}', order.orderNumber),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _deleteOrderDialog(order, l10n),
                                          tooltip: l10n.translate('delete_order'),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: order.status == 'paid'
                                                ? Colors.green.withValues(alpha: 0.15)
                                                : order.status == 'cancelled'
                                                    ? Colors.red.withValues(alpha: 0.15)
                                                    : Colors.orange.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            l10n.translate(order.status),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: order.status == 'paid'
                                                  ? Colors.green
                                                  : order.status == 'cancelled'
                                                      ? Colors.red
                                                      : Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                // Table row with transfer button for unpaid orders
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: _buildDetailRow(
                                        l10n.translate('tables'),
                                        order.tableNumber == -1
                                            ? l10n.translate('temp_no_table')
                                            : order.tableNumber == 0
                                                ? l10n.translate('takeaway')
                                                : '${l10n.translate("tables")} ${order.tableNumber}',
                                      ),
                                    ),
                                    if (isUnpaid)
                                      TextButton.icon(
                                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                        label: Text(l10n.translate('transfer_table'), style: const TextStyle(fontSize: 12)),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.primaryColor,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                        onPressed: () => _showTransferTableDialog(order, l10n),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow(l10n.translate('last_order'), DateFormat('yyyy-MM-dd HH:mm').format(order.timestamp)),
                                if (order.cashierName != null) ...[
                                  const SizedBox(height: 8),
                                  _buildDetailRow(l10n.translate('cashier').replaceAll(': {name}', ''), order.cashierName!),
                                ],
                                if (order.paymentMethod != null) ...[
                                  const SizedBox(height: 8),
                                  _buildDetailRow(l10n.translate('payment'), l10n.translate(order.paymentMethod!)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Items list card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      l10n.translate('grill_menu'),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    if (isUnpaid)
                                      IconButton(
                                        icon: Icon(_isEditing ? Icons.check_circle : Icons.edit_note, color: AppTheme.primaryColor),
                                        onPressed: () async {
                                          if (_isEditing) {
                                            // Save notes edits
                                            final updated = order.copyWith(
                                              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                                            );
                                            await ref.read(ordersRepositoryProvider).updateOrder(updated, ref.read(tablesRepositoryProvider));
                                          }
                                          setState(() => _isEditing = !_isEditing);
                                        },
                                      ),
                                  ],
                                ),
                                const Divider(),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: order.items.length,
                                  separatorBuilder: (context, index) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final item = order.items[index];
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              Text('${item.price.toStringAsFixed(0)} $currency'),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                             if (isUnpaid && _isEditing) ...[
                                               IconButton(
                                                 icon: const Icon(Icons.remove_circle_outline, size: 20),
                                                 onPressed: () => _updateItemQty(order, index, -1),
                                               ),
                                               InkWell(
                                                 onTap: () => _showTypeQtyDialog(order, index),
                                                 borderRadius: BorderRadius.circular(6),
                                                 child: Container(
                                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                   decoration: BoxDecoration(
                                                     color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                     borderRadius: BorderRadius.circular(6),
                                                   ),
                                                   child: Text(
                                                     '${item.quantity}',
                                                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                                                   ),
                                                 ),
                                               ),
                                               IconButton(
                                                 icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.primaryColor),
                                                 onPressed: () => _updateItemQty(order, index, 1),
                                               ),
                                             ] else ...[
                                              Text('x${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 16),
                                              Text(
                                                '${item.subtotal.toStringAsFixed(0)} $currency',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                if (isUnpaid && _isEditing) ...[
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () => _showAddItemModal(order),
                                    icon: const Icon(Icons.add),
                                    label: Text(l10n.translate('add_item')),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Notes field
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.translate('notes'),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                if (isUnpaid && _isEditing)
                                  TextField(
                                    controller: _notesController,
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                      hintText: l10n.translate('notes'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  )
                                else
                                  Text(
                                    (order.notes == null || order.notes!.isEmpty)
                                        ? '-'
                                        : order.notes!,
                                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Foot action buttons panel
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).cardTheme.color,
                  child: SafeArea(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.translate('total'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            Text(
                              '${order.total.toStringAsFixed(0)} $currency',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Layout depending on status
                        if (isUnpaid) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showMergeOrdersModal(order),
                                  icon: const Icon(Icons.merge_type_rounded, size: 16),
                                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.translate('merge_orders'))),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showSplitBillModal(order),
                                  icon: const Icon(Icons.call_split_rounded, size: 16),
                                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.translate('split_bill'))),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final tablesRepo = ref.read(tablesRepositoryProvider);
                                    await ref.read(ordersRepositoryProvider).duplicateOrder(order, tablesRepo);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(l10n.translate('success_operation')), backgroundColor: Colors.green),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.translate('duplicate_order'))),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _cancelOrderDialog(order, l10n),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  icon: const Icon(Icons.cancel, size: 16),
                                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.translate('cancel_order'))),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _printReceipt(order, isKitchen: true),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                                  icon: const Icon(Icons.print, size: 16),
                                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.translate('print_kitchen'))),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _processDirectCashPayment(order),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  icon: const Icon(Icons.payment, size: 16),
                                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.translate('payment'))),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _printReceipt(order, isKitchen: false),
                                  icon: const Icon(Icons.print, size: 18),
                                  label: Text(l10n.translate('print_receipt')),
                                ),
                              ),
                              if (order.status == 'paid') ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _cancelOrderDialog(order, l10n),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                    icon: const Icon(Icons.undo, size: 18),
                                    label: Text(l10n.translate('cancel_order')),
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _cancelOrderDialog(OrderModel order, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('cancel_order')),
          content: Text('${l10n.translate('cancel_order')}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // Show loader
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final tablesRepo = ref.read(tablesRepositoryProvider);
                  final cashier = ref.read(currentAdminUserProvider).value?.name ?? 'Admin';
                  
                  await ref.read(ordersRepositoryProvider).cancelOrder(
                        order: order,
                        tablesRepo: tablesRepo,
                        cashierName: cashier,
                      );

                  if (context.mounted) {
                    Navigator.pop(context); // Close loader
                    context.pop(); // Return to dashboard
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.translate('success_operation')), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.translate('error_occurred')), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l10n.translate('confirm')),
            ),
          ],
        );
      },
    );
  }

  void _deleteOrderDialog(OrderModel order, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('delete_order')),
          content: Text('${l10n.translate('delete_order')}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // Show loader
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final tablesRepo = ref.read(tablesRepositoryProvider);
                  
                  await ref.read(ordersRepositoryProvider).deleteOrder(
                        order: order,
                        tablesRepo: tablesRepo,
                      );

                  if (context.mounted) {
                    Navigator.pop(context); // Close loader
                    context.pop(); // Return to dashboard
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.translate('success_operation')), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.translate('error_occurred')), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l10n.translate('confirm')),
            ),
          ],
        );
      },
    );
  }

  void _showTransferTableDialog(OrderModel order, AppLocalizations l10n) {
    final tablesAsync = ref.read(tablesStreamProvider);
    final tables = tablesAsync.value ?? [];
    final isPending = order.tableNumber == -1;

    // Exclude current table and -1 (pending) from selection
    final targetTables = tables
        .where((t) => t.number != order.tableNumber && t.number != -1)
        .toList();
    targetTables.sort((a, b) => a.number.compareTo(b.number));

    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isPending ? Icons.table_restaurant_rounded : Icons.swap_horiz_rounded,
                color: isPending ? Colors.orange : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(isPending ? l10n.translate('assign_table_to_order') : l10n.translate('transfer_order_to_table')),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.translate('order_no').replaceAll('{number}', order.orderNumber), style: const TextStyle(fontWeight: FontWeight.bold)),
                if (!isPending)
                  Text(
                    l10n.translate('current_table').replaceAll('{table}', order.tableNumber == 0 ? l10n.translate('takeaway') : '${l10n.translate("tables")} ${order.tableNumber}'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                const SizedBox(height: 12),
                Text(l10n.translate('select_target_table')),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: targetTables.map((t) {
                        final label = t.number == 0 ? l10n.translate('takeaway') : '${l10n.translate("tables")} ${t.number}';
                        final color = t.status == 'unpaid' ? AppTheme.unpaidColor : AppTheme.emptyColor;
                        return ActionChip(
                          avatar: Icon(
                            t.number == 0 ? Icons.takeout_dining_rounded : Icons.table_restaurant_rounded,
                            size: 16,
                            color: color,
                          ),
                          label: Text(
                            label,
                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          backgroundColor: color.withValues(alpha: 0.1),
                          side: BorderSide(color: color.withValues(alpha: 0.4)),
                          onPressed: () async {
                            Navigator.pop(dialogCtx);
                            try {
                              final tablesRepo = ref.read(tablesRepositoryProvider);
                              final ordersRepo = ref.read(ordersRepositoryProvider);
                              if (isPending) {
                                await ordersRepo.assignPendingOrderToTable(
                                  order: order,
                                  targetTableNumber: t.number,
                                  tablesRepo: tablesRepo,
                                );
                              } else {
                                await ordersRepo.transferOrderToTable(
                                  order: order,
                                  newTableNumber: t.number,
                                  tablesRepo: tablesRepo,
                                );
                              }
                              messenger.showSnackBar(SnackBar(
                                content: Text(
                                  isPending
                                      ? l10n.translate('order_assigned_success').replaceAll('{number}', order.orderNumber).replaceAll('{table}', label)
                                      : l10n.translate('order_transferred_success').replaceAll('{number}', order.orderNumber).replaceAll('{table}', label),
                                ),
                                backgroundColor: Colors.green,
                              ));
                            } catch (e) {
                              messenger.showSnackBar(SnackBar(
                                content: Text(l10n.translate('operation_failed').replaceAll('{error}', '$e')),
                                backgroundColor: Colors.red,
                              ));
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.translate('cancel')),
            ),
          ],
        );
      },
    );
  }
}
