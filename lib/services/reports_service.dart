import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:aushadhi_tracker/core/database/local_db.dart';
import 'package:intl/intl.dart';

class ReportsService {
  // Generate and Share CSV
  Future<void> generateAndShareCSV(List<MedicineBatch> batches) async {
    List<List<dynamic>> rows = [];
    
    // Headers
    rows.add(["Batch Number", "Medicine ID", "Expiry Date", "Quantity", "Status"]);

    // Data Rows
    for (var batch in batches) {
      final daysLeft = batch.expiryDate.difference(DateTime.now()).inDays;
      String status = daysLeft <= 90 ? 'Expiring Soon' : 'Safe';
      if (daysLeft < 0) status = 'EXPIRED';

      rows.add([
        batch.batchNumber,
        batch.medicineId,
        DateFormat('yyyy-MM-dd').format(batch.expiryDate),
        batch.quantity,
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
  Future<void> generateAndSharePDF(List<MedicineBatch> batches) async {
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
                headers: ['Batch No.', 'Expiry Date', 'Qty', 'Status'],
                data: batches.map((batch) {
                  final daysLeft = batch.expiryDate.difference(DateTime.now()).inDays;
                  String status = daysLeft <= 90 ? 'Warning' : 'OK';
                  if (daysLeft < 0) status = 'EXPIRED';

                  return [
                    batch.batchNumber,
                    DateFormat('dd/MM/yyyy').format(batch.expiryDate),
                    batch.quantity.toString(),
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
                  2: pw.Alignment.centerRight, // Align Qty to right
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
