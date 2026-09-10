class MeterReading {
  final int? id;
  final int roomId;
  final int? tenantId;
  final int? allocationId;
  final String readingDate;
  final double meterReading;
  final String? notes;
  final String createdAt;

  MeterReading({
    this.id,
    required this.roomId,
    this.tenantId,
    this.allocationId,
    required this.readingDate,
    required this.meterReading,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'tenant_id': tenantId,
      'allocation_id': allocationId,
      'reading_date': readingDate,
      'meter_reading': meterReading,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory MeterReading.fromMap(Map<String, dynamic> map) {
    return MeterReading(
      id: map['id'] as int?,
      roomId: map['room_id'] as int,
      tenantId: map['tenant_id'] as int?,
      allocationId: map['allocation_id'] as int?,
      readingDate: map['reading_date'] as String,
      meterReading: (map['meter_reading'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
