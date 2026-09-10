import 'package:flutter/material.dart';

import '../../models/deposit.dart';
import '../../models/electricity_bill.dart';
import '../../models/payment.dart';
import '../../models/rent_transaction.dart';
import '../../models/room.dart';
import '../../models/room_allocation.dart';
import '../../models/settlement.dart';
import '../../models/tenant.dart';
import '../../repositories/allocation_repository.dart';
import '../../repositories/deposit_repository.dart';
import '../../repositories/electricity_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../repositories/room_repository.dart';
import '../../repositories/tenant_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import '../allocation/checkout_screen.dart';
import '../ledger/tenant_ledger_screen.dart';
import 'tenant_form_screen.dart';

class TenantDetailScreen extends StatefulWidget {
  final int tenantId;

  const TenantDetailScreen({super.key, required this.tenantId});

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  final _tenantRepo = TenantRepository();
  final _roomRepo = RoomRepository();
  final _allocationRepo = AllocationRepository();
  final _rentRepo = RentRepository();
  final _electricityRepo = ElectricityRepository();
  final _paymentRepo = PaymentRepository();
  final _depositRepo = DepositRepository();

  Tenant? _tenant;
  Room? _currentRoom;
  RoomAllocation? _activeAllocation;
  List<RoomAllocation> _allocationHistory = [];
  List<Deposit> _deposits = [];
  List<RentTransaction> _rents = [];
  List<ElectricityBill> _bills = [];
  List<Payment> _payments = [];
  List<Settlement> _settlements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tenant = await _tenantRepo.getById(widget.tenantId);
    final activeAllocation = await _allocationRepo.getActiveForTenant(widget.tenantId);
    final room = activeAllocation != null ? await _roomRepo.getById(activeAllocation.roomId) : null;
    final history = await _allocationRepo.getByTenant(widget.tenantId);
    final deposits = await _depositRepo.getByTenant(widget.tenantId);
    final rents = await _rentRepo.getByTenant(widget.tenantId);
    final bills = await _electricityRepo.getByTenant(widget.tenantId);
    final payments = await _paymentRepo.getByTenant(widget.tenantId);
    final settlements = await _allocationRepo.getSettlementsByTenant(widget.tenantId);

    if (!mounted) return;
    setState(() {
      _tenant = tenant;
      _activeAllocation = activeAllocation;
      _currentRoom = room;
      _allocationHistory = history;
      _deposits = deposits;
      _rents = rents;
      _bills = bills;
      _payments = payments;
      _settlements = settlements;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _tenant == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final tenant = _tenant!;

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tenant.fullName),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => TenantFormScreen(tenant: tenant)));
                _load();
              },
            ),
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Ledger',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TenantLedgerScreen(tenant: tenant))),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Room History'),
              Tab(text: 'Deposits'),
              Tab(text: 'Rent'),
              Tab(text: 'Electricity'),
              Tab(text: 'Payments'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(),
            _buildRoomHistoryTab(),
            _buildDepositsTab(),
            _buildRentTab(),
            _buildElectricityTab(),
            _buildPaymentsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final tenant = _tenant!;
    final members = (tenant.familyMembersDetails ?? '')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tenant.fullName, style: Theme.of(context).textTheme.titleLarge),
                    StatusBadge.forStatus(tenant.status),
                  ],
                ),
                const SizedBox(height: 12),
                KeyValueRow(label: 'Mobile', value: tenant.mobileNumber ?? '-'),
                KeyValueRow(label: 'Members', value: '${tenant.familyMembersCount}'),
                KeyValueRow(label: 'Joining Date', value: formatDisplayDate(tenant.joiningDate)),
                KeyValueRow(
                  label: 'Room',
                  value: _currentRoom != null ? 'Room ${_currentRoom!.roomNumber}' : 'Not allocated',
                ),
                KeyValueRow(label: 'Monthly Rent', value: formatCurrency(tenant.monthlyRent)),
                if (tenant.notes != null) KeyValueRow(label: 'Notes', value: tenant.notes!),
              ],
            ),
          ),
        ),
        if (members.isNotEmpty) ...[
          const SectionHeader(title: 'Family Members'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: members.map((m) => Text('• $m')).toList(),
              ),
            ),
          ),
        ],
        if (_activeAllocation != null && _currentRoom != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CheckoutScreen(allocation: _activeAllocation!, tenant: tenant, room: _currentRoom!)),
              );
              _load();
            },
            child: const Text('Tenant Leaving / Final Settlement'),
          ),
        ],
        if (_settlements.isNotEmpty) ...[
          const SectionHeader(title: 'Past Settlements'),
          ..._settlements.map((s) => Card(
                child: ListTile(
                  title: Text('Left on ${formatDisplayDate(s.leavingDate)}'),
                  subtitle: Text('Final Refund: ${formatCurrency(s.finalRefund)}'),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildRoomHistoryTab() {
    if (_allocationHistory.isEmpty) return const EmptyState(message: 'No room history yet.', icon: Icons.history);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _allocationHistory.length,
      itemBuilder: (context, i) {
        final a = _allocationHistory[i];
        return FutureBuilder<Room?>(
          future: _roomRepo.getById(a.roomId),
          builder: (context, snapshot) {
            return Card(
              child: ListTile(
                title: Text(snapshot.data != null ? 'Room ${snapshot.data!.roomNumber}' : '...'),
                subtitle: Text('${formatDisplayDate(a.joiningDate)} → ${a.leavingDate != null ? formatDisplayDate(a.leavingDate) : 'Present'}'),
                trailing: StatusBadge.forStatus(a.status),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDepositsTab() {
    if (_deposits.isEmpty) return const EmptyState(message: 'No deposits recorded.', icon: Icons.savings_outlined);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _deposits.length,
      itemBuilder: (context, i) {
        final d = _deposits[i];
        return Card(
          child: ListTile(
            title: Text(formatCurrency(d.depositAmount)),
            subtitle: Text('${formatDisplayDate(d.depositDate)}${d.status != DepositStatus.held ? ' · Refund: ${formatCurrency(d.refundAmount)}' : ''}'),
            trailing: StatusBadge.forStatus(d.status),
          ),
        );
      },
    );
  }

  Widget _buildRentTab() {
    if (_rents.isEmpty) return const EmptyState(message: 'No rent records yet.', icon: Icons.receipt_outlined);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _rents.length,
      itemBuilder: (context, i) {
        final r = _rents[i];
        return Card(
          child: ListTile(
            title: Text(formatBillingMonthLabel(r.billingMonth)),
            subtitle: Text('Rent: ${formatCurrency(r.rentAmount)} · Paid: ${formatCurrency(r.paidAmount)}'),
            trailing: StatusBadge.forStatus(r.paymentStatus),
          ),
        );
      },
    );
  }

  Widget _buildElectricityTab() {
    if (_bills.isEmpty) return const EmptyState(message: 'No electricity bills yet.', icon: Icons.bolt_outlined);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _bills.length,
      itemBuilder: (context, i) {
        final b = _bills[i];
        return Card(
          child: ListTile(
            title: Text('${formatDisplayDate(b.fromDate)} → ${formatDisplayDate(b.toDate)}'),
            subtitle: Text('${b.totalUnits.toStringAsFixed(0)} units · ${formatCurrency(b.billAmount)}'),
            trailing: StatusBadge.forStatus(b.paymentStatus),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) return const EmptyState(message: 'No payments recorded yet.', icon: Icons.payments_outlined);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _payments.length,
      itemBuilder: (context, i) {
        final p = _payments[i];
        return Card(
          child: ListTile(
            title: Text('${PaymentType.label(p.paymentType)} · ${formatCurrency(p.amount)}'),
            subtitle: Text('${formatDisplayDate(p.paymentDate)} · ${PaymentMethod.label(p.paymentMethod)}'),
          ),
        );
      },
    );
  }
}
