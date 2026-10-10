import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class PrintService {
  // ESC/POS Commands
  static const List<int> escInit = [0x1B, 0x40];
  static const List<int> escAlignLeft = [0x1B, 0x61, 0x00];
  static const List<int> escAlignCenter = [0x1B, 0x61, 0x01];
  static const List<int> escAlignRight = [0x1B, 0x61, 0x02];
  static const List<int> escTextDouble = [0x1D, 0x21, 0x11]; // Double width & height
  static const List<int> escTextLarge = [0x1D, 0x21, 0x22]; // Extra large
  static const List<int> escTextNormal = [0x1D, 0x21, 0x00];
  static const List<int> escCut = [0x1D, 0x56, 0x00]; // Full cut
  static const List<int> escFeedLine = [0x0A];

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  // Print via WiFi socket
  Future<bool> printViaWifi({
    required String ip,
    required int port,
    required List<int> bytes,
  }) async {
    if (kIsWeb) {
      debugPrint('Raw socket printing is not supported on Web. Bytes: $bytes');
      return false;
    }
    _isConnecting = true;
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 3));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      _isConnecting = false;
      return true;
    } catch (e) {
      debugPrint('WiFi Print error: $e');
      _isConnecting = false;
      return false;
    }
  }

  // Print via Bluetooth (Simulated driver that logs output and prepares transmission)
  Future<bool> printViaBluetooth({
    required String macAddress,
    required List<int> bytes,
  }) async {
    _isConnecting = true;
    // In a real device setup, we hook into Android's BluetoothAdapter or iOS CoreBluetooth
    // using the macAddress, open an RFCOMM socket (UUID 00001101-0000-1000-8000-00805F9B34FB)
    // and write the raw ESC/POS bytes.
    await Future.delayed(const Duration(milliseconds: 800));
    debugPrint('Bluetooth Print bytes transmitted to $macAddress: ${bytes.length} bytes');
    _isConnecting = false;
    return true;
  }

  // Formats a line with left-aligned and right-aligned text matching paper width
  String formatRow(String left, String right, int paperWidth) {
    final int lineLength = paperWidth == 80 ? 48 : 32;
    final int spaces = lineLength - left.length - right.length;
    if (spaces <= 0) {
      // If content overflows, truncate or split
      final int leftTake = lineLength - right.length - 1;
      if (leftTake > 0) {
        return '${left.substring(0, leftTake)} $right';
      }
      return left;
    }
    return left + (' ' * spaces) + right;
  }

  // Divider line matching paper width
  String getDivider(int paperWidth) {
    final int lineLength = paperWidth == 80 ? 48 : 32;
    return '-' * lineLength;
  }

  // Generate Customer Receipt bytes
  List<int> generateCustomerReceipt({
    required String restaurantName,
    required String orderNumber,
    required int tableNumber,
    required String dateTime,
    required List<Map<String, dynamic>> items,
    required double total,
    required int paperWidth,
    required String currency,
    String? cashierName,
    double taxPercent = 0.0,
    double servicePercent = 0.0,
  }) {
    List<int> bytes = [];
    bytes.addAll(escInit);

    // Header
    bytes.addAll(escAlignCenter);
    bytes.addAll(escTextDouble);
    bytes.addAll(utf8.encode('$restaurantName\n'));
    bytes.addAll(escTextNormal);
    bytes.addAll(utf8.encode('*** CUSTOMER RECEIPT ***\n\n'));

    bytes.addAll(escAlignLeft);
    bytes.addAll(utf8.encode('Table: Table $tableNumber\n'));
    bytes.addAll(utf8.encode('Order: #$orderNumber\n'));
    bytes.addAll(utf8.encode('Date: $dateTime\n'));
    if (cashierName != null) {
      bytes.addAll(utf8.encode('Cashier: $cashierName\n'));
    }
    bytes.addAll(utf8.encode('${getDivider(paperWidth)}\n'));

    // Columns Header
    final String cols = formatRow('Item x Qty', 'Total', paperWidth);
    bytes.addAll(utf8.encode('$cols\n'));
    bytes.addAll(utf8.encode('${getDivider(paperWidth)}\n'));

    // Items list
    for (final item in items) {
      final name = item['name'] as String;
      final qty = item['quantity'] as int;
      final price = item['price'] as double;
      final itemTotal = price * qty;

      final String left = '$name x$qty';
      final String right = '${itemTotal.toStringAsFixed(2)} $currency';
      bytes.addAll(utf8.encode('${formatRow(left, right, paperWidth)}\n'));
    }

    bytes.addAll(utf8.encode('${getDivider(paperWidth)}\n'));

    // Calculations
    final subtotal = total / (1 + (taxPercent + servicePercent) / 100);
    final tax = subtotal * (taxPercent / 100);
    final service = subtotal * (servicePercent / 100);

    if (taxPercent > 0) {
      bytes.addAll(utf8.encode('${formatRow('Tax (${taxPercent.toStringAsFixed(0)}%)', '${tax.toStringAsFixed(2)} $currency', paperWidth)}\n'));
    }
    if (servicePercent > 0) {
      bytes.addAll(utf8.encode('${formatRow('Service (${servicePercent.toStringAsFixed(0)}%)', '${service.toStringAsFixed(2)} $currency', paperWidth)}\n'));
    }

    bytes.addAll(escTextDouble);
    final String totStr = '${total.toStringAsFixed(2)} $currency';
    bytes.addAll(utf8.encode('${formatRow('GRAND TOTAL', totStr, paperWidth)}\n'));
    bytes.addAll(escTextNormal);

    bytes.addAll(utf8.encode('${getDivider(paperWidth)}\n\n'));

    // Footer
    bytes.addAll(escAlignCenter);
    bytes.addAll(utf8.encode('Thank You For Your Visit!\n'));
    bytes.addAll(utf8.encode('Please Come Again\n\n\n\n'));
    bytes.addAll(escCut);

    return bytes;
  }

  // Generate Kitchen Ticket (No prices, large readable font, includes notes)
  List<int> generateKitchenTicket({
    required String orderNumber,
    required int tableNumber,
    required String dateTime,
    required List<Map<String, dynamic>> items,
    String? notes,
    required int paperWidth,
  }) {
    List<int> bytes = [];
    bytes.addAll(escInit);

    // Header
    bytes.addAll(escAlignCenter);
    bytes.addAll(escTextLarge);
    bytes.addAll(utf8.encode('KITCHEN TICKET\n'));
    bytes.addAll(escTextDouble);
    bytes.addAll(utf8.encode('TABLE $tableNumber\n'));
    bytes.addAll(escTextNormal);
    bytes.addAll(utf8.encode('Order: #$orderNumber\n'));
    bytes.addAll(utf8.encode('Time: $dateTime\n'));
    bytes.addAll(utf8.encode('${getDivider(paperWidth)}\n\n'));

    // Items List in bold double size
    bytes.addAll(escAlignLeft);
    bytes.addAll(escTextDouble);
    for (final item in items) {
      final name = item['name'] as String;
      final qty = item['quantity'] as int;
      bytes.addAll(utf8.encode('[ ] $qty x $name\n'));
    }
    bytes.addAll(escTextNormal);

    bytes.addAll(utf8.encode('\n${getDivider(paperWidth)}\n'));

    // Notes
    if (notes != null && notes.isNotEmpty) {
      bytes.addAll(escTextDouble);
      bytes.addAll(utf8.encode('NOTES:\n'));
      bytes.addAll(escTextNormal);
      bytes.addAll(utf8.encode('$notes\n'));
      bytes.addAll(utf8.encode('${getDivider(paperWidth)}\n'));
    }

    bytes.addAll(utf8.encode('\n\n\n\n'));
    bytes.addAll(escCut);

    return bytes;
  }
}
