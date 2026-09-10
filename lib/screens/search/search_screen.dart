import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/room.dart';
import '../../models/tenant.dart';
import '../../repositories/allocation_repository.dart';
import '../../repositories/deposit_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../repositories/room_repository.dart';
import '../../repositories/tenant_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../tenants/tenant_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchResult {
  final Tenant tenant;
  final Room? room;
  final double pending;
  final double deposit;
  final String? lastPaymentDate;

  _SearchResult({required this.tenant, this.room, required this.pending, required this.deposit, this.lastPaymentDate});
}

class _SearchScreenState extends State<SearchScreen> {
  final _tenantRepo = TenantRepository();
  final _roomRepo = RoomRepository();
  final _allocationRepo = AllocationRepository();
  final _rentRepo = RentRepository();
  final _depositRepo = DepositRepository();
  final _paymentRepo = PaymentRepository();

  final _controller = TextEditingController();
  Timer? _debounce;
  List<_SearchResult> _results = [];
  bool _loading = false;

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);

    final tenants = await _tenantRepo.search(trimmed);
    final rooms = await _roomRepo.getAll();
    final matchingRoomNumbers = rooms.where((r) => r.roomNumber.toLowerCase().contains(trimmed.toLowerCase())).toList();

    final tenantIds = <int>{...tenants.map((t) => t.id!)};
    for (final room in matchingRoomNumbers) {
      final allocation = await _allocationRepo.getActiveForRoom(room.id!);
      if (allocation != null) tenantIds.add(allocation.tenantId);
    }

    final results = <_SearchResult>[];
    for (final id in tenantIds) {
      final resolvedTenant = await _tenantRepo.getById(id);
      if (resolvedTenant == null) continue;

      Room? room;
      if (resolvedTenant.currentRoomId != null) {
        room = await _roomRepo.getById(resolvedTenant.currentRoomId!);
      }
      final pending = await _rentRepo.totalPendingForAllocation((await _allocationRepo.getActiveForTenant(id))?.id ?? -1);
      final deposits = await _depositRepo.getByTenant(id);
      final depositTotal = deposits.fold<double>(0, (sum, d) => sum + d.depositAmount);
      final payments = await _paymentRepo.getByTenant(id);
      final lastPayment = payments.isNotEmpty ? payments.first.paymentDate : null;

      results.add(_SearchResult(tenant: resolvedTenant, room: room, pending: pending, deposit: depositTotal, lastPaymentDate: lastPayment));
    }

    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by name, mobile, or room number',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? EmptyState(message: _controller.text.isEmpty ? 'Search tenants by name, mobile, or room number.' : 'No matches found.', icon: Icons.search)
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = _results[i];
                    return Card(
                      child: ListTile(
                        title: Text(r.tenant.fullName),
                        subtitle: Text(
                          '${r.room != null ? 'Room ${r.room!.roomNumber}' : 'Not allocated'}\n'
                          'Rent: ${formatCurrency(r.tenant.monthlyRent)} · Pending: ${formatCurrency(r.pending)}\n'
                          'Deposit: ${formatCurrency(r.deposit)} · Last Payment: ${r.lastPaymentDate != null ? formatDisplayDate(r.lastPaymentDate) : '-'}',
                        ),
                        isThreeLine: true,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TenantDetailScreen(tenantId: r.tenant.id!))),
                      ),
                    );
                  },
                ),
    );
  }
}
