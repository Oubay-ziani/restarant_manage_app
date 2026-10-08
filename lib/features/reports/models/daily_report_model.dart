import 'package:cloud_firestore/cloud_firestore.dart';

class DailyReportModel {
  final String id;
  final String dateString;
  final DateTime timestamp;
  final double revenue;
  final int ordersCount;
  final int paidOrders;
  final int cancelledOrders;
  final List<Map<String, dynamic>> itemsSold;
  final String? pdfBase64; // PDF bytes stored as base64 in Firestore

  DailyReportModel({
    required this.id,
    required this.dateString,
    required this.timestamp,
    required this.revenue,
    required this.ordersCount,
    required this.paidOrders,
    required this.cancelledOrders,
    required this.itemsSold,
    this.pdfBase64,
  });

  factory DailyReportModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts = DateTime.now();
    if (map['timestamp'] != null) {
      if (map['timestamp'] is Timestamp) {
        ts = (map['timestamp'] as Timestamp).toDate();
      } else if (map['timestamp'] is String) {
        ts = DateTime.tryParse(map['timestamp']) ?? DateTime.now();
      }
    }

    final rawItems = map['itemsSold'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> parsedItems = rawItems
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return DailyReportModel(
      id: id,
      dateString: map['dateString'] ?? '',
      timestamp: ts,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
      ordersCount: map['ordersCount'] ?? 0,
      paidOrders: map['paidOrders'] ?? 0,
      cancelledOrders: map['cancelledOrders'] ?? 0,
      itemsSold: parsedItems,
      pdfBase64: map['pdfBase64'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dateString': dateString,
      'timestamp': Timestamp.fromDate(timestamp),
      'revenue': revenue,
      'ordersCount': ordersCount,
      'paidOrders': paidOrders,
      'cancelledOrders': cancelledOrders,
      'itemsSold': itemsSold,
      'pdfBase64': pdfBase64,
    };
  }
}
