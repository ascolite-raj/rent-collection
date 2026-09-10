class PaymentStatus {
  static const paid = 'paid';
  static const partial = 'partial';
  static const pending = 'pending';

  static String fromAmounts(double total, double paid) {
    if (paid <= 0) return pending;
    if (paid >= total) return PaymentStatus.paid;
    return partial;
  }
}

class RentTransaction {
  final int? id;
  final int tenantId;
  final int roomId;
  final int allocationId;
  final String billingMonth; // yyyy-MM
  final String fromDate;
  final String toDate;
  final double rentAmount;
  final String? dueDate;
  final double paidAmount;
  final double pendingAmount;
  final String? paymentDate;
  final String paymentStatus;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  RentTransaction({
    this.id,
    required this.tenantId,
    required this.roomId,
    required this.allocationId,
    required this.billingMonth,
    required this.fromDate,
    required this.toDate,
    required this.rentAmount,
    this.dueDate,
    this.paidAmount = 0,
    double? pendingAmount,
    this.paymentDate,
    String? paymentStatus,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  })  : pendingAmount = pendingAmount ?? (rentAmount - paidAmount),
        paymentStatus = paymentStatus ?? PaymentStatus.fromAmounts(rentAmount, paidAmount);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'room_id': roomId,
      'allocation_id': allocationId,
      'billing_month': billingMonth,
      'from_date': fromDate,
      'to_date': toDate,
      'rent_amount': rentAmount,
      'due_date': dueDate,
      'paid_amount': paidAmount,
      'pending_amount': pendingAmount,
      'payment_date': paymentDate,
      'payment_status': paymentStatus,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory RentTransaction.fromMap(Map<String, dynamic> map) {
    return RentTransaction(
      id: map['id'] as int?,
      tenantId: map['tenant_id'] as int,
      roomId: map['room_id'] as int,
      allocationId: map['allocation_id'] as int,
      billingMonth: map['billing_month'] as String,
      fromDate: map['from_date'] as String,
      toDate: map['to_date'] as String,
      rentAmount: (map['rent_amount'] as num).toDouble(),
      dueDate: map['due_date'] as String?,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      pendingAmount: (map['pending_amount'] as num?)?.toDouble() ?? 0,
      paymentDate: map['payment_date'] as String?,
      paymentStatus: map['payment_status'] as String,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
