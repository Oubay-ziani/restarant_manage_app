import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/daily_statistics_model.dart';
import '../../reports/models/daily_report_model.dart';
import '../../menu/providers/menu_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/l10n/app_localizations.dart';

class DashboardNotifier extends StateNotifier<AsyncValue<DailyStatisticsModel?>> {
  final Ref _ref;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DashboardNotifier(this._ref) : super(const AsyncValue.loading()) {
    _subscribeToStats();
  }

  void _subscribeToStats() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _db.collection('daily_statistics').doc(todayStr).snapshots().listen(
      (doc) {
        if (doc.exists && doc.data() != null) {
          state = AsyncValue.data(DailyStatisticsModel.fromMap(doc.data()!, doc.id));
        } else {
          state = AsyncValue.data(DailyStatisticsModel.empty(todayStr));
          // Proactively initialize with carry over if any!
          _initializeTodayStatsWithCarryOver(todayStr);
        }
      },
      onError: (err, stack) {
        state = AsyncValue.error(err, stack);
      },
    );
  }

  Future<void> _initializeTodayStatsWithCarryOver(String todayStr) async {
    try {
      final statsRef = _db.collection('daily_statistics').doc(todayStr);
      final now = DateTime.now();

      // Check previous days one by one — no composite index needed
      DocumentSnapshot? carryOverDoc;
      for (int i = 1; i <= 7; i++) {
        final prevStr = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
        final doc = await _db.collection('daily_statistics').doc(prevStr).get();
        if (doc.exists && doc.data() != null) {
          final double rev = (doc.data()!['revenue'] as num?)?.toDouble() ?? 0.0;
          if (rev > 0) {
            carryOverDoc = doc;
            break;
          }
        }
      }

      if (carryOverDoc != null) {
        await _db.runTransaction((transaction) async {
          final todaySnap = await transaction.get(statsRef);
          if (!todaySnap.exists) {
            final carrySnap = await transaction.get(carryOverDoc!.reference);
            if (carrySnap.exists && carrySnap.data() != null) {
              final carryData = Map<String, dynamic>.from(carrySnap.data()! as Map<String, dynamic>);
              
              transaction.set(statsRef, {
                'revenue': (carryData['revenue'] as num?)?.toDouble() ?? 0.0,
                'ordersCount': (carryData['ordersCount'] as num?)?.toInt() ?? 0,
                'paidOrdersCount': (carryData['paidOrdersCount'] as num?)?.toInt() ?? 0,
                'cancelledOrdersCount': (carryData['cancelledOrdersCount'] as num?)?.toInt() ?? 0,
                'soldQuantities': carryData['soldQuantities'] ?? {},
              });

              transaction.update(carryOverDoc.reference, {
                'revenue': 0.0,
                'ordersCount': 0,
                'paidOrdersCount': 0,
                'cancelledOrdersCount': 0,
                'soldQuantities': {},
              });
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize today stats with carry over: $e');
    }
  }

  // End Business Day: Generate PDF, archive report, reset table statuses, reset stats
  Future<Uint8List> endBusinessDay({required String cashierName}) async {
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // 1. Fetch current settings, statistics, and menu items
      final settings = _ref.read(settingsProvider).value ?? _ref.read(settingsProvider.notifier).state.value!;
      final currentStats = state.value ?? DailyStatisticsModel.empty(todayStr);
      final menuItems = _ref.read(menuItemsStreamProvider).value ?? [];

      // 2. Map items data for PDF and report document
      final Map<String, String> itemNames = {};
      final Map<String, double> itemPrices = {};
      final List<Map<String, dynamic>> itemsSoldReport = [];

      for (final item in menuItems) {
        itemNames[item.id] = item.name['en'] ?? '';
        itemPrices[item.id] = item.price;
      }

      currentStats.soldQuantities.forEach((itemId, qty) {
        final name = itemNames[itemId] ?? itemId;
        itemsSoldReport.add({
          'menuItemId': itemId,
          'name': name,
          'quantity': qty,
        });
      });

      // 3. Generate Daily Report PDF
      final pdfService = PdfService();
      final Uint8List pdfBytes = await pdfService.generateDailyReportPdf(
        restaurantName: settings.restaurantName,
        date: todayStr,
        totalRevenue: currentStats.revenue,
        totalOrders: currentStats.ordersCount,
        paidOrders: currentStats.paidOrdersCount,
        cancelledOrders: currentStats.cancelledOrdersCount,
        itemSalesQuantities: currentStats.soldQuantities,
        itemNames: itemNames,
        itemPrices: itemPrices,
        currency: settings.currency,
        languageCode: _ref.read(localeProvider).languageCode,
      );

      // 4. Encode PDF as base64 to store inline in Firestore (no Storage needed)
      final String pdfBase64 = base64Encode(pdfBytes);

      // 5. Save report to Firestore archives (PDF stored inline as base64)
      final newReport = DailyReportModel(
        id: '',
        dateString: todayStr,
        timestamp: DateTime.now(),
        revenue: currentStats.revenue,
        ordersCount: currentStats.ordersCount,
        paidOrders: currentStats.paidOrdersCount,
        cancelledOrders: currentStats.cancelledOrdersCount,
        itemsSold: itemsSoldReport,
        pdfBase64: pdfBase64,
      );

      await _db.collection('daily_reports').add(newReport.toMap());

      // 6. Active unpaid orders and tables remain OPEN across business day closing.
      // Ending the day archives today's sales statistics and generates a PDF report,
      // without closing active accounts (unpaid orders remain unpaid for the next shift).

      // 7. Reset daily statistics doc for today
      await _db.collection('daily_statistics').doc(todayStr).set(
        DailyStatisticsModel.empty(todayStr).toMap(),
      );

      return pdfBytes;
    } catch (e) {
      debugPrint('End of day failed: $e');
      rethrow;
    }
  }
}

// Riverpod Providers
final dailyStatisticsProvider = StateNotifierProvider<DashboardNotifier, AsyncValue<DailyStatisticsModel?>>((ref) {
  return DashboardNotifier(ref);
});

// Stream of reports for historical search
final dailyReportsStreamProvider = StreamProvider<List<DailyReportModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('daily_reports')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => DailyReportModel.fromMap(doc.data(), doc.id))
        .toList();
  });
});
