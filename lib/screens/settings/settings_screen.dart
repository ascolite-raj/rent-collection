import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../widgets/common.dart';
import 'backup_restore_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _helper = DatabaseHelper.instance;
  late final TextEditingController _rateController;
  late final TextEditingController _dueDayController;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rateController = TextEditingController();
    _dueDayController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final rate = await _helper.getSetting('electricity_rate_per_unit') ?? '10';
    final dueDay = await _helper.getSetting('rent_due_day') ?? '5';
    if (!mounted) return;
    setState(() {
      _rateController.text = rate;
      _dueDayController.text = dueDay;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _helper.setSetting('electricity_rate_per_unit', _rateController.text.trim());
      await _helper.setSetting('rent_due_day', _dueDayController.text.trim());
      if (mounted) showSnack(context, 'Settings saved');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _rateController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Electricity'),
          TextField(
            controller: _rateController,
            decoration: const InputDecoration(labelText: 'Rate per Unit', prefixText: '₹'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Rent'),
          TextField(
            controller: _dueDayController,
            decoration: const InputDecoration(labelText: 'Rent Due Day of Month'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const CircularProgressIndicator() : const Text('Save Settings'),
          ),
          const SizedBox(height: 32),
          const SectionHeader(title: 'Data'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup & Restore'),
              subtitle: const Text('Export the database, or restore from a backup'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupRestoreScreen())),
            ),
          ),
        ],
      ),
    );
  }
}
