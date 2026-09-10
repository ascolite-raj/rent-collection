import 'package:flutter/material.dart';

import '../../services/csv_service.dart';
import '../../widgets/common.dart';

/// Generic tabular report viewer: renders selected columns from a raw query
/// result and offers a CSV export of the same rows.
class SimpleReportScreen extends StatefulWidget {
  final String title;
  final List<Map<String, Object?>> rows;
  final List<String> columns;

  const SimpleReportScreen({super.key, required this.title, required this.rows, required this.columns});

  @override
  State<SimpleReportScreen> createState() => _SimpleReportScreenState();
}

class _SimpleReportScreenState extends State<SimpleReportScreen> {
  final _csvService = CsvService();
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final fileName = '${widget.title.replaceAll(' ', '_')}.csv';
      final file = await _csvService.exportQueryResult(fileName, widget.rows);
      if (mounted) showSnack(context, 'Saved CSV to ${file.path}');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _label(String column) => column.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: _exporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_outlined),
            onPressed: _exporting ? null : _export,
          ),
        ],
      ),
      body: widget.rows.isEmpty
          ? const EmptyState(message: 'No data for this report yet.', icon: Icons.insert_drive_file_outlined)
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: DataTable(
                columns: widget.columns.map((c) => DataColumn(label: Text(_label(c)))).toList(),
                rows: widget.rows
                    .map((row) => DataRow(
                          cells: widget.columns.map((c) => DataCell(Text('${row[c] ?? '-'}'))).toList(),
                        ))
                    .toList(),
              ),
            ),
    );
  }
}
