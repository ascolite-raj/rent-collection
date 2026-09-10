import 'package:flutter/material.dart';

import '../../models/tenant.dart';
import '../../repositories/allocation_repository.dart';
import '../../repositories/ledger_repository.dart';
import '../../repositories/room_repository.dart';
import '../../services/pdf_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';

class TenantLedgerScreen extends StatefulWidget {
  final Tenant tenant;

  const TenantLedgerScreen({super.key, required this.tenant});

  @override
  State<TenantLedgerScreen> createState() => _TenantLedgerScreenState();
}

class _TenantLedgerScreenState extends State<TenantLedgerScreen> {
  final _ledgerRepo = LedgerRepository();
  final _allocationRepo = AllocationRepository();
  final _roomRepo = RoomRepository();
  final _pdfService = PdfService();

  DateTime? _fromDate;
  DateTime? _toDate;
  late Future<TenantLedger> _future;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _ledgerRepo.getTenantLedger(
      widget.tenant.id!,
      fromDate: _fromDate != null ? formatDateForStorage(_fromDate!) : null,
      toDate: _toDate != null ? formatDateForStorage(_toDate!) : null,
    );
  }

  Future<String> _roomLabel() async {
    final allocation = await _allocationRepo.getActiveForTenant(widget.tenant.id!);
    if (allocation == null) return '';
    final room = await _roomRepo.getById(allocation.roomId);
    return room != null ? 'Room ${room.roomNumber}' : '';
  }

  Future<void> _export(TenantLedger ledger) async {
    setState(() => _exporting = true);
    try {
      final roomLabel = await _roomLabel();
      final file = await _pdfService.generateTenantLedger(widget.tenant.fullName, roomLabel, ledger);
      if (mounted) showSnack(context, 'Saved PDF to ${file.path}');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tenant.fullName} · Ledger'),
        actions: [
          IconButton(
            icon: _exporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporting
                ? null
                : () async {
                    final ledger = await _future;
                    _export(ledger);
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await pickDate(context, initial: _fromDate ?? DateTime.now());
                      if (picked != null) setState(() {
                        _fromDate = picked;
                        _load();
                      });
                    },
                    child: Text(_fromDate == null ? 'From Date' : formatDisplayDate(formatDateForStorage(_fromDate!))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await pickDate(context, initial: _toDate ?? DateTime.now());
                      if (picked != null) setState(() {
                        _toDate = picked;
                        _load();
                      });
                    },
                    child: Text(_toDate == null ? 'To Date' : formatDisplayDate(formatDateForStorage(_toDate!))),
                  ),
                ),
                if (_fromDate != null || _toDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _fromDate = null;
                      _toDate = null;
                      _load();
                    }),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<TenantLedger>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final ledger = snapshot.data!;
                if (ledger.entries.isEmpty) {
                  return const EmptyState(message: 'No ledger entries for this period.', icon: Icons.receipt_long_outlined);
                }
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    ...ledger.entries.map((e) => Card(
                          child: ListTile(
                            title: Text(e.label),
                            subtitle: Text(formatDisplayDate(e.date)),
                            trailing: Text(formatCurrency(e.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        )),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KeyValueRow(label: 'Total Rent', value: formatCurrency(ledger.totalRent)),
                            KeyValueRow(label: 'Total Electricity', value: formatCurrency(ledger.totalElectricity)),
                            KeyValueRow(label: 'Total Payments', value: formatCurrency(ledger.totalPayments)),
                            KeyValueRow(label: 'Total Pending', value: formatCurrency(ledger.totalPending), valueColor: ledger.totalPending > 0 ? Colors.red : Colors.green),
                            const Divider(),
                            KeyValueRow(label: 'Deposit', value: formatCurrency(ledger.deposit)),
                            KeyValueRow(label: 'Adjustments', value: formatCurrency(ledger.depositAdjustment)),
                            KeyValueRow(label: 'Refund', value: formatCurrency(ledger.depositRefund)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
