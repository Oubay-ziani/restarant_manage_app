import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../../menu/providers/menu_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/settings_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/pdf_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final statsAsync = ref.watch(dailyStatisticsProvider);
    final ordersAsync = ref.watch(allOrdersStreamProvider);
    final menuItemsAsync = ref.watch(menuItemsStreamProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('dashboard'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: statsAsync.when(
        data: (stats) {
          if (stats == null) {
            return Center(child: Text(l10n.translate('no_data')));
          }

          final settings = settingsAsync.value ?? SettingsModel.defaultConfig();
          final menuItems = menuItemsAsync.value ?? [];
          final allOrders = ordersAsync.value ?? [];

          // Map MenuItem IDs to names for statistics output
          final Map<String, String> itemNames = {};
          final Map<String, double> itemPrices = {};
          for (final item in menuItems) {
            itemNames[item.id] = item.getName(ref.watch(localeProvider).languageCode);
            itemPrices[item.id] = item.price;
          }

          // Calculate Best & Least Selling items
          String bestSellingName = '-';
          int bestSellingQty = 0;
          String leastSellingName = '-';
          int leastSellingQty = 999999;

          stats.soldQuantities.forEach((itemId, qty) {
            final name = itemNames[itemId] ?? itemId;
            if (qty > bestSellingQty) {
              bestSellingQty = qty;
              bestSellingName = name;
            }
            if (qty < leastSellingQty && qty > 0) {
              leastSellingQty = qty;
              leastSellingName = name;
            }
          });

          if (leastSellingQty == 999999) {
            leastSellingQty = 0;
          }

          // Group today's paid orders hourly for the chart
          final List<double> hourlyRevenue = List.filled(24, 0.0);
          final now = DateTime.now();
          final todayOrders = allOrders.where((order) {
            if (order.status != 'paid' || order.paidAt == null) return false;
            final paidTime = order.paidAt!;
            return paidTime.year == now.year &&
                paidTime.month == now.month &&
                paidTime.day == now.day;
          }).toList();

          for (final order in todayOrders) {
            final hour = order.paidAt!.hour;
            hourlyRevenue[hour] += order.total;
          }

          // Top Selling Items ordered list
          final sortedSoldItems = stats.soldQuantities.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metrics grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 5 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                  children: [
                    _buildStatCard(
                      context,
                      l10n.translate('revenue'),
                      '${stats.revenue.toStringAsFixed(0)} ${settings.currency}',
                      Icons.monetization_on,
                      Colors.green,
                    ),
                    _buildStatCard(
                      context,
                      l10n.translate('orders_count'),
                      '${stats.ordersCount}',
                      Icons.receipt_long,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      context,
                      l10n.translate('avg_order'),
                      '${(stats.paidOrdersCount > 0 ? stats.revenue / stats.paidOrdersCount : 0.0).toStringAsFixed(0)} ${settings.currency}',
                      Icons.confirmation_num,
                      Colors.purple,
                    ),
                    _buildStatCard(
                      context,
                      l10n.translate('best_selling'),
                      bestSellingName,
                      Icons.star,
                      Colors.orange,
                      subtitle: bestSellingQty > 0 ? l10n.translate('sold_count').replaceAll('{count}', '$bestSellingQty') : null,
                    ),
                    _buildStatCard(
                      context,
                      l10n.translate('least_selling'),
                      leastSellingName,
                      Icons.trending_down,
                      Colors.grey,
                      subtitle: leastSellingQty > 0 ? l10n.translate('sold_count').replaceAll('{count}', '$leastSellingQty') : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Chart and Top Items side-by-side or stacked
                if (MediaQuery.of(context).size.width > 900)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildChartCard(context, hourlyRevenue, settings.currency, l10n),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildTopItemsCard(context, sortedSoldItems, itemNames, l10n),
                      ),
                    ],
                  )
                else ...[
                  _buildChartCard(context, hourlyRevenue, settings.currency, l10n),
                  const SizedBox(height: 24),
                  _buildTopItemsCard(context, sortedSoldItems, itemNames, l10n),
                ],
                const SizedBox(height: 32),

                // End Business Day Section
                Card(
                  color: Colors.red.shade900.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.red.shade900.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.translate('end_day'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.translate('end_day_confirm'),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _handleEndDay(context, ref, l10n),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            l10n.translate('end_day'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(l10n.translate('error_loading'))),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(
    BuildContext context,
    List<double> hourlyRevenue,
    String currency,
    AppLocalizations l10n,
  ) {
    // Find highest hourly revenue to scale chart
    double maxRevenue = 1000.0;
    for (final rev in hourlyRevenue) {
      if (rev > maxRevenue) maxRevenue = rev;
    }
    maxRevenue = (maxRevenue * 1.15).roundToDouble();

    // Map hourly data into BarChartGroups
    final List<BarChartGroupData> barGroups = [];
    // Only display business hours e.g. 11:00 to 23:00 to avoid clutter
    for (int hour = 9; hour <= 23; hour++) {
      barGroups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: hourlyRevenue[hour],
              color: AppTheme.primaryColor,
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('revenue_chart'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxRevenue,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.primaryColor.withValues(alpha: 0.9),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${group.x}:00\n${rod.toY.toStringAsFixed(0)} $currency',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('');
                          return Text(
                            '${value.toStringAsFixed(0)} $currency',
                            style: const TextStyle(fontSize: 8, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final int hour = value.toInt();
                          if (hour % 2 == 0) {
                            return Text('$hour:00', style: const TextStyle(fontSize: 9, color: Colors.grey));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopItemsCard(
    BuildContext context,
    List<MapEntry<String, int>> sortedSoldItems,
    Map<String, String> itemNames,
    AppLocalizations l10n,
  ) {
    final top10 = sortedSoldItems.take(10).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('top_selling'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (top10.isEmpty)
              SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    l10n.translate('no_data'),
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: top10.length,
                separatorBuilder: (context, index) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final entry = top10[index];
                  final name = itemNames[entry.key] ?? entry.key;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          l10n.translate('sold_count').replaceAll('{count}', '${entry.value}'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _handleEndDay(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('end_day')),
          content: Text(l10n.translate('end_day_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                
                // Show loading indicator dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final cashier = ref.read(currentAdminUserProvider).value?.name ?? 'Admin';
                  final pdfBytes = await ref.read(dailyStatisticsProvider.notifier).endBusinessDay(
                    cashierName: cashier,
                  );

                  if (context.mounted) {
                    Navigator.pop(context); // Close loading dialog
                    
                    // Show success & preview options
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.translate('success_operation')),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Open report preview
                    final pdfService = PdfService();
                    await pdfService.previewReport(pdfBytes, 'report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${l10n.translate('error_occurred')}: $e'),
                        backgroundColor: Colors.red,
                      ),
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
}
