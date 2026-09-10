import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../database/database_helper.dart';
import '../../models/electricity_bill.dart';
import '../../models/note.dart';
import '../../models/rent_transaction.dart';
import '../../models/room.dart';
import '../../models/room_allocation.dart';
import '../../models/tenant.dart';
import '../../repositories/allocation_repository.dart';
import '../../repositories/conversation_repository.dart';
import '../../repositories/electricity_repository.dart';
import '../../repositories/note_repository.dart';
import '../../repositories/rent_repository.dart';
import '../../repositories/room_repository.dart';
import '../../repositories/tenant_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../allocation/checkout_screen.dart';
import '../electricity/add_meter_reading_screen.dart';
import '../electricity/record_electricity_payment_screen.dart';
import '../expenses/expense_form_screen.dart';
import '../rent/record_rent_payment_screen.dart';
import '../tenants/tenant_detail_screen.dart';
import '../tenants/tenant_form_screen.dart';

class ChatConversationScreen extends StatefulWidget {
  final int tenantId;

  const ChatConversationScreen({super.key, required this.tenantId});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _conversationRepo = ConversationRepository();
  final _tenantRepo = TenantRepository();
  final _roomRepo = RoomRepository();
  final _allocationRepo = AllocationRepository();
  final _rentRepo = RentRepository();
  final _electricityRepo = ElectricityRepository();
  final _noteRepo = NoteRepository();
  final _imagePicker = ImagePicker();

  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  Tenant? _tenant;
  Room? _room;
  RoomAllocation? _activeAllocation;
  List<ConversationMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tenant = await _tenantRepo.getById(widget.tenantId);
    final allocation = await _allocationRepo.getActiveForTenant(widget.tenantId);
    final room = allocation != null ? await _roomRepo.getById(allocation.roomId) : null;
    final messages = await _conversationRepo.getConversation(widget.tenantId);

    if (!mounted) return;
    setState(() {
      _tenant = tenant;
      _activeAllocation = allocation;
      _room = room;
      _messages = messages;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendNote() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _noteRepo.create(tenantId: widget.tenantId, roomId: _room?.id, text: text);
      _textController.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _postNote(String text, {String? imagePath, String? kind, double? amount}) async {
    final tenant = _tenant;
    if (tenant == null) return;
    await _noteRepo.create(tenantId: tenant.id!, roomId: _room?.id, text: text, imagePath: imagePath, kind: kind, amount: amount);
    await _load();
  }

  Future<void> _setNoteDone(ConversationMessage message, bool isDone) async {
    final noteId = message.noteId;
    if (noteId == null) return;
    await _noteRepo.setDone(noteId, isDone);
    await _load();
  }

  Future<String?> _captureMeterPhoto() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'meter_photos'));
    if (!await photosDir.exists()) await photosDir.create(recursive: true);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
    final savedPath = p.join(photosDir.path, fileName);
    await File(picked.path).copy(savedPath);
    return savedPath;
  }

  Future<void> _quickDeposit() async {
    final amountController = TextEditingController();
    final amount = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16),
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              final parsed = double.tryParse(amountController.text);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Send Deposit', style: Theme.of(sheetContext).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹'),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: (parsed == null || parsed <= 0) ? null : () => Navigator.pop(sheetContext, parsed),
                    child: const Text('Send'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (amount == null) return;
    await _postNote('Deposit: ${formatCurrency(amount)}', kind: NoteKind.deposit, amount: amount);
  }

  Future<void> _quickLightBill() async {
    final room = _room;
    if (room == null) return;

    final readings = await _electricityRepo.getReadingsByRoom(room.id!);
    final previousReading = readings.isNotEmpty ? readings.first.meterReading : room.currentMeterReading;
    final rate = await DatabaseHelper.instance.getElectricityRate();
    if (!mounted) return;

    final currentController = TextEditingController();
    DateTime from = DateTime.now().subtract(const Duration(days: 30));
    DateTime to = DateTime.now();
    String? photoPath;

    final result = await showModalBottomSheet<(DateTime, DateTime, double, String?)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16),
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              final current = double.tryParse(currentController.text);
              final units = current != null && current >= previousReading ? current - previousReading : null;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Send Light Bill', style: Theme.of(sheetContext).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  KeyValueRow(label: 'Previous Reading', value: previousReading.toStringAsFixed(0)),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('From Date'),
                    subtitle: Text(formatDisplayDate(formatDateForStorage(from))),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await pickDate(sheetContext, initial: from);
                      if (picked != null) setSheetState(() => from = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('To Date'),
                    subtitle: Text(formatDisplayDate(formatDateForStorage(to))),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await pickDate(sheetContext, initial: to, firstDate: from);
                      if (picked != null) setSheetState(() => to = picked);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: currentController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Current Reading'),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  if (units != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Units: ${units.toStringAsFixed(0)} × ${formatCurrency(rate)} = ${formatCurrency(units * rate)}',
                      style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (photoPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(photoPath!), height: 140, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(photoPath == null ? 'Add Meter Photo' : 'Retake Photo'),
                    onPressed: () async {
                      final path = await _captureMeterPhoto();
                      if (path != null) setSheetState(() => photoPath = path);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        units == null || units <= 0 ? null : () => Navigator.pop(sheetContext, (from, to, units, photoPath)),
                    child: const Text('Send'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (result == null) return;
    final (fromDate, toDate, units, savedPhotoPath) = result;
    final amount = units * rate;
    await _postNote(
      '${formatDisplayDate(formatDateForStorage(fromDate))} to ${formatDisplayDate(formatDateForStorage(toDate))}: '
      '${units.toStringAsFixed(0)} units × ${formatCurrency(rate)} = ${formatCurrency(amount)}',
      imagePath: savedPhotoPath,
      kind: NoteKind.electricity,
      amount: amount,
    );
  }

  Future<void> _quickRent() async {
    final tenant = _tenant;
    if (tenant == null) return;
    final amountController = TextEditingController(text: tenant.monthlyRent.toStringAsFixed(0));
    DateTime from = DateTime.now().subtract(const Duration(days: 30));
    DateTime to = DateTime.now();

    final result = await showModalBottomSheet<(DateTime, DateTime, double)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16),
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              final amount = double.tryParse(amountController.text);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Send Rent', style: Theme.of(sheetContext).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('From Date'),
                    subtitle: Text(formatDisplayDate(formatDateForStorage(from))),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await pickDate(sheetContext, initial: from);
                      if (picked != null) setSheetState(() => from = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('To Date'),
                    subtitle: Text(formatDisplayDate(formatDateForStorage(to))),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await pickDate(sheetContext, initial: to, firstDate: from);
                      if (picked != null) setSheetState(() => to = picked);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹'),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: (amount == null || amount <= 0)
                        ? null
                        : () => Navigator.pop(sheetContext, (from, to, amount)),
                    child: const Text('Send'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (result == null) return;
    final (fromDate, toDate, amount) = result;
    await _postNote(
      '${formatDisplayDate(formatDateForStorage(fromDate))} to ${formatDisplayDate(formatDateForStorage(toDate))}: '
      'Rent ${formatCurrency(amount)}',
      kind: NoteKind.rent,
      amount: amount,
    );
  }

  Future<void> _openQuickActions() async {
    final tenant = _tenant;
    if (tenant == null) return;

    List<RentTransaction> pendingRent = [];
    List<ElectricityBill> pendingBills = [];
    if (_activeAllocation != null) {
      pendingRent = (await _rentRepo.getByTenant(tenant.id!)).where((r) => r.paymentStatus != PaymentStatus.paid).toList();
      pendingBills = (await _electricityRepo.getByTenant(tenant.id!)).where((b) => b.paymentStatus != PaymentStatus.paid).toList();
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              if (_activeAllocation != null && _room != null) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Send to tenant', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Send Deposit'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _quickDeposit();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bolt_outlined),
                  title: const Text('Send Light Bill'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _quickLightBill();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Send Rent (choose dates)'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _quickRent();
                  },
                ),
                const Divider(),
                if (pendingRent.isNotEmpty || pendingBills.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('Pending dues', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                ...pendingRent.map((r) => ListTile(
                      leading: const Icon(Icons.receipt_outlined, color: Colors.red),
                      title: Text('Rent — ${formatBillingMonthLabel(r.billingMonth)}'),
                      subtitle: Text('Pending: ${formatCurrency(r.pendingAmount)}'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => RecordRentPaymentScreen(rent: r))).then((_) => _load());
                      },
                    )),
                ...pendingBills.map((b) => ListTile(
                      leading: const Icon(Icons.bolt_outlined, color: Colors.red),
                      title: Text('Electricity — ${formatDisplayDate(b.fromDate)} to ${formatDisplayDate(b.toDate)}'),
                      subtitle: Text('Pending: ${formatCurrency(b.pendingAmount)}'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => RecordElectricityPaymentScreen(bill: b))).then((_) => _load());
                      },
                    )),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.speed_outlined),
                  title: const Text('Add Meter Reading'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AddMeterReadingScreen(room: _room!))).then((_) => _load());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.build_outlined),
                  title: const Text('Add Expense for this room'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseFormScreen(defaultRoom: _room))).then((_) => _load());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.orange),
                  title: const Text('Tenant Leaving / Checkout'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CheckoutScreen(allocation: _activeAllocation!, tenant: tenant, room: _room!)),
                    ).then((_) => _load());
                  },
                ),
                const Divider(),
              ],
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('View Full Profile'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TenantDetailScreen(tenantId: tenant.id!))).then((_) => _load());
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Tenant'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TenantFormScreen(tenant: tenant))).then((_) => _load());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _tenant == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final tenant = _tenant!;

    return Scaffold(
      appBar: AppBar(
        title: Text(tenant.fullName),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TenantDetailScreen(tenantId: tenant.id!))).then((_) => _load()),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              _room != null ? 'Room ${_room!.roomNumber} · ${tenant.status == 'active' ? 'Active' : 'Inactive'}' : 'Not currently allocated a room',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? const EmptyState(message: 'No activity yet. Use + below to record a payment, reading, or note.', icon: Icons.chat_bubble_outline)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final showDateSeparator = index == 0 ||
                          formatChatDateLabel(parseFlexibleDate(message.timestamp)) !=
                              formatChatDateLabel(parseFlexibleDate(_messages[index - 1].timestamp));
                      return Column(
                        children: [
                          if (showDateSeparator) _DateSeparator(label: formatChatDateLabel(parseFlexibleDate(message.timestamp))),
                          _MessageBubble(
                            message: message,
                            onToggleDone: message.noteId != null && message.noteKind != null
                                ? (value) => _setNoteDone(message, value)
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _openQuickActions,
                    tooltip: 'Add payment, reading, expense...',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a note...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onSubmitted: (_) => _sendNote(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    onPressed: _sending ? null : _sendNote,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ConversationMessage message;
  final ValueChanged<bool>? onToggleDone;
  const _MessageBubble({required this.message, this.onToggleDone});

  @override
  Widget build(BuildContext context) {
    final isOwner = message.side == MessageSide.owner;
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isOwner ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest;
    final onBubbleColor = isOwner ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final align = isOwner ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final time = formatTimeOfDay(message.timestamp);
    final hasStatus = onToggleDone != null;

    return Align(
      alignment: isOwner ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(message.imagePath!),
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(message.title, style: TextStyle(fontWeight: FontWeight.w600, color: onBubbleColor)),
            if (message.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(message.subtitle!, style: TextStyle(fontSize: 12, color: onBubbleColor.withValues(alpha: 0.7))),
            ],
            if (message.amount != null) ...[
              const SizedBox(height: 4),
              Text(formatCurrency(message.amount!), style: TextStyle(fontWeight: FontWeight.bold, color: onBubbleColor)),
            ],
            if (hasStatus) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.isDone ? 'Done' : 'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: message.isDone ? Colors.green : Colors.orange,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.7,
                    child: Switch(
                      value: message.isDone,
                      activeTrackColor: Colors.green,
                      onChanged: onToggleDone,
                    ),
                  ),
                ],
              ),
            ],
            if (time.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(time, style: TextStyle(fontSize: 10, color: onBubbleColor.withValues(alpha: 0.6))),
            ],
          ],
        ),
      ),
    );
  }
}
