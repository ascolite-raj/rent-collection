import 'package:flutter/material.dart';

import '../../repositories/report_repository.dart';
import 'monthly_report_screen.dart';
import 'pending_payments_report_screen.dart';
import 'simple_report_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportRepo = ReportRepository();

    final tiles = <_ReportTile>[
      _ReportTile('Monthly Collection Report', Icons.calendar_month_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyReportScreen()))),
      _ReportTile('Pending Payment Report', Icons.warning_amber_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingPaymentsReportScreen()))),
      _ReportTile('Rent Report', Icons.receipt_outlined, () async {
        final rows = await reportRepo.getRentReport();
        _openSimple(context, 'Rent Report', rows, ['billing_month', 'tenant_name', 'room_number', 'rent_amount', 'paid_amount', 'pending_amount', 'payment_status']);
      }),
      _ReportTile('Electricity Report', Icons.bolt_outlined, () async {
        final rows = await reportRepo.getElectricityReport();
        _openSimple(context, 'Electricity Report', rows, ['from_date', 'to_date', 'tenant_name', 'room_number', 'total_units', 'bill_amount', 'pending_amount', 'payment_status']);
      }),
      _ReportTile('Deposit Report', Icons.savings_outlined, () async {
        final rows = await reportRepo.getDepositReport();
        _openSimple(context, 'Deposit Report', rows, ['deposit_date', 'tenant_name', 'room_number', 'deposit_amount', 'status', 'refund_amount']);
      }),
      _ReportTile('Expense Report', Icons.build_outlined, () async {
        final rows = await reportRepo.getExpenseReport();
        _openSimple(context, 'Expense Report', rows, ['expense_date', 'room_number', 'category', 'amount', 'description']);
      }),
      _ReportTile('Tenant Settlement Report', Icons.fact_check_outlined, () async {
        final rows = await reportRepo.getSettlementReport();
        _openSimple(context, 'Tenant Settlement Report', rows, ['leaving_date', 'tenant_name', 'room_number', 'pending_rent', 'pending_electricity', 'deposit_adjustment', 'final_refund']);
      }),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final tile = tiles[i];
          return Card(
            child: ListTile(
              leading: Icon(tile.icon),
              title: Text(tile.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: tile.onTap,
            ),
          );
        },
      ),
    );
  }

  static void _openSimple(BuildContext context, String title, List<Map<String, Object?>> rows, List<String> columns) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SimpleReportScreen(title: title, rows: rows, columns: columns)));
  }
}

class _ReportTile {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  _ReportTile(this.title, this.icon, this.onTap);
}
