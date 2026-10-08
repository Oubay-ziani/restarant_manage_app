import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/daily_report_model.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/models/settings_model.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/pdf_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime? _selectedDate;
  String _searchQuery = '';

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDate = null;
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final reportsAsync = ref.watch(dailyReportsStreamProvider);
    final settings = ref.watch(settingsProvider).value ?? SettingsModel.defaultConfig();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('reports'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectDate(context),
          ),
          if (_selectedDate != null || _searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: '${l10n.translate('search_by_date')} (e.g. 2026-08)',
                prefixIcon: const Icon(Icons.search),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            ),
          ),

          // Date indicator
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  Chip(
                    label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate!)),
                    onDeleted: () => setState(() => _selectedDate = null),
                  ),
                ],
              ),
            ),

          Expanded(
            child: reportsAsync.when(
              data: (reports) {
                // Client-side date filters
                final filtered = reports.where((rep) {
                  // Date Picker Filter
                  if (_selectedDate != null) {
                    final pickerStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
                    if (rep.dateString != pickerStr) return false;
                  }

                  // Manual Text Filter (Year, Month, etc)
                  if (_searchQuery.isNotEmpty) {
                    if (!rep.dateString.contains(_searchQuery)) return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.translate('no_data'),
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final report = filtered[index];
                    return _buildReportItem(context, report, settings, l10n);
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

  Widget _buildReportItem(
    BuildContext context,
    DailyReportModel report,
    SettingsModel settings,
    AppLocalizations l10n,
  ) {
    final currency = l10n.translate('currency');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Date & Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  report.dateString,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                Text(
                  '${report.revenue.toStringAsFixed(0)} $currency',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryColor, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 20),
            // Statistics details
            Row(
              children: [
                Expanded(child: _buildStatLabel(l10n.translate('orders_count'), '${report.ordersCount}')),
                Expanded(child: _buildStatLabel(l10n.translate('paid'), '${report.paidOrders}')),
                Expanded(child: _buildStatLabel(l10n.translate('cancelled'), '${report.cancelledOrders}')),
              ],
            ),
            const SizedBox(height: 16),
            // PDF sharing actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _handlePdfAction(report, settings, 'preview'),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: Text(l10n.translate('preview'), style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _handlePdfAction(report, settings, 'download'),
                  icon: const Icon(Icons.download, size: 16),
                  label: Text(l10n.translate('download'), style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _handlePdfAction(report, settings, 'share'),
                  icon: const Icon(Icons.share, size: 16),
                  label: Text(l10n.translate('share'), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatLabel(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Generates and triggers action on PDF bytes
  Future<void> _handlePdfAction(DailyReportModel report, SettingsModel settings, String action) async {
    // Show loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfService = PdfService();
      
      // We map the items list back to maps
      final Map<String, int> itemSales = {};
      final Map<String, String> itemNames = {};
      final Map<String, double> itemPrices = {};

      for (final item in report.itemsSold) {
        final String itemId = item['menuItemId'] ?? '';
        final String name = item['name'] ?? '';
        final int qty = (item['quantity'] as num).toInt();
        itemSales[itemId] = qty;
        itemNames[itemId] = name;
        itemPrices[itemId] = 0.0; // historical price mapping placeholder
      }

      final pdfBytes = await pdfService.generateDailyReportPdf(
        restaurantName: settings.restaurantName,
        date: report.dateString,
        totalRevenue: report.revenue,
        totalOrders: report.ordersCount,
        paidOrders: report.paidOrders,
        cancelledOrders: report.cancelledOrders,
        itemSalesQuantities: itemSales,
        itemNames: itemNames,
        itemPrices: itemPrices,
        currency: settings.currency,
      );

      if (mounted) {
        Navigator.pop(context); // Close loader
        
        final filename = 'report_${report.dateString.replaceAll('-', '')}.pdf';
        
        if (action == 'preview') {
          await pdfService.previewReport(pdfBytes, filename);
        } else if (action == 'download') {
          final path = await pdfService.savePdfLocally(pdfBytes, filename);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved to: $path'), backgroundColor: Colors.green),
            );
          }
        } else if (action == 'share') {
          await pdfService.shareReport(pdfBytes, filename);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
