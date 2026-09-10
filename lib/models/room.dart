class RoomStatus {
  static const occupied = 'occupied';
  static const vacant = 'vacant';
  static const inactive = 'inactive';
}

class Room {
  final int? id;
  final String roomNumber;
  final String? description;
  final double monthlyRent;
  final String? meterNumber;
  final double currentMeterReading;
  final String status;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  Room({
    this.id,
    required this.roomNumber,
    this.description,
    required this.monthlyRent,
    this.meterNumber,
    this.currentMeterReading = 0,
    this.status = RoomStatus.vacant,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Room copyWith({
    int? id,
    String? roomNumber,
    String? description,
    double? monthlyRent,
    String? meterNumber,
    double? currentMeterReading,
    String? status,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      description: description ?? this.description,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      meterNumber: meterNumber ?? this.meterNumber,
      currentMeterReading: currentMeterReading ?? this.currentMeterReading,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_number': roomNumber,
      'description': description,
      'monthly_rent': monthlyRent,
      'meter_number': meterNumber,
      'current_meter_reading': currentMeterReading,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] as int?,
      roomNumber: map['room_number'] as String,
      description: map['description'] as String?,
      monthlyRent: (map['monthly_rent'] as num).toDouble(),
      meterNumber: map['meter_number'] as String?,
      currentMeterReading: (map['current_meter_reading'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
