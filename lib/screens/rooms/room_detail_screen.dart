import 'package:flutter/material.dart';

import '../../models/deposit.dart';
import '../../models/electricity_bill.dart';
import '../../models/expense.dart';
import '../../models/payment.dart';
import '../../models/rent_transaction.dart';
import '../../models/room.dart';
import '../../models/room_allocation.dart';
import '../../models/tenant.dart';
import '../../repositories/allocation_repository.dart';
import '../../repositories/deposit_repository.dart';
import '../../repositories/electricity_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../repositories/room_repository.dart';
import '../../repositories/tenant_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import '../allocation/allocate_tenant_screen.dart';
import '../allocation/checkout_screen.dart';
import '../expenses/expense_form_screen.dart';
import '../rooms/room_form_screen.dart';
import '../tenants/tenant_detail_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  final int roomId;

  const RoomDetailScreen({super.key, required this.roomId});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final _roomRepo = RoomRepository();
  final _tenantRepo = TenantRepository();
  final _allocationRepo = AllocationRepository();
  final _rentRepo = RentRepository();
  final _electricityRepo = ElectricityRepository();
  final _paymentRepo = PaymentRepository();
  final _depositRepo = DepositRepository();
  final _expenseRepo = ExpenseRepository();

  Room? _room;
  Tenant? _activeTenant;
  RoomAllocation? _activeAllocation;
  Deposit? _deposit;
  List<RentTransaction> _rents = [];
  List<ElectricityBill> _bills = [];
  List<Payment> _payments = [];
  List<Expense> _expenses = [];
  List<RoomAllocation> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final room = await _roomRepo.getById(widget.roomId);
    final allocation = await _allocationRepo.getActiveForRoom(widget.roomId);
    Tenant? tenant;
    Deposit? deposit;
    if (allocation != null) {
      tenant = await _tenantRepo.getById(allocation.tenantId);
      deposit = await _depositRepo.getByAllocation(allocation.id!);
    }
    final rents = await _rentRepo.getByRoom(widget.roomId);
    final bills = await _electricityRepo.getBillsByRoom(widget.roomId);
    final payments = await _paymentRepo.getByRoom(widget.roomId);
    final expenses = await _expenseRepo.filter(roomId: widget.roomId);
    final history = await _allocationRepo.getByRoom(widget.roomId);

    if (!mounted) return;
    setState(() {
      _room = room;
      _activeAllocation = allocation;
      _activeTenant = tenant;
      _deposit = deposit;
      _rents = rents;
      _bills = bills;
      _payments = payments;
      _expenses = expenses;
      _history = history;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _room == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final room = _room!;

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Room ${room.roomNumber}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomFormScreen(room: room)));
                _load();
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'vacant') {
                  await _roomRepo.updateStatus(room.id!, RoomStatus.vacant);
                  _load();
                } else if (value == 'deactivate') {
                  final hasHistory = await _roomRepo.hasHistory(room.id!);
                  if (!mounted) return;
                  final confirmed = await confirmDialog(
                    context,
                    title: 'Deactivate Room',
                    message: hasHistory
                        ? 'This room has transaction history and will be marked Inactive rather than deleted.'
                        : 'Mark this room as inactive?',
                  );
                  if (confirmed) {
                    await _roomRepo.deactivate(room.id!);
                    _load();
                  }
                }
              },
              itemBuilder: (context) => [
                if (room.status != RoomStatus.vacant && _activeAllocation == null)
                  const PopupMenuItem(value: 'vacant', child: Text('Mark Vacant')),
                const PopupMenuItem(value: 'deactivate', child: Text('Deactivate Room')),
              ],
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Tenant'),
              Tab(text: 'Rent'),
              Tab(text: 'Electricity'),
              Tab(text: 'Payments'),
              Tab(text: 'Deposit'),
              Tab(text: 'Expenses'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTenantTab(),
            _buildRentTab(),
            _buildElectricityTab(),
            _buildPaymentsTab(),
            _buildDepositTab(),
            _buildExpensesTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantTab() {
    final room = _room!;
    if (_activeTenant == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const EmptyState(message: 'This room is currently vacant.', icon: Icons.person_off_outlined),
          Center(
            child: FilledButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Allocate Tenant'),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => AllocateTenantScreen(room: room)));
                _load();
              },
            ),
          ),
        ],
      );
    }
    final tenant = _activeTenant!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tenant.fullName, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                KeyValueRow(label: 'Mobile', value: tenant.mobileNumber ?? '-'),
                KeyValueRow(label: 'Members', value: '${tenant.familyMembersCount}'),
                KeyValueRow(label: 'Joining Date', value: formatDisplayDate(_activeAllocation?.joiningDate)),
                KeyValueRow(label: 'Monthly Rent', value: formatCurrency(tenant.monthlyRent)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => TenantDetailScreen(tenantId: tenant.id!)));
                          _load();
                        },
                        child: const Text('View Tenant'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CheckoutScreen(allocation: _activeAllocation!, tenant: tenant, room: room)),
                          );
                          _load();
                        },
                        child: const Text('Tenant Leaving'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
            subtitle: Text('${formatDisplayDate(r.fromDate)} → ${formatDisplayDate(r.toDate)}\nRent: ${formatCurrency(r.rentAmount)}'),
            isThreeLine: true,
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
            subtitle: Text('${b.previousReading.toStringAsFixed(0)} → ${b.currentReading.toStringAsFixed(0)}  '
                '(${b.totalUnits.toStringAsFixed(0)} units × ${formatCurrency(b.ratePerUnit)}) = ${formatCurrency(b.billAmount)}'),
            isThreeLine: true,
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

  Widget _buildDepositTab() {
    if (_deposit == null) return const EmptyState(message: 'No deposit on record for the current tenant.', icon: Icons.savings_outlined);
    final d = _deposit!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KeyValueRow(label: 'Deposit Amount', value: formatCurrency(d.depositAmount)),
                KeyValueRow(label: 'Deposit Date', value: formatDisplayDate(d.depositDate)),
                KeyValueRow(label: 'Status', value: d.status),
                if (d.status != DepositStatus.held) ...[
                  KeyValueRow(label: 'Adjustment', value: formatCurrency(d.adjustmentAmount)),
                  KeyValueRow(label: 'Refund', value: formatCurrency(d.refundAmount)),
                  KeyValueRow(label: 'Refund Date', value: formatDisplayDate(d.refundDate)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpensesTab() {
    final room = _room!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseFormScreen(defaultRoom: room)));
                _load();
              },
            ),
          ),
        ),
        Expanded(
          child: _expenses.isEmpty
              ? const EmptyState(message: 'No expenses for this room yet.', icon: Icons.build_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _expenses.length,
                  itemBuilder: (context, i) {
                    final e = _expenses[i];
                    return Card(
                      child: ListTile(
                        title: Text('${ExpenseCategory.label(e.category)} · ${formatCurrency(e.amount)}'),
                        subtitle: Text('${formatDisplayDate(e.expenseDate)}${e.description != null ? ' · ${e.description}' : ''}'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) return const EmptyState(message: 'No allocation history yet.', icon: Icons.history);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _history.length,
      itemBuilder: (context, i) {
        final a = _history[i];
        return FutureBuilder<Tenant?>(
          future: _tenantRepo.getById(a.tenantId),
          builder: (context, snapshot) {
            final name = snapshot.data?.fullName ?? '...';
            return Card(
              child: ListTile(
                title: Text(name),
                subtitle: Text('${formatDisplayDate(a.joiningDate)} → ${a.leavingDate != null ? formatDisplayDate(a.leavingDate) : 'Present'}'),
                trailing: StatusBadge.forStatus(a.status),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TenantDetailScreen(tenantId: a.tenantId))),
              ),
            );
          },
        );
      },
    );
  }
}
