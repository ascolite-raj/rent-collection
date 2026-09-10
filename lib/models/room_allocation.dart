class AllocationStatus {
  static const active = 'active';
  static const closed = 'closed';
}

class RoomAllocation {
  final int? id;
  final int roomId;
  final int tenantId;
  final String joiningDate;
  final String? leavingDate;
  final double monthlyRent;
  final double initialMeterReading;
  final double? finalMeterReading;
  final String status;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  RoomAllocation({
    this.id,
    required this.roomId,
    required this.tenantId,
    required this.joiningDate,
    this.leavingDate,
    required this.monthlyRent,
    required this.initialMeterReading,
    this.finalMeterReading,
    this.status = AllocationStatus.active,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  RoomAllocation copyWith({
    String? leavingDate,
    double? finalMeterReading,
    String? status,
    String? notes,
    String? updatedAt,
  }) {
    return RoomAllocation(
      id: id,
      roomId: roomId,
      tenantId: tenantId,
      joiningDate: joiningDate,
      leavingDate: leavingDate ?? this.leavingDate,
      monthlyRent: monthlyRent,
      initialMeterReading: initialMeterReading,
      finalMeterReading: finalMeterReading ?? this.finalMeterReading,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'tenant_id': tenantId,
      'joining_date': joiningDate,
      'leaving_date': leavingDate,
      'monthly_rent': monthlyRent,
      'initial_meter_reading': initialMeterReading,
      'final_meter_reading': finalMeterReading,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory RoomAllocation.fromMap(Map<String, dynamic> map) {
    return RoomAllocation(
      id: map['id'] as int?,
      roomId: map['room_id'] as int,
      tenantId: map['tenant_id'] as int,
      joiningDate: map['joining_date'] as String,
      leavingDate: map['leaving_date'] as String?,
      monthlyRent: (map['monthly_rent'] as num).toDouble(),
      initialMeterReading: (map['initial_meter_reading'] as num).toDouble(),
      finalMeterReading: (map['final_meter_reading'] as num?)?.toDouble(),
      status: map['status'] as String,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
