import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/room.dart';
import '../../repositories/electricity_repository.dart';
import '../../services/electricity_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';

class AddMeterReadingScreen extends StatefulWidget {
  final Room room;

  const AddMeterReadingScreen({super.key, required this.room});

  @override
  State<AddMeterReadingScreen> createState() => _AddMeterReadingScreenState();
}

class _AddMeterReadingScreenState extends State<AddMeterReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _electricityRepo = ElectricityRepository();
  final _electricityService = ElectricityService();

  late final TextEditingController _readingController;
  late final TextEditingController _notesController;
  DateTime _readingDate = DateTime.now();
  double _rate = 10;
  double _previousReading = 0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _readingController = TextEditingController();
    _notesController = TextEditingController();
    _init();
  }

  Future<void> _init() async {
    final rate = await DatabaseHelper.instance.getElectricityRate();
    final readings = await _electricityRepo.getReadingsByRoom(widget.room.id!);
    final previous = readings.isNotEmpty ? readings.first.meterReading : widget.room.currentMeterReading;
    if (!mounted) return;
    setState(() {
      _rate = rate;
      _previousReading = previous;
      _readingController.text = previous.toStringAsFixed(0);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _readingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final bill = await _electricityService.recordReadingAndGenerateBill(
        room: widget.room,
        readingDate: formatDateForStorage(_readingDate),
        meterReading: double.parse(_readingController.text),
        ratePerUnit: _rate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted) {
        showSnack(context, 'Bill generated: ${bill.totalUnits.toStringAsFixed(0)} units × ${formatCurrency(_rate)} = ${formatCurrency(bill.billAmount)}');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text('Meter Reading · Room ${widget.room.roomNumber}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            KeyValueRow(label: 'Previous Reading', value: _previousReading.toStringAsFixed(0)),
            KeyValueRow(label: 'Rate per Unit', value: formatCurrency(_rate)),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reading Date'),
              subtitle: Text(formatDisplayDate(formatDateForStorage(_readingDate))),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await pickDate(context, initial: _readingDate);
                if (picked != null) setState(() => _readingDate = picked);
              },
            ),
            TextFormField(
              controller: _readingController,
              decoration: const InputDecoration(labelText: 'Current Meter Reading *'),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.meterReading(v, minAllowed: _previousReading),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final current = double.tryParse(_readingController.text);
              if (current == null || current < _previousReading) return const SizedBox.shrink();
              final units = current - _previousReading;
              return Text(
                'Units: ${units.toStringAsFixed(0)} × ${formatCurrency(_rate)} = ${formatCurrency(units * _rate)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              );
            }),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator() : const Text('Save Reading & Generate Bill'),
            ),
          ],
        ),
      ),
    );
  }
}
