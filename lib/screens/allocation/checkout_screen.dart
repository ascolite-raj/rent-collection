import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/room.dart';
import '../../models/room_allocation.dart';
import '../../models/tenant.dart';
import '../../repositories/allocation_repository.dart';
import '../../repositories/deposit_repository.dart';
import '../../repositories/electricity_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';

class CheckoutScreen extends StatefulWidget {
  final RoomAllocation allocation;
  final Tenant tenant;
  final Room room;

  const CheckoutScreen({super.key, required this.allocation, required this.tenant, required this.room});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _allocationRepo = AllocationRepository();
  final _rentRepo = RentRepository();
  final _electricityRepo = ElectricityRepository();
  final _depositRepo = DepositRepository();

  late final TextEditingController _meterReadingController;
  late final TextEditingController _otherPendingController;
  late final TextEditingController _notesController;
  DateTime _leavingDate = DateTime.now();
  double _rate = 10;
  double _minMeterReading = 0;
  bool _loading = true;
  bool _saving = false;

  _CheckoutPreview? _preview;

  @override
  void initState() {
    super.initState();
    _meterReadingController = TextEditingController();
    _otherPendingController = TextEditingController(text: '0');
    _notesController = TextEditingController();
    _init();
  }

  Future<void> _init() async {
    final rate = await DatabaseHelper.instance.getElectricityRate();
    final lastReading = await _electricityRepo.getLastReadingForAllocation(widget.allocation.id!);
    final minReading = lastReading?.meterReading ?? widget.allocation.initialMeterReading;
    if (!mounted) return;
    setState(() {
      _rate = rate;
      _minMeterReading = minReading;
      _meterReadingController.text = minReading.toStringAsFixed(0);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _meterReadingController.dispose();
    _otherPendingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) return;

    final finalMeterReading = double.parse(_meterReadingController.text);
    final otherPending = double.tryParse(_otherPendingController.text) ?? 0;

    final pendingRentExisting = await _rentRepo.totalPendingForAllocation(widget.allocation.id!);
    final pendingElectricityExisting = await _electricityRepo.totalPendingForAllocation(widget.allocation.id!);
    final units = finalMeterReading - _minMeterReading;
    final finalBillAmount = units > 0 ? units * _rate : 0.0;
    final pendingElectricity = pendingElectricityExisting + finalBillAmount;

    final deposit = await _depositRepo.getByAllocation(widget.allocation.id!);
    final depositAmount = deposit?.depositAmount ?? 0;
    final totalDue = pendingRentExisting + pendingElectricity + otherPending;
    final adjustment = totalDue > depositAmount ? depositAmount : totalDue;
    final refund = depositAmount - adjustment;

    setState(() {
      _preview = _CheckoutPreview(
        finalMeterReading: finalMeterReading,
        units: units,
        finalBillAmount: finalBillAmount,
        pendingRent: pendingRentExisting,
        pendingElectricity: pendingElectricity,
        otherPending: otherPending,
        depositAmount: depositAmount,
        adjustment: adjustment,
        refund: refund,
      );
    });
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final otherPending = double.tryParse(_otherPendingController.text) ?? 0;
      await _allocationRepo.checkoutTenant(
        allocation: widget.allocation,
        leavingDate: formatDateForStorage(_leavingDate),
        finalMeterReading: double.parse(_meterReadingController.text),
        electricityRate: _rate,
        otherPending: otherPending,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted) {
        showSnack(context, 'Checkout complete. Room ${widget.room.roomNumber} is now vacant.');
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
      appBar: AppBar(title: const Text('Tenant Checkout')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KeyValueRow(label: 'Tenant', value: widget.tenant.fullName),
                    KeyValueRow(label: 'Room', value: widget.room.roomNumber),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Leaving Date'),
              subtitle: Text(formatDisplayDate(formatDateForStorage(_leavingDate))),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await pickDate(context, initial: _leavingDate, firstDate: parseStorageDate(widget.allocation.joiningDate));
                if (picked != null) setState(() => _leavingDate = picked);
              },
            ),
            TextFormField(
              controller: _meterReadingController,
              decoration: const InputDecoration(labelText: 'Final Meter Reading *'),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.meterReading(v, minAllowed: _minMeterReading),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _otherPendingController,
              decoration: const InputDecoration(labelText: 'Other Pending / Adjustment', prefixText: '₹'),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.nonNegativeAmount(v, label: 'Other pending'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: _calculate, child: const Text('Calculate Final Settlement')),
            if (_preview != null) ...[
              const SizedBox(height: 20),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Final Settlement', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      KeyValueRow(label: 'Units Consumed', value: '${_preview!.units.toStringAsFixed(0)}'),
                      KeyValueRow(label: 'Final Electricity Bill', value: formatCurrency(_preview!.finalBillAmount)),
                      const Divider(),
                      KeyValueRow(label: 'Pending Rent', value: formatCurrency(_preview!.pendingRent)),
                      KeyValueRow(label: 'Pending Electricity', value: formatCurrency(_preview!.pendingElectricity)),
                      KeyValueRow(label: 'Other Pending', value: formatCurrency(_preview!.otherPending)),
                      const Divider(),
                      KeyValueRow(label: 'Deposit Held', value: formatCurrency(_preview!.depositAmount)),
                      KeyValueRow(label: 'Deposit Adjustment', value: formatCurrency(_preview!.adjustment)),
                      KeyValueRow(
                        label: 'Final Refund',
                        value: formatCurrency(_preview!.refund),
                        valueColor: _preview!.refund > 0 ? Colors.green : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final confirmed = await confirmDialog(
                          context,
                          title: 'Confirm Checkout',
                          message: 'This will close the allocation, mark Room ${widget.room.roomNumber} vacant, '
                              'and settle the deposit. This cannot be undone from within the app.',
                          confirmLabel: 'Confirm Checkout',
                        );
                        if (confirmed) _confirm();
                      },
                child: _saving ? const CircularProgressIndicator() : const Text('Confirm Checkout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckoutPreview {
  final double finalMeterReading;
  final double units;
  final double finalBillAmount;
  final double pendingRent;
  final double pendingElectricity;
  final double otherPending;
  final double depositAmount;
  final double adjustment;
  final double refund;

  _CheckoutPreview({
    required this.finalMeterReading,
    required this.units,
    required this.finalBillAmount,
    required this.pendingRent,
    required this.pendingElectricity,
    required this.otherPending,
    required this.depositAmount,
    required this.adjustment,
    required this.refund,
  });
}
