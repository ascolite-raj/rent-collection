class Settlement {
  final int? id;
  final int allocationId;
  final int tenantId;
  final int roomId;
  final String leavingDate;
  final double finalMeterReading;
  final double pendingRent;
  final double pendingElectricity;
  final double otherPending;
  final double depositAmount;
  final double depositAdjustment;
  final double finalRefund;
  final String? notes;
  final String createdAt;

  Settlement({
    this.id,
    required this.allocationId,
    required this.tenantId,
    required this.roomId,
    required this.leavingDate,
    required this.finalMeterReading,
    required this.pendingRent,
    required this.pendingElectricity,
    required this.otherPending,
    required this.depositAmount,
    required this.depositAdjustment,
    required this.finalRefund,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'allocation_id': allocationId,
      'tenant_id': tenantId,
      'room_id': roomId,
      'leaving_date': leavingDate,
      'final_meter_reading': finalMeterReading,
      'pending_rent': pendingRent,
      'pending_electricity': pendingElectricity,
      'other_pending': otherPending,
      'deposit_amount': depositAmount,
      'deposit_adjustment': depositAdjustment,
      'final_refund': finalRefund,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['id'] as int?,
      allocationId: map['allocation_id'] as int,
      tenantId: map['tenant_id'] as int,
      roomId: map['room_id'] as int,
      leavingDate: map['leaving_date'] as String,
      finalMeterReading: (map['final_meter_reading'] as num).toDouble(),
      pendingRent: (map['pending_rent'] as num).toDouble(),
      pendingElectricity: (map['pending_electricity'] as num).toDouble(),
      otherPending: (map['other_pending'] as num).toDouble(),
      depositAmount: (map['deposit_amount'] as num).toDouble(),
      depositAdjustment: (map['deposit_adjustment'] as num).toDouble(),
      finalRefund: (map['final_refund'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
