import 'package:flutter/material.dart';

import '../../models/payment.dart';
import '../../models/room.dart';
import '../../models/tenant.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/room_repository.dart';
import '../../repositories/tenant_repository.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';

class AddOtherPaymentScreen extends StatefulWidget {
  const AddOtherPaymentScreen({super.key});

  @override
  State<AddOtherPaymentScreen> createState() => _AddOtherPaymentScreenState();
}

class _AddOtherPaymentScreenState extends State<AddOtherPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _paymentRepo = PaymentRepository();
  final _tenantRepo = TenantRepository();
  final _roomRepo = RoomRepository();

  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  DateTime _paymentDate = DateTime.now();
  String _type = PaymentType.other;
  String _method = PaymentMethod.cash;
  Tenant? _tenant;
  Room? _room;
  List<Tenant> _tenants = [];
  List<Room> _rooms = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final tenants = await _tenantRepo.getAll();
    final rooms = await _roomRepo.getAll();
    if (!mounted) return;
    setState(() {
      _tenants = tenants;
      _rooms = rooms;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _paymentRepo.create(
        Payment(
          tenantId: _tenant?.id,
          roomId: _room?.id,
          paymentType: _type,
          amount: double.parse(_amountController.text),
          paymentDate: formatDateForStorage(_paymentDate),
          paymentMethod: _method,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdAt: '',
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Payment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Payment Type'),
              items: PaymentType.all.map((t) => DropdownMenuItem(value: t, child: Text(PaymentType.label(t)))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Tenant?>(
              value: _tenant,
              decoration: const InputDecoration(labelText: 'Tenant (optional)'),
              items: [
                const DropdownMenuItem<Tenant?>(value: null, child: Text('None')),
                ..._tenants.map((t) => DropdownMenuItem(value: t, child: Text(t.fullName))),
              ],
              onChanged: (v) => setState(() => _tenant = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Room?>(
              value: _room,
              decoration: const InputDecoration(labelText: 'Room (optional)'),
              items: [
                const DropdownMenuItem<Room?>(value: null, child: Text('None')),
                ..._rooms.map((r) => DropdownMenuItem(value: r, child: Text('Room ${r.roomNumber}'))),
              ],
              onChanged: (v) => setState(() => _room = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹'),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.positiveAmount(v, label: 'Amount'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Payment Date'),
              subtitle: Text(formatDisplayDate(formatDateForStorage(_paymentDate))),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await pickDate(context, initial: _paymentDate);
                if (picked != null) setState(() => _paymentDate = picked);
              },
            ),
            DropdownButtonFormField<String>(
              value: _method,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: PaymentMethod.all.map((m) => DropdownMenuItem(value: m, child: Text(PaymentMethod.label(m)))).toList(),
              onChanged: (v) => setState(() => _method = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator() : const Text('Add Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
