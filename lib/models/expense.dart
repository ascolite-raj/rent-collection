class ExpenseCategory {
  static const repair = 'repair';
  static const plumbing = 'plumbing';
  static const electrical = 'electrical';
  static const cleaning = 'cleaning';
  static const maintenance = 'maintenance';
  static const other = 'other';

  static const all = [repair, plumbing, electrical, cleaning, maintenance, other];

  static String label(String category) {
    switch (category) {
      case repair:
        return 'Repair';
      case plumbing:
        return 'Plumbing';
      case electrical:
        return 'Electrical';
      case cleaning:
        return 'Cleaning';
      case maintenance:
        return 'Maintenance';
      default:
        return 'Other';
    }
  }
}

class Expense {
  final int? id;
  final int? roomId;
  final String category;
  final String expenseDate;
  final double amount;
  final String? description;
  final String? notes;
  final String createdAt;

  Expense({
    this.id,
    this.roomId,
    required this.category,
    required this.expenseDate,
    required this.amount,
    this.description,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'category': category,
      'expense_date': expenseDate,
      'amount': amount,
      'description': description,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      roomId: map['room_id'] as int?,
      category: map['category'] as String,
      expenseDate: map['expense_date'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
