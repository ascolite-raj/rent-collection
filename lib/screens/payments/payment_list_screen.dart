import 'package:flutter/material.dart';

import '../../models/payment.dart';
import '../../repositories/payment_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import 'add_other_payment_screen.dart';

class PaymentListScreen extends StatefulWidget {
  const PaymentListScreen({super.key});

  @override
  State<PaymentListScreen> createState() => _PaymentListScreenState();
}

class _PaymentListScreenState extends State<PaymentListScreen> {
  final _paymentRepo = PaymentRepository();
  String? _typeFilter;
  late Future<List<Payment>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _paymentRepo.filter(paymentType: _typeFilter);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddOtherPaymentScreen()));
          _refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip(null, 'All'),
                  ...PaymentType.all.map((t) => _filterChip(t, PaymentType.label(t))),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Payment>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final payments = snapshot.data!;
                  if (payments.isEmpty) {
                    return ListView(children: const [EmptyState(message: 'No payments recorded yet.', icon: Icons.payments_outlined)]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: payments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = payments[i];
                      return Card(
                        child: ListTile(
                          title: Text('${PaymentType.label(p.paymentType)} · ${formatCurrency(p.amount)}'),
                          subtitle: Text('${formatDisplayDate(p.paymentDate)} · ${PaymentMethod.label(p.paymentMethod)}${p.notes != null ? '\n${p.notes}' : ''}'),
                          isThreeLine: p.notes != null,
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

  Widget _filterChip(String? type, String label) {
    final selected = _typeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() {
          _typeFilter = type;
          _load();
        }),
      ),
    );
  }
}
