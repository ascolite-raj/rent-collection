import 'package:flutter/material.dart';

import '../../repositories/report_repository.dart';
import '../../services/csv_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';

class PendingPaymentsReportScreen extends StatefulWidget {
  const PendingPaymentsReportScreen({super.key});

  @override
  State<PendingPaymentsReportScreen> createState() => _PendingPaymentsReportScreenState();
}

class _PendingPaymentsReportScreenState extends State<PendingPaymentsReportScreen> {
  final _reportRepo = ReportRepository();
  final _csvService = CsvService();
  late Future<List<Map<String, Object?>>> _future;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _future = _reportRepo.getPendingPaymentsReport();
  }

  Future<void> _export(List<Map<String, Object?>> rows) async {
    setState(() => _exporting = true);
    try {
      final file = await _csvService.exportQueryResult('pending_payments.csv', rows);
      if (mounted) showSnack(context, 'Saved CSV to ${file.path}');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Payments'),
        actions: [
          IconButton(
            icon: _exporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_outlined),
            onPressed: _exporting
                ? null
                : () async {
                    final rows = await _future;
                    _export(rows);
                  },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const EmptyState(message: 'No pending payments. Everything is settled.', icon: Icons.check_circle_outline);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              return Card(
                child: ListTile(
                  title: Text('${r['tenant_name']} · Room ${r['room_number']}'),
                  subtitle: Text('${r['type']} · ${r['period']}'),
                  trailing: Text(
                    formatCurrency((r['pending'] as num).toDouble()),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
