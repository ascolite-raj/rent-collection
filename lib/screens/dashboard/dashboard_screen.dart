import 'package:flutter/material.dart';

import '../../repositories/dashboard_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/room_card.dart';
import '../../widgets/summary_card.dart';
import '../allocation/allocate_tenant_screen.dart';
import '../rooms/room_detail_screen.dart';
import '../search/search_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dashboardRepo = DashboardRepository();
  late Future<DashboardSummary> _summaryFuture;
  late Future<List<RoomCardData>> _cardsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _summaryFuture = _dashboardRepo.getSummary();
    _cardsFuture = _dashboardRepo.getRoomCards();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_summaryFuture, _cardsFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            FutureBuilder<DashboardSummary>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final s = snapshot.data!;
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.5,
                  children: [
                    SummaryCard(label: 'Total Rooms', value: '${s.totalRooms}', icon: Icons.meeting_room_outlined),
                    SummaryCard(label: 'Occupied Rooms', value: '${s.occupiedRooms}', icon: Icons.person, accentColor: Colors.green),
                    SummaryCard(label: 'Vacant Rooms', value: '${s.vacantRooms}', icon: Icons.person_off_outlined, accentColor: Colors.orange),
                    SummaryCard(label: 'Active Tenants', value: '${s.activeTenants}', icon: Icons.groups_outlined),
                    SummaryCard(label: 'This Month Rent', value: formatCurrency(s.currentMonthRent), icon: Icons.home_work_outlined),
                    SummaryCard(label: 'This Month Electricity', value: formatCurrency(s.currentMonthElectricity), icon: Icons.bolt_outlined),
                    SummaryCard(label: 'Total Pending', value: formatCurrency(s.totalPending), icon: Icons.warning_amber_outlined, accentColor: Colors.red),
                    SummaryCard(label: 'This Month Expenses', value: formatCurrency(s.currentMonthExpenses), icon: Icons.receipt_long_outlined),
                    SummaryCard(label: 'Net Collection', value: formatCurrency(s.netCollection), icon: Icons.account_balance_wallet_outlined, accentColor: Colors.teal),
                    SummaryCard(
                      label: 'Chat Pending · ${s.chatPendingCount}',
                      value: formatCurrency(s.chatPendingAmount),
                      icon: Icons.hourglass_empty,
                      accentColor: Colors.orange,
                    ),
                    SummaryCard(
                      label: 'Chat Collected · ${s.chatDoneCount}',
                      value: formatCurrency(s.chatDoneAmount),
                      icon: Icons.check_circle_outline,
                      accentColor: Colors.green,
                    ),
                  ],
                );
              },
            ),
            const SectionHeader(title: 'Rooms'),
            FutureBuilder<List<RoomCardData>>(
              future: _cardsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final cards = snapshot.data!;
                if (cards.isEmpty) {
                  return const EmptyState(message: 'No rooms yet. Add a room to get started.', icon: Icons.meeting_room_outlined);
                }
                return Column(
                  children: cards
                      .map((c) => RoomCard(
                            data: c,
                            onViewDetails: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => RoomDetailScreen(roomId: c.room.id!)),
                              );
                              _refresh();
                            },
                            onAllocate: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AllocateTenantScreen(room: c.room)),
                              );
                              _refresh();
                            },
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
