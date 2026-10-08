import 'package:cloud_firestore/cloud_firestore.dart';

class TableModel {
  final String id;
  final int number;
  final String status; // "empty", "occupied", "unpaid"
  final int unpaidOrdersCount;
  final double currentTotal;
  final DateTime? lastOrderTime;

  TableModel({
    required this.id,
    required this.number,
    required this.status,
    required this.unpaidOrdersCount,
    required this.currentTotal,
    this.lastOrderTime,
  });

  factory TableModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime? lastOrder;
    if (map['lastOrderTime'] != null) {
      if (map['lastOrderTime'] is Timestamp) {
        lastOrder = (map['lastOrderTime'] as Timestamp).toDate();
      } else if (map['lastOrderTime'] is String) {
        lastOrder = DateTime.tryParse(map['lastOrderTime']);
      }
    }
    return TableModel(
      id: id,
      number: map['number'] ?? 0,
      status: map['status'] ?? 'empty',
      unpaidOrdersCount: map['unpaidOrdersCount'] ?? 0,
      currentTotal: (map['currentTotal'] as num?)?.toDouble() ?? 0.0,
      lastOrderTime: lastOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'status': status,
      'unpaidOrdersCount': unpaidOrdersCount,
      'currentTotal': currentTotal,
      'lastOrderTime': lastOrderTime != null ? Timestamp.fromDate(lastOrderTime!) : null,
    };
  }

  TableModel copyWith({
    String? status,
    int? unpaidOrdersCount,
    double? currentTotal,
    DateTime? lastOrderTime,
  }) {
    return TableModel(
      id: id,
      number: number,
      status: status ?? this.status,
      unpaidOrdersCount: unpaidOrdersCount ?? this.unpaidOrdersCount,
      currentTotal: currentTotal ?? this.currentTotal,
      lastOrderTime: lastOrderTime ?? this.lastOrderTime,
    );
  }
}
