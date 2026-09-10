import 'package:flutter/material.dart';

import '../../models/room.dart';
import '../../repositories/room_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import 'room_detail_screen.dart';
import 'room_form_screen.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final _roomRepo = RoomRepository();
  late Future<List<Room>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _roomRepo.getAll();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomFormScreen()));
          _refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Room>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final rooms = snapshot.data!;
            if (rooms.isEmpty) {
              return ListView(
                children: const [EmptyState(message: 'No rooms yet. Tap + to add one.', icon: Icons.meeting_room_outlined)],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final room = rooms[index];
                return Card(
                  child: ListTile(
                    title: Text('Room ${room.roomNumber}'),
                    subtitle: Text(formatMonthlyRentSubtitle(room)),
                    trailing: StatusBadge.forStatus(room.status),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomDetailScreen(roomId: room.id!)));
                      _refresh();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String formatMonthlyRentSubtitle(Room room) {
    final desc = room.description?.isNotEmpty == true ? '${room.description} · ' : '';
    return '$desc₹${room.monthlyRent.toStringAsFixed(0)}/month';
  }
}
