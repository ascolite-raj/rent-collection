import 'package:flutter/material.dart';

import '../../models/rent_transaction.dart';
import '../../repositories/rent_repository.dart';
import '../../services/rent_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import 'record_rent_payment_screen.dart';

class RentScreen extends StatefulWidget {
  const RentScreen({super.key});

  @override
  State<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends State<RentScreen> {
  final _rentRepo = RentRepository();
  final _rentService = RentService();
  String _billingMonth = currentBillingMonth();
  late Future<List<Map<String, Object?>>> _future;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _rentRepo.getByMonthDetailed(_billingMonth);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _pickMonth() async {
    final current = DateTime.tryParse('$_billingMonth-01') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select month',
    );
    if (picked != null) {
      setState(() {
        _billingMonth = billingMonthFor(picked);
        _load();
      });
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final created = await _rentService.generateForMonth(_billingMonth);
      if (mounted) {
        showSnack(context, created > 0 ? 'Generated rent for $created tenant(s)' : 'Rent already generated for this month');
      }
      _refresh();
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Rent'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month_outlined), onPressed: _pickMonth),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(formatBillingMonthLabel(_billingMonth), style: Theme.of(context).textTheme.titleMedium),
                ),
                FilledButton.tonal(
                  onPressed: _generating ? null : _generate,
                  child: _generating ? const CircularProgressIndicator() : const Text('Generate Rent'),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final rents = snapshot.data!;
                  if (rents.isEmpty) {
                    return ListView(
                      children: const [EmptyState(message: 'No rent generated for this month yet.', icon: Icons.receipt_outlined)],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: rents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = RentTransaction.fromMap(rents[i]);
                      final tenantName = rents[i]['tenant_name'] as String;
                      final roomNumber = rents[i]['room_number'] as String;
                      return Card(
                        child: ListTile(
                          title: Text('$tenantName · Room $roomNumber'),
                          subtitle: Text('Rent: ${formatCurrency(r.rentAmount)} · Paid: ${formatCurrency(r.paidAmount)} · Pending: ${formatCurrency(r.pendingAmount)}'),
                          isThreeLine: true,
                          trailing: StatusBadge.forStatus(r.paymentStatus),
                          onTap: r.paymentStatus == PaymentStatus.paid
                              ? null
                              : () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => RecordRentPaymentScreen(rent: r)));
                                  _refresh();
                                },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
