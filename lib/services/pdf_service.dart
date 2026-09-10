import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../repositories/ledger_repository.dart';
import '../repositories/report_repository.dart';
import '../utils/formatters.dart';

/// Renders reports to PDF for sharing/printing. Uses plain text formatting
/// (no custom fonts) so it works out of the box on any Android device.
class PdfService {
  Future<Directory> _reportsDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(documentsDir.path, 'reports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _save(String fileName, pw.Document doc) async {
    final dir = await _reportsDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(await doc.save());
    return file;
  }

  Future<File> generateMonthlyReport(MonthlyReport report) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Monthly Report: ${formatBillingMonthLabel(report.billingMonth)}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  pw.TableRow(children: [
                    _cell('Room', bold: true),
                    _cell('Rent', bold: true),
                    _cell('Electricity', bold: true),
                    _cell('Total', bold: true),
                  ]),
                  ...report.lines.map((l) => pw.TableRow(children: [
                        _cell(l.roomNumber),
                        _cell(formatCurrency(l.rent)),
                        _cell(formatCurrency(l.electricity)),
                        _cell(formatCurrency(l.total)),
                      ])),
                ],
              ),
              pw.SizedBox(height: 16),
              _summaryLine('Total Rent', report.totalRent),
              _summaryLine('Total Electricity', report.totalElectricity),
              _summaryLine('Total Collection', report.totalCollection),
              _summaryLine('Total Expenses', report.totalExpenses),
              pw.Divider(),
              _summaryLine('Net Collection', report.netCollection, bold: true),
            ],
          );
        },
      ),
    );
    return _save('monthly_report_${report.billingMonth}.pdf', doc);
  }

  Future<File> generateTenantLedger(String tenantName, String roomNumber, TenantLedger ledger) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(tenantName.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text(roomNumber, style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  pw.TableRow(children: [
                    _cell('Date', bold: true),
                    _cell('Description', bold: true),
                    _cell('Amount', bold: true),
                  ]),
                  ...ledger.entries.map((e) => pw.TableRow(children: [
                        _cell(formatDisplayDate(e.date)),
                        _cell(e.label),
                        _cell(formatCurrency(e.amount)),
                      ])),
                ],
              ),
              pw.SizedBox(height: 16),
              _summaryLine('Total Rent', ledger.totalRent),
              _summaryLine('Total Electricity', ledger.totalElectricity),
              _summaryLine('Total Payments', ledger.totalPayments),
              _summaryLine('Total Pending', ledger.totalPending),
              pw.Divider(),
              _summaryLine('Deposit', ledger.deposit),
              _summaryLine('Adjustments', ledger.depositAdjustment),
              _summaryLine('Refund', ledger.depositRefund),
            ],
          );
        },
      ),
    );
    return _save('tenant_ledger_${tenantName.replaceAll(' ', '_')}.pdf', doc);
  }

  pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  pw.Widget _summaryLine(String label, double amount, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(formatCurrency(amount), style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );
}
