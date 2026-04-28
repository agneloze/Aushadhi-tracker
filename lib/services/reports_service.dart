import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ReportsService {
  // Generate and Share CSV
  Future<void> generateAndShareCSV(List<Map<String, dynamic>> batches) async {
    List<List<dynamic>> rows = [];
    
    // Headers
    rows.add(["Batch Name", "Drug Code", "Expiry Date", "Scanned At", "Status"]);

    // Data Rows
    for (var batch in batches) {
      final expiryDate = batch['expiry_date'] != null ? DateTime.parse(batch['expiry_date']) : DateTime.now();
      final scannedAt = batch['scanned_at'] != null ? DateTime.parse(batch['scanned_at']) : DateTime.now();
      final daysLeft = expiryDate.difference(DateTime.now()).inDays;
      String status = daysLeft <= 90 ? 'Expiring Soon' : 'Safe';
      if (daysLeft < 0) status = 'EXPIRED';

      rows.add([
        batch['batch_name'] ?? 'N/A',
        batch['drug_code'] ?? 'N/A',
        DateFormat('yyyy-MM-dd').format(expiryDate),
        DateFormat('yyyy-MM-dd').format(scannedAt),
        status,
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/aushadhi_inventory_report.csv";
    final File file = File(path);
    await file.writeAsString(csv);

    // Share the file
    await Share.shareXFiles([XFile(path)], text: 'Jan Aushadhi Inventory CSV Report');
  }

  // Generate and Share PDF
  Future<void> generateAndSharePDF(List<Map<String, dynamic>> batches) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Aushadhi Tracker - Inventory Report', 
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Date Generated: ${DateFormat('dd-MMM-yyyy').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              
              // Table
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Batch Name', 'Drug Code', 'Expiry Date', 'Status'],
                data: batches.map((batch) {
                  final expiryDate = batch['expiry_date'] != null ? DateTime.parse(batch['expiry_date']) : DateTime.now();
                  final daysLeft = expiryDate.difference(DateTime.now()).inDays;
                  String status = daysLeft <= 90 ? 'Warning' : 'OK';
                  if (daysLeft < 0) status = 'EXPIRED';

                  return [
                    batch['batch_name']?.toString() ?? 'N/A',
                    batch['drug_code']?.toString() ?? 'N/A',
                    DateFormat('dd/MM/yyyy').format(expiryDate),
                    status,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: .5)),
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  2: pw.Alignment.centerRight, // Align Date to right
                },
              ),
            ],
          );
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/aushadhi_inventory_report.pdf";
    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    // Share the file
    await Share.shareXFiles([XFile(path)], text: 'Jan Aushadhi Inventory PDF Report');
  }
}
