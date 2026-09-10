class PaymentType {
  static const rent = 'rent';
  static const electricity = 'electricity';
  static const deposit = 'deposit';
  static const depositRefund = 'deposit_refund';
  static const other = 'other';

  static const all = [rent, electricity, deposit, depositRefund, other];

  static String label(String type) {
    switch (type) {
      case rent:
        return 'Rent';
      case electricity:
        return 'Electricity';
      case deposit:
        return 'Deposit';
      case depositRefund:
        return 'Deposit Refund';
      default:
        return 'Other';
    }
  }
}

class PaymentMethod {
  static const cash = 'cash';
  static const upi = 'upi';
  static const bankTransfer = 'bank_transfer';
  static const other = 'other';

  static const all = [cash, upi, bankTransfer, other];

  static String label(String method) {
    switch (method) {
      case cash:
        return 'Cash';
      case upi:
        return 'UPI';
      case bankTransfer:
        return 'Bank Transfer';
      default:
        return 'Other';
    }
  }
}

class Payment {
  final int? id;
  final int? tenantId;
  final int? roomId;
  final String paymentType;
  final int? referenceId;
  final double amount;
  final String paymentDate;
  final String paymentMethod;
  final String? notes;
  final String createdAt;

  Payment({
    this.id,
    this.tenantId,
    this.roomId,
    required this.paymentType,
    this.referenceId,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod = PaymentMethod.cash,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'room_id': roomId,
      'payment_type': paymentType,
      'reference_id': referenceId,
      'amount': amount,
      'payment_date': paymentDate,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int?,
      tenantId: map['tenant_id'] as int?,
      roomId: map['room_id'] as int?,
      paymentType: map['payment_type'] as String,
      referenceId: map['reference_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: map['payment_date'] as String,
      paymentMethod: map['payment_method'] as String,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
