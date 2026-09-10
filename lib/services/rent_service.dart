import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/payment.dart';
import '../models/rent_transaction.dart';
import '../models/room_allocation.dart';
import '../repositories/payment_repository.dart';
import '../repositories/rent_repository.dart';
import '../utils/formatters.dart';

/// Generates monthly rent and records rent payments, keeping the rent_transactions
/// ledger as the single source of truth (never overwritten, one row per month).
class RentService {
  final DatabaseHelper _helper = DatabaseHelper.instance;
  final RentRepository _rentRepo = RentRepository();
  final PaymentRepository _paymentRepo = PaymentRepository();

  /// Creates a rent_transactions row for [billingMonth] for every currently active
  /// allocation that doesn't already have one. Returns how many were created.
  Future<int> generateForMonth(String billingMonth, {int dueDay = 5}) async {
    final db = await _helper.database;
    final activeRows = await db.query('room_allocations', where: "status = 'active'");
    final activeAllocations = activeRows.map(RoomAllocation.fromMap).toList();

    int created = 0;
    final monthStart = DateFormat('yyyy-MM').parse(billingMonth);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

    for (final allocation in activeAllocations) {
      final exists = await _rentRepo.existsForMonth(allocation.id!, billingMonth);
      if (exists) continue;

      final joining = parseStorageDate(allocation.joiningDate);
      final fromDate = joining.isAfter(monthStart) ? joining : monthStart;
      final dueDate = DateTime(monthStart.year, monthStart.month, dueDay);

      await _rentRepo.create(
        RentTransaction(
          tenantId: allocation.tenantId,
          roomId: allocation.roomId,
          allocationId: allocation.id!,
          billingMonth: billingMonth,
          fromDate: formatDateForStorage(fromDate),
          toDate: formatDateForStorage(monthEnd),
          rentAmount: allocation.monthlyRent,
          dueDate: formatDateForStorage(dueDate),
          createdAt: todayForStorage(),
          updatedAt: todayForStorage(),
        ),
      );
      created++;
    }
    return created;
  }

  Future<void> recordPayment({
    required int rentId,
    required int tenantId,
    required int roomId,
    required double amount,
    required String paymentDate,
    String paymentMethod = PaymentMethod.cash,
    String? notes,
  }) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      await _paymentRepo.create(
        Payment(
          tenantId: tenantId,
          roomId: roomId,
          paymentType: PaymentType.rent,
          referenceId: rentId,
          amount: amount,
          paymentDate: paymentDate,
          paymentMethod: paymentMethod,
          notes: notes,
          createdAt: todayForStorage(),
        ),
        executor: txn,
      );
      await _rentRepo.applyPayment(rentId, amount, paymentDate, executor: txn);
    });
  }
}
