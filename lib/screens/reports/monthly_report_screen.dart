import 'package:flutter/material.dart';

import '../../repositories/report_repository.dart';
import '../../services/pdf_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final _reportRepo = ReportRepository();
  final _pdfService = PdfService();
  String _billingMonth = currentBillingMonth();
  late Future<MonthlyReport> _future;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _reportRepo.getMonthlyReport(_billingMonth);
  }

  Future<void> _pickMonth() async {
    final current = DateTime.tryParse('$_billingMonth-01') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select month',
    );
    if (picked != null) {
      setState(() {
        _billingMonth = billingMonthFor(picked);
        _load();
      });
    }
  }

  Future<void> _export(MonthlyReport report) async {
    setState(() => _exporting = true);
    try {
      final file = await _pdfService.generateMonthlyReport(report);
      if (mounted) showSnack(context, 'Saved PDF to ${file.path}');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Collection Report'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month_outlined), onPressed: _pickMonth),
          IconButton(
            icon: _exporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporting
                ? null
                : () async {
                    final report = await _future;
                    _export(report);
                  },
          ),
        ],
      ),
      body: FutureBuilder<MonthlyReport>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final report = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(formatBillingMonthLabel(_billingMonth).toUpperCase(), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ...report.lines.map((l) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Room ${l.roomNumber}', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          KeyValueRow(label: 'Rent', value: formatCurrency(l.rent)),
                          KeyValueRow(label: 'Electricity', value: formatCurrency(l.electricity)),
                          KeyValueRow(label: 'Total', value: formatCurrency(l.total)),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KeyValueRow(label: 'Total Rent', value: formatCurrency(report.totalRent)),
                      KeyValueRow(label: 'Total Electricity', value: formatCurrency(report.totalElectricity)),
                      KeyValueRow(label: 'Total Collection', value: formatCurrency(report.totalCollection)),
                      KeyValueRow(label: 'Total Expenses', value: formatCurrency(report.totalExpenses)),
                      const Divider(),
                      KeyValueRow(label: 'Net Collection', value: formatCurrency(report.netCollection)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
