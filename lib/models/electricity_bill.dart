import 'rent_transaction.dart' show PaymentStatus;

class ElectricityBill {
  final int? id;
  final int roomId;
  final int? tenantId;
  final int? allocationId;
  final String fromDate;
  final String toDate;
  final double previousReading;
  final double currentReading;
  final double totalUnits;
  final double ratePerUnit;
  final double billAmount;
  final double paidAmount;
  final double pendingAmount;
  final String paymentStatus;
  final String? paymentDate;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  factory ElectricityBill.calculate({
    int? id,
    required int roomId,
    int? tenantId,
    int? allocationId,
    required String fromDate,
    required String toDate,
    required double previousReading,
    required double currentReading,
    required double ratePerUnit,
    double paidAmount = 0,
    String? paymentDate,
    String? notes,
    required String createdAt,
    required String updatedAt,
  }) {
    final units = currentReading - previousReading;
    final amount = units * ratePerUnit;
    return ElectricityBill(
      id: id,
      roomId: roomId,
      tenantId: tenantId,
      allocationId: allocationId,
      fromDate: fromDate,
      toDate: toDate,
      previousReading: previousReading,
      currentReading: currentReading,
      totalUnits: units,
      ratePerUnit: ratePerUnit,
      billAmount: amount,
      paidAmount: paidAmount,
      pendingAmount: amount - paidAmount,
      paymentDate: paymentDate,
      paymentStatus: PaymentStatus.fromAmounts(amount, paidAmount),
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  ElectricityBill({
    this.id,
    required this.roomId,
    this.tenantId,
    this.allocationId,
    required this.fromDate,
    required this.toDate,
    required this.previousReading,
    required this.currentReading,
    required this.totalUnits,
    required this.ratePerUnit,
    required this.billAmount,
    this.paidAmount = 0,
    required this.pendingAmount,
    this.paymentDate,
    required this.paymentStatus,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'tenant_id': tenantId,
      'allocation_id': allocationId,
      'from_date': fromDate,
      'to_date': toDate,
      'previous_reading': previousReading,
      'current_reading': currentReading,
      'total_units': totalUnits,
      'rate_per_unit': ratePerUnit,
      'bill_amount': billAmount,
      'paid_amount': paidAmount,
      'pending_amount': pendingAmount,
      'payment_status': paymentStatus,
      'payment_date': paymentDate,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ElectricityBill.fromMap(Map<String, dynamic> map) {
    return ElectricityBill(
      id: map['id'] as int?,
      roomId: map['room_id'] as int,
      tenantId: map['tenant_id'] as int?,
      allocationId: map['allocation_id'] as int?,
      fromDate: map['from_date'] as String,
      toDate: map['to_date'] as String,
      previousReading: (map['previous_reading'] as num).toDouble(),
      currentReading: (map['current_reading'] as num).toDouble(),
      totalUnits: (map['total_units'] as num).toDouble(),
      ratePerUnit: (map['rate_per_unit'] as num).toDouble(),
      billAmount: (map['bill_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      pendingAmount: (map['pending_amount'] as num?)?.toDouble() ?? 0,
      paymentStatus: map['payment_status'] as String,
      paymentDate: map['payment_date'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
