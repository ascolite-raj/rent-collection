import 'package:flutter/material.dart';

import '../../models/payment.dart';
import '../../models/rent_transaction.dart';
import '../../services/rent_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';

class RecordRentPaymentScreen extends StatefulWidget {
  final RentTransaction rent;

  const RecordRentPaymentScreen({super.key, required this.rent});

  @override
  State<RecordRentPaymentScreen> createState() => _RecordRentPaymentScreenState();
}

class _RecordRentPaymentScreenState extends State<RecordRentPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rentService = RentService();
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  DateTime _paymentDate = DateTime.now();
  String _method = PaymentMethod.cash;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.rent.pendingAmount.toStringAsFixed(0));
    _notesController = TextEditingController();
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
      await _rentService.recordPayment(
        rentId: widget.rent.id!,
        tenantId: widget.rent.tenantId,
        roomId: widget.rent.roomId,
        amount: double.parse(_amountController.text),
        paymentDate: formatDateForStorage(_paymentDate),
        paymentMethod: _method,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rent = widget.rent;
    return Scaffold(
      appBar: AppBar(title: Text('Record Rent Payment · ${formatBillingMonthLabel(rent.billingMonth)}')),
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
                    KeyValueRow(label: 'Rent Amount', value: formatCurrency(rent.rentAmount)),
                    KeyValueRow(label: 'Already Paid', value: formatCurrency(rent.paidAmount)),
                    KeyValueRow(label: 'Pending', value: formatCurrency(rent.pendingAmount)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Payment Amount *', prefixText: '₹'),
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
              child: _saving ? const CircularProgressIndicator() : const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
