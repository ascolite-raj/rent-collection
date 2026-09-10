import 'package:flutter/material.dart';

import '../../models/room.dart';
import '../../models/tenant.dart';
import '../../repositories/allocation_repository.dart';
import '../../repositories/room_repository.dart';
import '../../repositories/tenant_repository.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';

class TenantFormScreen extends StatefulWidget {
  final Tenant? tenant;

  const TenantFormScreen({super.key, this.tenant});

  @override
  State<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends State<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantRepo = TenantRepository();
  final _roomRepo = RoomRepository();
  final _allocationRepo = AllocationRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _familyCountController;
  late final TextEditingController _familyDetailsController;
  late final TextEditingController _notesController;
  late final TextEditingController _rentController;
  late final TextEditingController _meterReadingController;
  late final TextEditingController _depositController;
  DateTime _joiningDate = DateTime.now();
  DateTime _depositDate = DateTime.now();
  String _status = TenantStatus.active;
  bool _saving = false;

  List<Room> _vacantRooms = [];
  Room? _selectedRoom;
  bool _loadingRooms = true;

  bool get _isEdit => widget.tenant != null;

  @override
  void initState() {
    super.initState();
    final tenant = widget.tenant;
    _nameController = TextEditingController(text: tenant?.fullName ?? '');
    _mobileController = TextEditingController(text: tenant?.mobileNumber ?? '');
    _familyCountController = TextEditingController(text: (tenant?.familyMembersCount ?? 1).toString());
    _familyDetailsController = TextEditingController(text: tenant?.familyMembersDetails ?? '');
    _notesController = TextEditingController(text: tenant?.notes ?? '');
    _rentController = TextEditingController();
    _meterReadingController = TextEditingController();
    _depositController = TextEditingController();
    if (tenant != null) {
      _joiningDate = parseStorageDate(tenant.joiningDate);
    }
    _status = tenant?.status ?? TenantStatus.active;
    if (!_isEdit) _loadVacantRooms();
  }

  Future<void> _loadVacantRooms() async {
    final rooms = await _roomRepo.getAll(includeInactive: false);
    if (!mounted) return;
    setState(() {
      _vacantRooms = rooms.where((r) => r.status == RoomStatus.vacant).toList();
      _loadingRooms = false;
    });
  }

  void _onRoomSelected(Room? room) {
    setState(() {
      _selectedRoom = room;
      _rentController.text = room?.monthlyRent.toStringAsFixed(0) ?? '';
      _meterReadingController.text = room?.currentMeterReading.toStringAsFixed(0) ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _familyCountController.dispose();
    _familyDetailsController.dispose();
    _notesController.dispose();
    _rentController.dispose();
    _meterReadingController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final tenant = Tenant(
        id: widget.tenant?.id,
        fullName: _nameController.text.trim(),
        mobileNumber: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        familyMembersCount: int.tryParse(_familyCountController.text) ?? 1,
        familyMembersDetails: _familyDetailsController.text.trim().isEmpty ? null : _familyDetailsController.text.trim(),
        joiningDate: formatDateForStorage(_joiningDate),
        currentRoomId: widget.tenant?.currentRoomId,
        monthlyRent: widget.tenant?.monthlyRent ?? 0,
        status: _status,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.tenant?.createdAt ?? '',
        updatedAt: widget.tenant?.updatedAt ?? '',
      );

      if (_isEdit) {
        await _tenantRepo.update(tenant);
      } else {
        final newId = await _tenantRepo.create(tenant);
        if (_selectedRoom != null) {
          await _allocationRepo.allocateTenant(
            room: _selectedRoom!,
            tenant: tenant.copyWith(id: newId),
            joiningDate: formatDateForStorage(_joiningDate),
            monthlyRent: double.parse(_rentController.text),
            initialMeterReading: double.parse(_meterReadingController.text),
            depositAmount: double.tryParse(_depositController.text) ?? 0,
            depositDate: formatDateForStorage(_depositDate),
          );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Tenant' : 'Add Tenant')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name *'),
              validator: (v) => Validators.required(v, label: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mobileController,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
              keyboardType: TextInputType.phone,
              validator: Validators.mobileNumber,
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 12),
              if (_loadingRooms)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<Room?>(
                  value: _selectedRoom,
                  decoration: const InputDecoration(labelText: 'Room No'),
                  hint: const Text('No room (allocate later)'),
                  items: [
                    const DropdownMenuItem<Room?>(value: null, child: Text('No room (allocate later)')),
                    ..._vacantRooms.map((r) => DropdownMenuItem<Room?>(value: r, child: Text(r.roomNumber))),
                  ],
                  onChanged: _onRoomSelected,
                ),
              if (_selectedRoom != null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rentController,
                  decoration: const InputDecoration(labelText: 'Monthly Rent *', prefixText: '₹'),
                  keyboardType: TextInputType.number,
                  validator: (v) => Validators.nonNegativeAmount(v, label: 'Rent'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _meterReadingController,
                  decoration: const InputDecoration(labelText: 'Initial Meter Reading *'),
                  keyboardType: TextInputType.number,
                  validator: (v) => Validators.nonNegativeAmount(v, label: 'Meter reading'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _depositController,
                  decoration: const InputDecoration(labelText: 'Deposit Amount', prefixText: '₹'),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.isEmpty) ? null : Validators.nonNegativeAmount(v, label: 'Deposit'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deposit Date'),
                  subtitle: Text(formatDisplayDate(formatDateForStorage(_depositDate))),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await pickDate(context, initial: _depositDate);
                    if (picked != null) setState(() => _depositDate = picked);
                  },
                ),
              ],
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _familyCountController,
              decoration: const InputDecoration(labelText: 'Number of Family Members'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _familyDetailsController,
              decoration: const InputDecoration(labelText: 'Family Member Details', hintText: 'One per line, e.g. Mother, Father'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Joining Date'),
              subtitle: Text(formatDisplayDate(formatDateForStorage(_joiningDate))),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await pickDate(context, initial: _joiningDate);
                if (picked != null) setState(() => _joiningDate = picked);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: TenantStatus.active, child: Text('Active')),
                DropdownMenuItem(value: TenantStatus.inactive, child: Text('Inactive')),
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
              child: _saving ? const CircularProgressIndicator() : Text(_isEdit ? 'Save Changes' : 'Add Tenant'),
            ),
          ],
        ),
      ),
    );
  }
}
