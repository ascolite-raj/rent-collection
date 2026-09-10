class TenantStatus {
  static const active = 'active';
  static const inactive = 'inactive';
}

class Tenant {
  final int? id;
  final String fullName;
  final String? mobileNumber;
  final int familyMembersCount;
  final String? familyMembersDetails; // newline-separated names/relations
  final String joiningDate; // yyyy-MM-dd
  final int? currentRoomId;
  final double monthlyRent;
  final String status;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  Tenant({
    this.id,
    required this.fullName,
    this.mobileNumber,
    this.familyMembersCount = 1,
    this.familyMembersDetails,
    required this.joiningDate,
    this.currentRoomId,
    required this.monthlyRent,
    this.status = TenantStatus.active,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Tenant copyWith({
    int? id,
    String? fullName,
    String? mobileNumber,
    int? familyMembersCount,
    String? familyMembersDetails,
    String? joiningDate,
    int? currentRoomId,
    bool clearCurrentRoomId = false,
    double? monthlyRent,
    String? status,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return Tenant(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      familyMembersCount: familyMembersCount ?? this.familyMembersCount,
      familyMembersDetails: familyMembersDetails ?? this.familyMembersDetails,
      joiningDate: joiningDate ?? this.joiningDate,
      currentRoomId: clearCurrentRoomId ? null : (currentRoomId ?? this.currentRoomId),
      monthlyRent: monthlyRent ?? this.monthlyRent,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'mobile_number': mobileNumber,
      'family_members_count': familyMembersCount,
      'family_members_details': familyMembersDetails,
      'joining_date': joiningDate,
      'current_room_id': currentRoomId,
      'monthly_rent': monthlyRent,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map['id'] as int?,
      fullName: map['full_name'] as String,
      mobileNumber: map['mobile_number'] as String?,
      familyMembersCount: (map['family_members_count'] as int?) ?? 1,
      familyMembersDetails: map['family_members_details'] as String?,
      joiningDate: map['joining_date'] as String,
      currentRoomId: map['current_room_id'] as int?,
      monthlyRent: (map['monthly_rent'] as num).toDouble(),
      status: map['status'] as String,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
