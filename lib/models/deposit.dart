class DepositStatus {
  static const held = 'held';
  static const partiallyRefunded = 'partially_refunded';
  static const refunded = 'refunded';
}

class Deposit {
  final int? id;
  final int tenantId;
  final int roomId;
  final int allocationId;
  final double depositAmount;
  final String depositDate;
  final String status;
  final double refundAmount;
  final double adjustmentAmount;
  final String? refundDate;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  Deposit({
    this.id,
    required this.tenantId,
    required this.roomId,
    required this.allocationId,
    required this.depositAmount,
    required this.depositDate,
    this.status = DepositStatus.held,
    this.refundAmount = 0,
    this.adjustmentAmount = 0,
    this.refundDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'room_id': roomId,
      'allocation_id': allocationId,
      'deposit_amount': depositAmount,
      'deposit_date': depositDate,
      'status': status,
      'refund_amount': refundAmount,
      'adjustment_amount': adjustmentAmount,
      'refund_date': refundDate,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Deposit.fromMap(Map<String, dynamic> map) {
    return Deposit(
      id: map['id'] as int?,
      tenantId: map['tenant_id'] as int,
      roomId: map['room_id'] as int,
      allocationId: map['allocation_id'] as int,
      depositAmount: (map['deposit_amount'] as num).toDouble(),
      depositDate: map['deposit_date'] as String,
      status: map['status'] as String,
      refundAmount: (map['refund_amount'] as num?)?.toDouble() ?? 0,
      adjustmentAmount: (map['adjustment_amount'] as num?)?.toDouble() ?? 0,
      refundDate: map['refund_date'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
