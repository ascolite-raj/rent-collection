import 'package:flutter/material.dart';

import '../../models/electricity_bill.dart';
import '../../models/room.dart';
import '../../repositories/electricity_repository.dart';
import '../../repositories/room_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import 'add_meter_reading_screen.dart';
import 'record_electricity_payment_screen.dart';

class ElectricityScreen extends StatefulWidget {
  const ElectricityScreen({super.key});

  @override
  State<ElectricityScreen> createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends State<ElectricityScreen> {
  final _roomRepo = RoomRepository();
  final _electricityRepo = ElectricityRepository();
  late Future<List<Room>> _roomsFuture;
  late Future<List<ElectricityBill>> _pendingFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _roomsFuture = _roomRepo.getAll(includeInactive: false);
    _pendingFuture = _electricityRepo.getPending();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_roomsFuture, _pendingFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Electricity'),
          bottom: const TabBar(tabs: [Tab(text: 'Record Reading'), Tab(text: 'Pending Bills')]),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Room>>(
                future: _roomsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final rooms = snapshot.data!.where((r) => r.status == RoomStatus.occupied).toList();
                  if (rooms.isEmpty) {
                    return ListView(
                      children: const [EmptyState(message: 'No occupied rooms to record readings for.', icon: Icons.bolt_outlined)],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final room = rooms[i];
                      return Card(
                        child: ListTile(
                          title: Text('Room ${room.roomNumber}'),
                          subtitle: Text('Current reading: ${room.currentMeterReading.toStringAsFixed(0)}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => AddMeterReadingScreen(room: room)));
                            _refresh();
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<ElectricityBill>>(
                future: _pendingFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final bills = snapshot.data!;
                  if (bills.isEmpty) {
                    return ListView(
                      children: const [EmptyState(message: 'No pending electricity bills.', icon: Icons.check_circle_outline)],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: bills.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final b = bills[i];
                      return Card(
                        child: ListTile(
                          title: Text(formatCurrency(b.pendingAmount)),
                          subtitle: Text('${formatDisplayDate(b.fromDate)} → ${formatDisplayDate(b.toDate)}'),
                          trailing: StatusBadge.forStatus(b.paymentStatus),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => RecordElectricityPaymentScreen(bill: b)));
                            _refresh();
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
