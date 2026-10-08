import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class PdfService {
  // Generates PDF bytes for a Daily Report
  Future<Uint8List> generateDailyReportPdf({
    required String restaurantName,
    required String date,
    required double totalRevenue,
    required int totalOrders,
    required int paidOrders,
    required int cancelledOrders,
    required Map<String, int> itemSalesQuantities,
    required Map<String, String> itemNames,
    required Map<String, double> itemPrices,
    required String currency,
    String languageCode = 'en',
  }) async {
    final pdf = pw.Document();

    final String reportTitle = languageCode == 'fr'
        ? 'Rapport de Fin de Journee'
        : languageCode == 'ar'
            ? 'Rapport de Fin de Journee'
            : 'Daily End-Of-Day Report';
    final String dateLabel = languageCode == 'fr' ? 'Date' : languageCode == 'ar' ? 'Date' : 'Date';
    final String genLabel = languageCode == 'fr' ? 'Genere le' : languageCode == 'ar' ? 'Genere le' : 'Generated';
    final String metricsSummary = languageCode == 'fr'
        ? 'Resume des Metriques'
        : languageCode == 'ar'
            ? 'Resume des Metriques'
            : 'Business Metrics Summary';
    final String totalRevLabel = languageCode == 'fr' ? 'Revenu Total' : languageCode == 'ar' ? 'Total Revenue' : 'Total Revenue';
    final String paidOrdersLabel = languageCode == 'fr' ? 'Commandes Payees' : languageCode == 'ar' ? 'Paid Orders' : 'Paid Orders';
    final String cancelledOrdersLabel = languageCode == 'fr' ? 'Commandes Annulees' : languageCode == 'ar' ? 'Cancelled Orders' : 'Cancelled Orders';
    final String totalOrdersLabel = languageCode == 'fr' ? 'Total Commandes' : languageCode == 'ar' ? 'Total Orders' : 'Total Orders';
    final String avgTicketLabel = languageCode == 'fr' ? 'Panier Moyen' : languageCode == 'ar' ? 'Average Ticket' : 'Average Ticket';
    final String breakdownTitle = languageCode == 'fr'
        ? 'Ventes par Article'
        : languageCode == 'ar'
            ? 'Sales Breakdown'
            : 'Sales Breakdown by Grill Item';
    final String colItem = languageCode == 'fr' ? 'Article' : languageCode == 'ar' ? 'Item' : 'Grill Item Name';
    final String colQty = languageCode == 'fr' ? 'Qte Vendu' : languageCode == 'ar' ? 'Qty' : 'Qty Sold';
    final String colPrice = languageCode == 'fr' ? 'Prix' : languageCode == 'ar' ? 'Price' : 'Price';
    final String colSubtotal = languageCode == 'fr' ? 'Sous-total' : languageCode == 'ar' ? 'Total' : 'Subtotal';

    // Calculate details
    final avgOrder = totalOrders > 0 ? (totalRevenue / paidOrders) : 0.0;
    
    // Sort items by quantities sold
    final sortedSales = itemSalesQuantities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Title Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      restaurantName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.deepOrange,
                      ),
                    ),
                    pw.Text(
                      reportTitle,
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '$dateLabel: $date',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '$genLabel: ${DateTime.now().toLocal().toString().substring(0, 16)}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 2, color: PdfColors.deepOrange),
            pw.SizedBox(height: 16),

            // Metrics Summary Grid
            pw.Text(
              metricsSummary,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.GridView(
              crossAxisCount: 3,
              childAspectRatio: 0.4,
              children: [
                _buildMetricCard(totalRevLabel, '${totalRevenue.toStringAsFixed(2)} $currency', PdfColors.green900),
                _buildMetricCard(paidOrdersLabel, '$paidOrders', PdfColors.blue900),
                _buildMetricCard(cancelledOrdersLabel, '$cancelledOrders', PdfColors.red900),
                _buildMetricCard(totalOrdersLabel, '$totalOrders', PdfColors.grey800),
                _buildMetricCard(avgTicketLabel, '${avgOrder.toStringAsFixed(2)} $currency', PdfColors.purple900),
              ],
            ),
            pw.SizedBox(height: 24),

            // Item Sales Details Table
            pw.Text(
              breakdownTitle,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(colItem, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(colQty, style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(colPrice, style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(colSubtotal, style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                // Table Rows
                ...sortedSales.map((entry) {
                  final itemId = entry.key;
                  final qty = entry.value;
                  final name = itemNames[itemId] ?? itemId;
                  final price = itemPrices[itemId] ?? 0.0;
                  final subtotal = price * qty;

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(name),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('$qty', textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(price.toStringAsFixed(2), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${subtotal.toStringAsFixed(2)} $currency', textAlign: pw.TextAlign.right),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 32),

            // Footer section
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'This report was generated automatically by BBQ POS & Grill Manager.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
              ),
            ),
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'End-of-day closing constitutes complete data freeze.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Card view helper inside PDF
  static pw.Widget _buildMetricCard(String title, String value, PdfColor textColor) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(4),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  // Previews report PDF directly in the App
  Future<void> previewReport(Uint8List pdfBytes, String filename) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: filename,
    );
  }

  // Saves daily PDF to local filesystem for downloading
  Future<String> savePdfLocally(Uint8List pdfBytes, String filename) async {
    if (kIsWeb) {
      // Direct Web Download trigger via printing package
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      return 'Web download triggered';
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  // Share report PDF to other applications (Email, WhatsApp, etc)
  Future<void> shareReport(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }
}
