import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/orders_provider.dart';
import '../models/order_model.dart';
import '../../tables/providers/tables_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  String _searchQuery = '';
  String _selectedStatusFilter = 'All'; // 'All', 'unpaid', 'paid', 'cancelled', 'emporter'

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final allOrdersAsync = ref.watch(allOrdersStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: l10n.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                l10n.translate('admin_title'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Search and Status Filters
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: l10n.translate('search_orders_hint'),
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Filters Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(l10n.translate('all'), 'All'),
                        const SizedBox(width: 8),
                        _buildFilterChip(l10n.translate('unpaid'), 'unpaid', color: AppTheme.unpaidColor),
                        const SizedBox(width: 8),
                        _buildFilterChip(l10n.translate('paid'), 'paid', color: Colors.green),
                        const SizedBox(width: 8),
                        _buildFilterChip(l10n.translate('cancelled'), 'cancelled', color: Colors.red),
                        const SizedBox(width: 8),
                        _buildFilterChip(l10n.translate('takeaway'), 'emporter', color: Colors.purple),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Orders list
            Expanded(
              child: allOrdersAsync.when(
                data: (orders) {
                  var filtered = orders.where((o) {
                    // Search filter
                    final matchesSearch = _searchQuery.isEmpty ||
                        o.orderNumber.toLowerCase().contains(_searchQuery) ||
                        o.tableNumber.toString().contains(_searchQuery) ||
                        (o.notes ?? '').toLowerCase().contains(_searchQuery) ||
                        (o.cashierName ?? '').toLowerCase().contains(_searchQuery);

                    if (!matchesSearch) return false;

                    // Status filter
                    if (_selectedStatusFilter == 'All') return true;
                    if (_selectedStatusFilter == 'emporter') return o.tableNumber == 0;
                    return o.status == _selectedStatusFilter;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            l10n.translate('no_data'),
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      return _buildOrderTile(context, order, isDark, l10n);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text(l10n.translate('error_loading'))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedStatusFilter = value);
      },
      selectedColor: color?.withValues(alpha: 0.2) ?? AppTheme.primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? (color ?? AppTheme.primaryColor) : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }

  Widget _buildOrderTile(BuildContext context, OrderModel order, bool isDark, AppLocalizations l10n) {
    final currency = l10n.translate('currency');
    final isEmporter = order.tableNumber == 0;
    final timeStr = DateFormat('yyyy/MM/dd HH:mm').format(order.timestamp);

    Color statusBg = Colors.grey.shade200;
    Color statusFg = Colors.black87;

    if (order.status == 'paid') {
      statusBg = Colors.green.shade100;
      statusFg = Colors.green.shade900;
    } else if (order.status == 'unpaid') {
      statusBg = AppTheme.unpaidColor.withValues(alpha: 0.15);
      statusFg = AppTheme.unpaidColor;
    } else if (order.status == 'cancelled') {
      statusBg = Colors.red.shade100;
      statusFg = Colors.red.shade900;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isEmporter ? Colors.purple.shade300 : Colors.transparent,
          width: isEmporter ? 1.5 : 0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/order-detail/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Order Number, Table, Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isEmporter ? Colors.purple.shade100 : AppTheme.primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isEmporter ? Icons.takeout_dining_rounded : Icons.table_restaurant_rounded,
                                  size: 16,
                                  color: isEmporter ? Colors.purple : AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    isEmporter ? l10n.translate('takeaway') : '${l10n.translate("tables")} ${order.tableNumber}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isEmporter ? Colors.purple.shade900 : AppTheme.primaryColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${order.orderNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.translate(order.status),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusFg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Items summary snippet
              Text(
                order.items.map((i) => '${i.quantity}x ${i.name}').join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800),
              ),
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${l10n.translate("notes")}: ${order.notes}',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.orange.shade800),
                ),
              ],
              const Divider(height: 20),

              // Bottom Row: Date/Time, Cashier name & Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        if (order.cashierName != null)
                          Text(
                            l10n.translate('cashier').replaceAll('{name}', order.cashierName!),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${order.total.toStringAsFixed(0)} $currency',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (action) async {
                          if (action == 'detail') {
                            context.push('/order-detail/${order.id}');
                          } else if (action == 'cancel') {
                            _confirmCancelOrder(context, order);
                          } else if (action == 'delete') {
                            _confirmDeleteOrder(context, order);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'detail',
                            child: Row(
                              children: [
                                const Icon(Icons.visibility_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text(l10n.translate('view_details')),
                              ],
                            ),
                          ),
                          if (order.status != 'cancelled')
                            PopupMenuItem(
                              value: 'cancel',
                              child: Row(
                                children: [
                                  const Icon(Icons.cancel_outlined, size: 18, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Text(l10n.translate('cancel_order')),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(l10n.translate('delete_permanently')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmCancelOrder(BuildContext context, OrderModel order) {
    final l10n = ref.read(l10nProvider);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.translate('cancel_order')),
        content: Text(l10n.translate('cancel_order_confirm').replaceAll('{number}', order.orderNumber)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(l10n.translate('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final tablesRepo = ref.read(tablesRepositoryProvider);
              await ref.read(ordersRepositoryProvider).cancelOrder(
                    order: order,
                    tablesRepo: tablesRepo,
                    cashierName: 'Admin',
                  );
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.translate('success_operation')), backgroundColor: Colors.orange),
              );
            },
            child: Text(l10n.translate('confirm')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteOrder(BuildContext context, OrderModel order) {
    final l10n = ref.read(l10nProvider);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.translate('delete_order')),
        content: Text(l10n.translate('delete_order_confirm').replaceAll('{number}', order.orderNumber)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(l10n.translate('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final tablesRepo = ref.read(tablesRepositoryProvider);
              await ref.read(ordersRepositoryProvider).deleteOrder(
                    order: order,
                    tablesRepo: tablesRepo,
                  );
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.translate('success_operation')), backgroundColor: Colors.red),
              );
            },
            child: Text(l10n.translate('confirm')),
          ),
        ],
      ),
    );
  }
}
