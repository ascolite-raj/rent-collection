import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/backup_service.dart';
import '../../services/csv_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final _backupService = BackupService();
  final _csvService = CsvService();

  late Future<List<File>> _backupsFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _backupsFuture = _backupService.listBackups();
  }

  void _refresh() => setState(() => _backupsFuture = _backupService.listBackups());

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      final file = await _backupService.createBackup();
      if (mounted) showSnack(context, 'Backup created: ${file.path.split(Platform.pathSeparator).last}');
      _refresh();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareBackup(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'Rent collection backup');
  }

  Future<void> _restoreFromFile(File file) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Restore Database',
      message: 'This replaces all current data with the selected backup. Your current data will be snapshotted first as a safety backup. Continue?',
      confirmLabel: 'Restore',
      destructive: true,
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await _backupService.restoreBackup(file);
      if (mounted) {
        showSnack(context, 'Database restored. Restart the app to see all changes reflected everywhere.');
      }
      _refresh();
    } catch (e) {
      if (mounted) showSnack(context, 'Restore failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndRestore() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    await _restoreFromFile(file);
  }

  Future<void> _exportAllData() async {
    setState(() => _busy = true);
    try {
      final files = await _csvService.exportAllData();
      if (mounted) {
        showSnack(context, 'Exported ${files.length} CSV files to ${files.first.parent.path}');
        await Share.shareXFiles(files.map((f) => XFile(f.path)).toList(), text: 'Rent collection data export');
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Create Backup Now'),
            onPressed: _busy ? null : _createBackup,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Restore from a File'),
            onPressed: _busy ? null : _pickAndRestore,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Export All Data (CSV)'),
            onPressed: _busy ? null : _exportAllData,
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Previous Backups'),
          FutureBuilder<List<File>>(
            future: _backupsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final backups = snapshot.data!;
              if (backups.isEmpty) {
                return const EmptyState(message: 'No backups yet.', icon: Icons.backup_outlined);
              }
              return Column(
                children: backups.map((f) {
                  final name = f.path.split(Platform.pathSeparator).last;
                  final modified = f.statSync().modified;
                  return Card(
                    child: ListTile(
                      title: Text(name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(formatDisplayDate(formatDateForStorage(modified))),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'share') _shareBackup(f);
                          if (value == 'restore') _restoreFromFile(f);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'share', child: Text('Share')),
                          PopupMenuItem(value: 'restore', child: Text('Restore this backup')),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
