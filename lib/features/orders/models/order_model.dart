import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_item_model.dart';

class OrderModel {
  final String id;
  final String orderNumber;
  final int tableNumber;
  final DateTime timestamp;
  final List<OrderItemModel> items;
  final String? notes;
  final double total;
  final String status; // "unpaid", "paid", "cancelled"
  final String? paymentMethod; // "cash", "card", "mixed"
  final DateTime? paidAt;
  final String? cashierName;
  final String? originalOrderId;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.tableNumber,
    required this.timestamp,
    required this.items,
    this.notes,
    required this.total,
    required this.status,
    this.paymentMethod,
    this.paidAt,
    this.cashierName,
    this.originalOrderId,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts = DateTime.now();
    if (map['timestamp'] != null) {
      if (map['timestamp'] is Timestamp) {
        ts = (map['timestamp'] as Timestamp).toDate();
      } else if (map['timestamp'] is String) {
        ts = DateTime.tryParse(map['timestamp']) ?? DateTime.now();
      }
    }

    DateTime? paidTime;
    if (map['paidAt'] != null) {
      if (map['paidAt'] is Timestamp) {
        paidTime = (map['paidAt'] as Timestamp).toDate();
      } else if (map['paidAt'] is String) {
        paidTime = DateTime.tryParse(map['paidAt']);
      }
    }

    final rawItems = map['items'] as List<dynamic>? ?? [];
    final List<OrderItemModel> parsedItems = rawItems
        .map((e) => OrderItemModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return OrderModel(
      id: id,
      orderNumber: map['orderNumber'] ?? '',
      tableNumber: map['tableNumber'] ?? 0,
      timestamp: ts,
      items: parsedItems,
      notes: map['notes'],
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'unpaid',
      paymentMethod: map['paymentMethod'],
      paidAt: paidTime,
      cashierName: map['cashierName'],
      originalOrderId: map['originalOrderId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderNumber': orderNumber,
      'tableNumber': tableNumber,
      'timestamp': Timestamp.fromDate(timestamp),
      'items': items.map((e) => e.toMap()).toList(),
      'notes': notes,
      'total': total,
      'status': status,
      'paymentMethod': paymentMethod,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'cashierName': cashierName,
      'originalOrderId': originalOrderId,
    };
  }

  OrderModel copyWith({
    String? status,
    String? paymentMethod,
    DateTime? paidAt,
    String? cashierName,
    List<OrderItemModel>? items,
    double? total,
    String? notes,
    int? tableNumber,
  }) {
    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      tableNumber: tableNumber ?? this.tableNumber,
      timestamp: timestamp,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      total: total ?? this.total,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAt: paidAt ?? this.paidAt,
      cashierName: cashierName ?? this.cashierName,
      originalOrderId: originalOrderId,
    );
  }
}
