import 'package:flutter/material.dart';

import '../../models/room.dart';
import '../../repositories/room_repository.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';

class RoomFormScreen extends StatefulWidget {
  final Room? room;

  const RoomFormScreen({super.key, this.room});

  @override
  State<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends State<RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomRepo = RoomRepository();

  late final TextEditingController _roomNumberController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _rentController;
  late final TextEditingController _meterNumberController;
  late final TextEditingController _meterReadingController;
  late final TextEditingController _notesController;
  String _status = RoomStatus.vacant;
  bool _saving = false;

  bool get _isEdit => widget.room != null;

  @override
  void initState() {
    super.initState();
    final room = widget.room;
    _roomNumberController = TextEditingController(text: room?.roomNumber ?? '');
    _descriptionController = TextEditingController(text: room?.description ?? '');
    _rentController = TextEditingController(text: room != null ? room.monthlyRent.toStringAsFixed(0) : '');
    _meterNumberController = TextEditingController(text: room?.meterNumber ?? '');
    _meterReadingController = TextEditingController(text: room != null ? room.currentMeterReading.toStringAsFixed(0) : '0');
    _notesController = TextEditingController(text: room?.notes ?? '');
    _status = room?.status ?? RoomStatus.vacant;
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _descriptionController.dispose();
    _rentController.dispose();
    _meterNumberController.dispose();
    _meterReadingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final roomNumber = _roomNumberController.text.trim();
      final exists = await _roomRepo.roomNumberExists(roomNumber, excludeId: widget.room?.id);
      if (exists) {
        if (mounted) showSnack(context, 'A room with this number already exists', error: true);
        setState(() => _saving = false);
        return;
      }

      final room = Room(
        id: widget.room?.id,
        roomNumber: roomNumber,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        monthlyRent: double.parse(_rentController.text),
        meterNumber: _meterNumberController.text.trim().isEmpty ? null : _meterNumberController.text.trim(),
        currentMeterReading: double.tryParse(_meterReadingController.text) ?? 0,
        status: _status,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.room?.createdAt ?? '',
        updatedAt: widget.room?.updatedAt ?? '',
      );

      if (_isEdit) {
        await _roomRepo.update(room);
      } else {
        await _roomRepo.create(room);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Room' : 'Add Room')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _roomNumberController,
              decoration: const InputDecoration(labelText: 'Room Number *'),
              validator: (v) => Validators.required(v, label: 'Room number'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rentController,
              decoration: const InputDecoration(labelText: 'Monthly Rent *', prefixText: '₹'),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.nonNegativeAmount(v, label: 'Rent'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _meterNumberController,
              decoration: const InputDecoration(labelText: 'Meter Number'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _meterReadingController,
              decoration: const InputDecoration(labelText: 'Current Meter Reading'),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.nonNegativeAmount(v, label: 'Meter reading'),
              enabled: !_isEdit, // once tenants are recording readings, this is derived automatically
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: RoomStatus.vacant, child: Text('Vacant')),
                DropdownMenuItem(value: RoomStatus.occupied, child: Text('Occupied')),
                DropdownMenuItem(value: RoomStatus.inactive, child: Text('Inactive')),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator() : Text(_isEdit ? 'Save Changes' : 'Add Room'),
            ),
          ],
        ),
      ),
    );
  }
}
