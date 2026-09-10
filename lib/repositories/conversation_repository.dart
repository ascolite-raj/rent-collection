import '../database/database_helper.dart';
import '../utils/formatters.dart';

enum MessageSide { system, owner }

class ConversationMessage {
  final String timestamp;
  final String title;
  final String? subtitle;
  final double? amount;
  final String? imagePath;
  final MessageSide side;
  final String kind;

  /// Set only for 'note' messages created via the chat quick actions
  /// (Send Deposit / Send Light Bill / Send Rent) — lets the bubble offer a
  /// Done/Pending toggle. Freeform typed notes leave these null.
  final int? noteId;
  final String? noteKind;
  final bool isDone;

  ConversationMessage({
    required this.timestamp,
    required this.title,
    this.subtitle,
    this.amount,
    this.imagePath,
    required this.side,
    required this.kind,
    this.noteId,
    this.noteKind,
    this.isDone = false,
  });
}

class ConversationSummary {
  final int tenantId;
  final String tenantName;
  final int? roomId;
  final String? roomNumber;
  final String status;
  final String? lastMessagePreview;
  final String? lastMessageTime;
  final double pendingAmount;

  ConversationSummary({
    required this.tenantId,
    required this.tenantName,
    this.roomId,
    this.roomNumber,
    required this.status,
    this.lastMessagePreview,
    this.lastMessageTime,
    required this.pendingAmount,
  });
}

/// Builds a WhatsApp-style timeline for a tenant by merging every source-of-truth
/// table (deposits, rent, electricity, payments, settlements, free-text notes)
/// into one chronological list of messages. Nothing is stored redundantly —
/// this is a read-time projection over the existing relational tables.
class ConversationRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<List<ConversationMessage>> getConversation(int tenantId) async {
    final db = await _helper.database;
    final messages = <ConversationMessage>[];

    final allocations = await db.query('room_allocations', where: 'tenant_id = ?', whereArgs: [tenantId]);
    for (final a in allocations) {
      final roomRows = await db.query('rooms', where: 'id = ?', whereArgs: [a['room_id']], limit: 1);
      final roomNumber = roomRows.isNotEmpty ? roomRows.first['room_number'] as String : '?';
      messages.add(ConversationMessage(
        timestamp: a['joining_date'] as String,
        title: 'Joined Room $roomNumber',
        subtitle: 'Monthly rent ${formatCurrency((a['monthly_rent'] as num).toDouble())}',
        side: MessageSide.system,
        kind: 'allocation',
      ));
      if (a['leaving_date'] != null) {
        messages.add(ConversationMessage(
          timestamp: a['leaving_date'] as String,
          title: 'Left Room $roomNumber',
          side: MessageSide.system,
          kind: 'allocation',
        ));
      }
    }

    final deposits = await db.query('deposits', where: 'tenant_id = ?', whereArgs: [tenantId]);
    for (final d in deposits) {
      messages.add(ConversationMessage(
        timestamp: d['deposit_date'] as String,
        title: 'Deposit recorded: ${formatCurrency((d['deposit_amount'] as num).toDouble())}',
        side: MessageSide.system,
        kind: 'deposit',
        amount: (d['deposit_amount'] as num).toDouble(),
      ));
    }

    final rents = await db.query('rent_transactions', where: 'tenant_id = ?', whereArgs: [tenantId]);
    for (final r in rents) {
      messages.add(ConversationMessage(
        timestamp: r['from_date'] as String,
        title: 'Rent charged — ${formatBillingMonthLabel(r['billing_month'] as String)}',
        subtitle: 'Due ${formatDisplayDate(r['due_date'] as String?)}',
        amount: (r['rent_amount'] as num).toDouble(),
        side: MessageSide.system,
        kind: 'rent',
      ));
    }

    final bills = await db.query('electricity_bills', where: 'tenant_id = ?', whereArgs: [tenantId]);
    for (final b in bills) {
      messages.add(ConversationMessage(
        timestamp: b['to_date'] as String,
        title: 'Electricity bill: ${(b['total_units'] as num).toStringAsFixed(0)} units × '
            '${formatCurrency((b['rate_per_unit'] as num).toDouble())}',
        subtitle: '${formatDisplayDate(b['from_date'] as String)} → ${formatDisplayDate(b['to_date'] as String)}',
        amount: (b['bill_amount'] as num).toDouble(),
        side: MessageSide.system,
        kind: 'electricity',
      ));
    }

    final payments = await db.query('payments', where: 'tenant_id = ?', whereArgs: [tenantId]);
    for (final p in payments) {
      final type = p['payment_type'] as String;
      final label = switch (type) {
        'rent' => 'Rent payment received',
        'electricity' => 'Electricity payment received',
        'deposit' => 'Deposit received',
        'deposit_refund' => 'Deposit refunded',
        _ => 'Payment received',
      };
      messages.add(ConversationMessage(
        timestamp: p['payment_date'] as String,
        title: label,
        subtitle: p['notes'] as String?,
        amount: (p['amount'] as num).toDouble(),
        side: MessageSide.owner,
        kind: 'payment',
      ));
    }

    final settlements = await db.query('settlements', where: 'tenant_id = ?', whereArgs: [tenantId]);
    for (final s in settlements) {
      messages.add(ConversationMessage(
        timestamp: s['leaving_date'] as String,
        title: 'Checked out — Final refund ${formatCurrency((s['final_refund'] as num).toDouble())}',
        subtitle: 'Pending rent ${formatCurrency((s['pending_rent'] as num).toDouble())}, '
            'Pending electricity ${formatCurrency((s['pending_electricity'] as num).toDouble())}',
        side: MessageSide.system,
        kind: 'settlement',
      ));
    }

    final notes = await db.query('notes', where: 'tenant_id = ?', whereArgs: [tenantId]);
    for (final n in notes) {
      messages.add(ConversationMessage(
        timestamp: n['created_at'] as String,
        title: n['text'] as String,
        imagePath: n['image_path'] as String?,
        side: MessageSide.owner,
        kind: 'note',
        noteId: n['id'] as int?,
        noteKind: n['kind'] as String?,
        isDone: (n['is_done'] as int?) == 1,
      ));
    }

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  /// Chat-list style summary rows: one per active tenant, most recent activity first.
  Future<List<ConversationSummary>> getInbox({bool includeInactive = true}) async {
    final db = await _helper.database;
    final tenants = await db.query(
      'tenants',
      where: includeInactive ? null : "status = 'active'",
    );

    final summaries = <ConversationSummary>[];
    for (final t in tenants) {
      final tenantId = t['id'] as int;
      final roomId = t['current_room_id'] as int?;
      String? roomNumber;
      if (roomId != null) {
        final roomRows = await db.query('rooms', where: 'id = ?', whereArgs: [roomId], limit: 1);
        if (roomRows.isNotEmpty) roomNumber = roomRows.first['room_number'] as String;
      }

      final pendingRentRows = await db.rawQuery(
        'SELECT COALESCE(SUM(pending_amount),0) t FROM rent_transactions WHERE tenant_id = ?',
        [tenantId],
      );
      final pendingElecRows = await db.rawQuery(
        'SELECT COALESCE(SUM(pending_amount),0) t FROM electricity_bills WHERE tenant_id = ?',
        [tenantId],
      );
      final pending = (pendingRentRows.first['t'] as num).toDouble() + (pendingElecRows.first['t'] as num).toDouble();

      final lastNote = await db.query('notes', where: 'tenant_id = ?', whereArgs: [tenantId], orderBy: 'created_at DESC', limit: 1);
      final lastPayment = await db.query('payments', where: 'tenant_id = ?', whereArgs: [tenantId], orderBy: 'payment_date DESC', limit: 1);
      final lastRent = await db.query('rent_transactions', where: 'tenant_id = ?', whereArgs: [tenantId], orderBy: 'from_date DESC', limit: 1);

      String? preview;
      String? lastTime;
      final candidates = <(String, String)>[];
      if (lastNote.isNotEmpty) candidates.add((lastNote.first['created_at'] as String, lastNote.first['text'] as String));
      if (lastPayment.isNotEmpty) {
        candidates.add((
          lastPayment.first['payment_date'] as String,
          'Paid ${formatCurrency((lastPayment.first['amount'] as num).toDouble())}',
        ));
      }
      if (lastRent.isNotEmpty) {
        candidates.add((
          lastRent.first['from_date'] as String,
          'Rent charged: ${formatCurrency((lastRent.first['rent_amount'] as num).toDouble())}',
        ));
      }
      candidates.sort((a, b) => a.$1.compareTo(b.$1));
      if (candidates.isNotEmpty) {
        lastTime = candidates.last.$1;
        preview = candidates.last.$2;
      }

      summaries.add(ConversationSummary(
        tenantId: tenantId,
        tenantName: t['full_name'] as String,
        roomId: roomId,
        roomNumber: roomNumber,
        status: t['status'] as String,
        lastMessagePreview: preview,
        lastMessageTime: lastTime,
        pendingAmount: pending,
      ));
    }

    summaries.sort((a, b) => (b.lastMessageTime ?? '').compareTo(a.lastMessageTime ?? ''));
    return summaries;
  }
}
