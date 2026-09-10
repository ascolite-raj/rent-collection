import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../models/room.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/room_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import 'expense_form_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _expenseRepo = ExpenseRepository();
  final _roomRepo = RoomRepository();
  String? _categoryFilter;
  int? _roomFilter;
  List<Room> _rooms = [];
  late Future<List<Expense>> _future;

  @override
  void initState() {
    super.initState();
    _load();
    _roomRepo.getAll().then((rooms) {
      if (mounted) setState(() => _rooms = rooms);
    });
  }

  void _load() {
    _future = _expenseRepo.filter(category: _categoryFilter, roomId: _roomFilter);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          PopupMenuButton<int?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (roomId) => setState(() {
              _roomFilter = roomId;
              _load();
            }),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All Rooms')),
              ..._rooms.map((r) => PopupMenuItem(value: r.id, child: Text('Room ${r.roomNumber}'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseFormScreen()));
          _refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip(null, 'All'),
                  ...ExpenseCategory.all.map((c) => _chip(c, ExpenseCategory.label(c))),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Expense>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final expenses = snapshot.data!;
                  if (expenses.isEmpty) {
                    return ListView(children: const [EmptyState(message: 'No expenses recorded yet.', icon: Icons.build_outlined)]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: expenses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = expenses[i];
                      return Card(
                        child: ListTile(
                          title: Text('${ExpenseCategory.label(e.category)} · ${formatCurrency(e.amount)}'),
                          subtitle: Text('${formatDisplayDate(e.expenseDate)}${e.description != null ? ' · ${e.description}' : ''}'),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseFormScreen(expense: e)));
                            _refresh();
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String? category, String label) {
    final selected = _categoryFilter == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() {
          _categoryFilter = category;
          _load();
        }),
      ),
    );
  }
}
