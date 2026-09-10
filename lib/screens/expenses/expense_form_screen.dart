import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../models/room.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/room_repository.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense;
  final Room? defaultRoom;

  const ExpenseFormScreen({super.key, this.expense, this.defaultRoom});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _expenseRepo = ExpenseRepository();
  final _roomRepo = RoomRepository();

  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  DateTime _expenseDate = DateTime.now();
  String _category = ExpenseCategory.repair;
  Room? _room;
  List<Room> _rooms = [];

  bool _saving = false;
  bool get _isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amountController = TextEditingController(text: e != null ? e.amount.toStringAsFixed(0) : '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    if (e != null) {
      _expenseDate = parseStorageDate(e.expenseDate);
      _category = e.category;
    }
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final rooms = await _roomRepo.getAll();
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      if (widget.expense != null) {
        final matches = rooms.where((r) => r.id == widget.expense!.roomId);
        _room = matches.isEmpty ? null : matches.first;
      } else if (widget.defaultRoom != null) {
        final matches = rooms.where((r) => r.id == widget.defaultRoom!.id);
        _room = matches.isEmpty ? null : matches.first;
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final expense = Expense(
        id: widget.expense?.id,
        roomId: _room?.id,
        category: _category,
        expenseDate: formatDateForStorage(_expenseDate),
        amount: double.parse(_amountController.text),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.expense?.createdAt ?? '',
      );
      if (_isEdit) {
        await _expenseRepo.update(expense);
      } else {
        await _expenseRepo.create(expense);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(context, title: 'Delete Expense', message: 'Remove this expense record?', destructive: true);
    if (!confirmed) return;
    await _expenseRepo.delete(widget.expense!.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Expense' : 'Add Expense'),
        actions: [
          if (_isEdit) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ExpenseCategory.all.map((c) => DropdownMenuItem(value: c, child: Text(ExpenseCategory.label(c)))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Room?>(
              value: _room,
              decoration: const InputDecoration(labelText: 'Room (optional)'),
              items: [
                const DropdownMenuItem<Room?>(value: null, child: Text('General / Not room-specific')),
                ..._rooms.map((r) => DropdownMenuItem(value: r, child: Text('Room ${r.roomNumber}'))),
              ],
              onChanged: (v) => setState(() => _room = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹'),
              keyboardType: TextInputType.number,
              validator: (v) => Validators.positiveAmount(v, label: 'Amount'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Expense Date'),
              subtitle: Text(formatDisplayDate(formatDateForStorage(_expenseDate))),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await pickDate(context, initial: _expenseDate);
                if (picked != null) setState(() => _expenseDate = picked);
              },
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator() : Text(_isEdit ? 'Save Changes' : 'Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
