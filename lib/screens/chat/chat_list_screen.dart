import 'package:flutter/material.dart';

import '../../models/room.dart';
import '../../repositories/conversation_repository.dart';
import '../../repositories/room_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/common.dart';
import '../allocation/allocate_tenant_screen.dart';
import '../search/search_screen.dart';
import '../tenants/tenant_form_screen.dart';
import 'chat_conversation_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _conversationRepo = ConversationRepository();
  final _roomRepo = RoomRepository();

  late Future<List<ConversationSummary>> _inboxFuture;
  late Future<List<Room>> _vacantRoomsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _inboxFuture = _conversationRepo.getInbox();
    _vacantRoomsFuture = _roomRepo.getAll(includeInactive: false);
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_inboxFuture, _vacantRoomsFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantFormScreen()));
          _refresh();
        },
        child: const Icon(Icons.person_add_alt),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Object>>(
          future: Future.wait<Object>([_inboxFuture, _vacantRoomsFuture]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final summaries = snapshot.data![0] as List<ConversationSummary>;
            final vacantRooms = (snapshot.data![1] as List<Room>).where((r) => r.status == RoomStatus.vacant).toList();

            if (summaries.isEmpty && vacantRooms.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(message: 'No tenants yet. Tap + to add your first tenant.', icon: Icons.chat_bubble_outline),
                ],
              );
            }

            return ListView(
              children: [
                ...summaries.map((s) => _ConversationTile(
                      summary: s,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatConversationScreen(tenantId: s.tenantId)));
                        _refresh();
                      },
                    )),
                if (vacantRooms.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Vacant rooms', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                  ),
                  ...vacantRooms.map((room) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.15),
                          child: const Icon(Icons.meeting_room_outlined, color: Colors.orange),
                        ),
                        title: Text('Room ${room.roomNumber}'),
                        subtitle: const Text('Vacant · tap to allocate a tenant'),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => AllocateTenantScreen(room: room)));
                          _refresh();
                        },
                      )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationSummary summary;
  final VoidCallback onTap;

  const _ConversationTile({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = summary.status == 'active';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isActive ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
        child: Text(
          summary.tenantName.isNotEmpty ? summary.tenantName[0].toUpperCase() : '?',
          style: TextStyle(color: isActive ? Colors.green[800] : Colors.grey[700], fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(summary.tenantName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        summary.roomNumber != null
            ? '${summary.roomNumber != null ? "Room ${summary.roomNumber} · " : ""}${summary.lastMessagePreview ?? "No activity yet"}'
            : summary.lastMessagePreview ?? 'No activity yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (summary.lastMessageTime != null)
            Text(formatDisplayDate(summary.lastMessageTime), style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          if (summary.pendingAmount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
              child: Text(
                formatCurrency(summary.pendingAmount),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
