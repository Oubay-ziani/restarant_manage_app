class DailyStatisticsModel {
  final String dateString; // "YYYY-MM-DD"
  final double revenue;
  final int ordersCount;
  final int paidOrdersCount;
  final int cancelledOrdersCount;
  final Map<String, int> soldQuantities; // menuItemId -> quantity sold

  DailyStatisticsModel({
    required this.dateString,
    required this.revenue,
    required this.ordersCount,
    required this.paidOrdersCount,
    required this.cancelledOrdersCount,
    required this.soldQuantities,
  });

  factory DailyStatisticsModel.fromMap(Map<String, dynamic> map, String id) {
    final Map<String, int> qs = {};
    if (map['soldQuantities'] is Map) {
      (map['soldQuantities'] as Map).forEach((key, val) {
        qs[key.toString()] = (val as num).toInt();
      });
    }

    return DailyStatisticsModel(
      dateString: id,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
      ordersCount: map['ordersCount'] ?? 0,
      paidOrdersCount: map['paidOrdersCount'] ?? 0,
      cancelledOrdersCount: map['cancelledOrdersCount'] ?? 0,
      soldQuantities: qs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'revenue': revenue,
      'ordersCount': ordersCount,
      'paidOrdersCount': paidOrdersCount,
      'cancelledOrdersCount': cancelledOrdersCount,
      'soldQuantities': soldQuantities,
    };
  }

  // Create an empty starting state for a new day
  factory DailyStatisticsModel.empty(String dateStr) {
    return DailyStatisticsModel(
      dateString: dateStr,
      revenue: 0.0,
      ordersCount: 0,
      paidOrdersCount: 0,
      cancelledOrdersCount: 0,
      soldQuantities: {},
    );
  }
}
