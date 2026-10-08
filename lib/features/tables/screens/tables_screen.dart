import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/tables_provider.dart';
import '../models/table_model.dart';
import '../../orders/providers/orders_provider.dart';
import '../../orders/models/order_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

class TablesScreen extends ConsumerStatefulWidget {
  const TablesScreen({super.key});

  @override
  ConsumerState<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends ConsumerState<TablesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final tablesAsync = ref.watch(tablesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'La Terrasse Plus',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Sign Out Action
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new-order/-1'),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text(l10n.translate('order_without_table')),
        backgroundColor: Colors.orange.shade700,
      ),
      body: Column(
        children: [
          // Pending orders banner — orders waiting for a table
          Consumer(
            builder: (context, ref, _) {
              final pendingAsync = ref.watch(pendingOrdersStreamProvider);
              return pendingAsync.when(
                data: (pendingOrders) {
                  if (pendingOrders.isEmpty) return const SizedBox.shrink();
                  return InkWell(
                    onTap: () => _showPendingOrdersSheet(context, pendingOrders),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pending_actions_rounded, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.translate('pending_orders_banner').replaceAll('{count}', '${pendingOrders.length}'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
          // Search & Filters Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.translate('search'),
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            ),
          ),
          Expanded(
            child: tablesAsync.when(
              data: (tables) {
                // Filter tables if searched
                final filtered = tables.where((t) {
                  if (_searchQuery.isEmpty) return true;
                  return t.number.toString() == _searchQuery ||
                      t.status.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

                // Sort tables: Table 0 (Emporter) always first, then latest order time, then number
                filtered.sort((a, b) {
                  if (a.number == 0) return -1;
                  if (b.number == 0) return 1;
                  if (a.lastOrderTime != null && b.lastOrderTime != null) {
                    return b.lastOrderTime!.compareTo(a.lastOrderTime!);
                  }
                  if (a.lastOrderTime != null && b.lastOrderTime == null) {
                    return -1;
                  }
                  if (a.lastOrderTime == null && b.lastOrderTime != null) {
                    return 1;
                  }
                  return a.number.compareTo(b.number);
                });

                if (filtered.isEmpty) {
                  return Center(child: Text(l10n.translate('no_data')));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.74,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final table = filtered[index];
                    return _buildTableCard(context, table);
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
  }

  Widget _buildTableCard(BuildContext context, TableModel table) {
    final l10n = ref.watch(l10nProvider);
    final isEmporter = table.number == 0;
    
    // Status colors: Green for empty, Orange for occupied, Red for unpaid orders, Blue for paid
    Color statusColor = isEmporter ? Colors.purple : AppTheme.emptyColor;
    if (table.status == 'occupied') {
      statusColor = AppTheme.occupiedColor;
    } else if (table.status == 'unpaid') {
      statusColor = isEmporter ? Colors.deepOrange : AppTheme.unpaidColor;
    } else if (table.status == 'paid') {
      statusColor = Colors.blue;
    }

    return Card(
      elevation: isEmporter ? 5 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isEmporter ? Colors.purple.shade400 : statusColor.withValues(alpha: 0.4),
          width: isEmporter ? 2.5 : 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTableOrdersSheet(context, table),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header: Table number or Emporter icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: isEmporter ? Colors.purple.shade100 : statusColor.withValues(alpha: 0.15),
                    radius: 18,
                    child: isEmporter
                        ? const Icon(Icons.takeout_dining_rounded, color: Colors.purple, size: 20)
                        : Text(
                            '${table.number}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                            ),
                          ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isEmporter ? Colors.purple.shade50 : statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isEmporter ? l10n.translate('takeaway') : l10n.translate(table.status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isEmporter ? Colors.purple.shade800 : statusColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Details
              if (table.unpaidOrdersCount > 0) ...[
                Text(
                  '${l10n.translate('unpaid_orders')}: ${table.unpaidOrdersCount}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${table.currentTotal.toStringAsFixed(0)} ${l10n.translate('currency')}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  l10n.translate('empty'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 2),
                const Text('-', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 6),
              // Time
              if (table.lastOrderTime != null)
                Text(
                  '${l10n.translate('last_order')} ${DateFormat('HH:mm').format(table.lastOrderTime!)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                const SizedBox(height: 12),
              const SizedBox(height: 6),
              // Action Button
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton(
                  onPressed: () {
                    context.push('/new-order/${table.number}');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l10n.translate('new_order'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Slide-up dialog displaying current orders for the clicked table
  void _showTableOrdersSheet(BuildContext context, TableModel table) {
    final l10n = ref.read(l10nProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final ordersAsync = ref.watch(activeTableOrdersStreamProvider(table.number));

                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.translate('orders_for_table').replaceAll('{table}', '${table.number}'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              context.push('/new-order/${table.number}');
                            },
                            icon: const Icon(Icons.add),
                            label: Text(l10n.translate('new_order')),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: ordersAsync.when(
                          data: (orders) {
                            if (orders.isEmpty) {
                              return Center(
                                child: Text(
                                  l10n.translate('no_orders'),
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: scrollController,
                              itemCount: orders.length,
                              itemBuilder: (context, index) {
                                final order = orders[index];
                                return _buildOrderListItem(context, order);
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
      },
    );
  }

  Widget _buildOrderListItem(BuildContext context, OrderModel order) {
    final l10n = ref.read(l10nProvider);
    final currency = l10n.translate('currency');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                l10n.translate('order_no').replaceAll('{number}', order.orderNumber),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${order.total.toStringAsFixed(0)} $currency',
              style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${order.items.length} items | ${DateFormat('HH:mm').format(order.timestamp)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: order.items.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: Text(
                    '${item.quantity}x ${item.name}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${l10n.translate('notes')}: ${order.notes}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.translate('transfer_table'),
              icon: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryColor),
              onPressed: () {
                Navigator.pop(context); // Close bottom sheet first
                _showTransferTableDialog(context, order);
              },
            ),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
        onTap: () {
          Navigator.pop(context); // Close bottom sheet
          context.push('/order-detail/${order.id}');
        },
      ),
    );
  }

  // ─── Pending Orders Sheet (orders without table) ───────────────────────────
  void _showPendingOrdersSheet(BuildContext context, List<OrderModel> orders) {
    final l10n = ref.read(l10nProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.9,
          minChildSize: 0.35,
          expand: false,
          builder: (ctx, scroll) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.translate('pending_orders_title'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.translate('pending_orders_subtitle'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView.builder(
                      controller: scroll,
                      itemCount: orders.length,
                      itemBuilder: (context, i) {
                        final order = orders[i];
                        return _buildPendingOrderTile(ctx, order);
                      },
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

  Widget _buildPendingOrderTile(BuildContext ctx, OrderModel order) {
    final l10n = ref.read(l10nProvider);
    final currency = l10n.translate('currency');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade300, width: 1.5),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: const Icon(Icons.pending_actions_rounded, color: Colors.orange),
        ),
        title: Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${order.items.length} أصناف • ${order.total.toStringAsFixed(0)} $currency • ${DateFormat('HH:mm').format(order.timestamp)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.translate('assign_table'),
              icon: const Icon(Icons.table_restaurant_rounded, color: Colors.orange),
              onPressed: () {
                Navigator.pop(ctx);
                _showAssignTableDialog(ctx, order, isPending: true);
              },
            ),
            IconButton(
              tooltip: l10n.translate('view_details'),
              icon: const Icon(Icons.visibility_outlined, color: AppTheme.primaryColor),
              onPressed: () {
                Navigator.pop(ctx);
                ctx.push('/order-detail/${order.id}');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Table Transfer Dialog ─────────────────────────────────────────────────
  void _showTransferTableDialog(BuildContext context, OrderModel order) {
    _showAssignTableDialog(context, order, isPending: false);
  }

  void _showAssignTableDialog(BuildContext context, OrderModel order, {required bool isPending}) {
    final l10n = ref.read(l10nProvider);
    final tablesAsync = ref.read(tablesStreamProvider);
    final tables = tablesAsync.value ?? [];
    // Exclude current table, pending table (-1) and Emporter (0) from targets
    final targetTables = tables.where((t) => t.number != order.tableNumber && t.number != -1).toList();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(isPending ? Icons.table_restaurant_rounded : Icons.swap_horiz_rounded,
                  color: isPending ? Colors.orange : AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(isPending ? l10n.translate('assign_table_to_order') : l10n.translate('transfer_order_to_table')),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('order_no').replaceAll('{number}', order.orderNumber),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (!isPending)
                  Text(
                    l10n.translate('current_table').replaceAll('{table}', order.tableNumber == 0 ? l10n.translate('takeaway') : '${order.tableNumber}'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                const SizedBox(height: 12),
                Text(l10n.translate('select_target_table')),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Emporter option
                        if (!isPending)
                          _buildTableChip(dialogCtx, order, 0, l10n.translate('takeaway'), isPending, Colors.purple),
                        // Regular tables
                        ...targetTables.map((t) => _buildTableChip(
                          dialogCtx, order, t.number,
                          t.number == 0 ? l10n.translate('takeaway') : '${l10n.translate("tables")} ${t.number}',
                          isPending,
                          t.status == 'unpaid' ? AppTheme.unpaidColor : AppTheme.emptyColor,
                        )),
                      ],
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

  Widget _buildTableChip(
    BuildContext dialogCtx,
    OrderModel order,
    int targetTable,
    String label,
    bool isPending,
    Color color,
  ) {
    return ActionChip(
      avatar: Icon(
        targetTable == 0 ? Icons.takeout_dining_rounded : Icons.table_restaurant_rounded,
        size: 16,
        color: color,
      ),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      onPressed: () async {
        Navigator.pop(dialogCtx);
        final tablesRepo = ref.read(tablesRepositoryProvider);
        final ordersRepo = ref.read(ordersRepositoryProvider);
        final messenger = ScaffoldMessenger.of(context);
        final l10nRepo = ref.read(l10nProvider);
        try {
          if (isPending) {
            await ordersRepo.assignPendingOrderToTable(
              order: order,
              targetTableNumber: targetTable,
              tablesRepo: tablesRepo,
            );
            messenger.showSnackBar(SnackBar(
              content: Text(l10nRepo.translate('order_assigned_success').replaceAll('{number}', order.orderNumber).replaceAll('{table}', '$targetTable')),
              backgroundColor: Colors.green,
            ));
          } else {
            await ordersRepo.transferOrderToTable(
              order: order,
              newTableNumber: targetTable,
              tablesRepo: tablesRepo,
            );
            messenger.showSnackBar(SnackBar(
              content: Text(l10nRepo.translate('order_transferred_success').replaceAll('{number}', order.orderNumber).replaceAll('{table}', '$targetTable')),
              backgroundColor: Colors.green,
            ));
          }
        } catch (e) {
          messenger.showSnackBar(SnackBar(
            content: Text(l10nRepo.translate('operation_failed').replaceAll('{error}', '$e')),
            backgroundColor: Colors.red,
          ));
        }
      },
    );
  }
}
