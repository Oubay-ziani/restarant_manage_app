class SettingsModel {
  final String restaurantName;
  final String? logoUrl;
  final String currency;
  final double taxPercentage;
  final double serviceCharge;
  final String? bluetoothAddress;
  final String? wifiPrinterIp;
  final int wifiPrinterPort;
  final int paperWidth; // 58 or 80

  SettingsModel({
    required this.restaurantName,
    this.logoUrl,
    required this.currency,
    required this.taxPercentage,
    required this.serviceCharge,
    this.bluetoothAddress,
    this.wifiPrinterIp,
    required this.wifiPrinterPort,
    required this.paperWidth,
  });

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      restaurantName: map['restaurantName'] ?? 'La Terrasse Plus',
      logoUrl: map['logoUrl'],
      currency: map['currency'] ?? 'DA',
      taxPercentage: (map['taxPercentage'] as num?)?.toDouble() ?? 0.0,
      serviceCharge: (map['serviceCharge'] as num?)?.toDouble() ?? 0.0,
      bluetoothAddress: map['bluetoothAddress'],
      wifiPrinterIp: map['wifiPrinterIp'] ?? '192.168.1.100',
      wifiPrinterPort: (map['wifiPrinterPort'] as num?)?.toInt() ?? 9100,
      paperWidth: (map['paperWidth'] as num?)?.toInt() ?? 80,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurantName': restaurantName,
      'logoUrl': logoUrl,
      'currency': currency,
      'taxPercentage': taxPercentage,
      'serviceCharge': serviceCharge,
      'bluetoothAddress': bluetoothAddress,
      'wifiPrinterIp': wifiPrinterIp,
      'wifiPrinterPort': wifiPrinterPort,
      'paperWidth': paperWidth,
    };
  }

  factory SettingsModel.defaultConfig() {
    return SettingsModel(
      restaurantName: 'La Terrasse Plus',
      currency: 'DA',
      taxPercentage: 0.0,
      serviceCharge: 0.0,
      wifiPrinterIp: '192.168.1.100',
      wifiPrinterPort: 9100,
      paperWidth: 80,
    );
  }
}
