import 'package:flutter/material.dart';

import '../../models/room.dart';
import '../../models/tenant.dart';
import '../../repositories/allocation_repository.dart';
import '../../repositories/tenant_repository.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';
import '../tenants/tenant_form_screen.dart';

class AllocateTenantScreen extends StatefulWidget {
  final Room room;

  const AllocateTenantScreen({super.key, required this.room});

  @override
  State<AllocateTenantScreen> createState() => _AllocateTenantScreenState();
}

class _AllocateTenantScreenState extends State<AllocateTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantRepo = TenantRepository();
  final _allocationRepo = AllocationRepository();

  late final TextEditingController _rentController;
  late final TextEditingController _meterReadingController;
  late final TextEditingController _depositController;
  DateTime _joiningDate = DateTime.now();
  DateTime _depositDate = DateTime.now();
  Tenant? _selectedTenant;
  List<Tenant> _availableTenants = [];
  bool _loadingTenants = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rentController = TextEditingController(text: widget.room.monthlyRent.toStringAsFixed(0));
    _meterReadingController = TextEditingController(text: widget.room.currentMeterReading.toStringAsFixed(0));
    _depositController = TextEditingController();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    setState(() => _loadingTenants = true);
    final all = await _tenantRepo.getAll();
    final unallocated = <Tenant>[];
    for (final t in all) {
      final hasActive = await _tenantRepo.hasActiveAllocation(t.id!);
      if (!hasActive) unallocated.add(t);
    }
    if (!mounted) return;
    setState(() {
      _availableTenants = unallocated;
      _loadingTenants = false;
    });
  }

  Future<void> _addNewTenant() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantFormScreen()));
    if (result == true) {
      await _loadTenants();
      if (_availableTenants.isNotEmpty) {
        setState(() => _selectedTenant = _availableTenants.last);
      }
    }
  }

  Future<void> _allocate() async {
    if (_selectedTenant == null) {
      showSnack(context, 'Select a tenant first', error: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _allocationRepo.allocateTenant(
        room: widget.room,
        tenant: _selectedTenant!,
        joiningDate: formatDateForStorage(_joiningDate),
        monthlyRent: double.parse(_rentController.text),
        initialMeterReading: double.parse(_meterReadingController.text),
        depositAmount: double.tryParse(_depositController.text) ?? 0,
        depositDate: formatDateForStorage(_depositDate),
      );
      if (mounted) {
        showSnack(context, 'Tenant allocated to Room ${widget.room.roomNumber}');
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
    return Scaffold(
      appBar: AppBar(title: Text('Allocate Room ${widget.room.roomNumber}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Tenant', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_loadingTenants)
              const Center(child: CircularProgressIndicator())
            else if (_availableTenants.isEmpty)
              const Text('No unallocated tenants available. Add a new tenant below.')
            else
              DropdownButtonFormField<Tenant>(
                value: _selectedTenant,
                decoration: const InputDecoration(labelText: 'Select Tenant'),
                items: _availableTenants
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.fullName)))
                    .toList(),
                onChanged: (t) => setState(() => _selectedTenant = t),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add New Tenant'),
              onPressed: _addNewTenant,
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            Text('Security Deposit', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _allocate,
              child: _saving ? const CircularProgressIndicator() : const Text('Allocate Tenant'),
            ),
          ],
        ),
      ),
    );
  }
}
