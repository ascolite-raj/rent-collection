import '../database/database_helper.dart';

class LedgerEntry {
  final String date;
  final String label;
  final double amount;
  final String type; // deposit / rent / electricity

  LedgerEntry({required this.date, required this.label, required this.amount, required this.type});
}

class TenantLedger {
  final List<LedgerEntry> entries;
  final double totalRent;
  final double totalElectricity;
  final double totalPayments;
  final double totalPending;
  final double deposit;
  final double depositAdjustment;
  final double depositRefund;

  TenantLedger({
    required this.entries,
    required this.totalRent,
    required this.totalElectricity,
    required this.totalPayments,
    required this.totalPending,
    required this.deposit,
    required this.depositAdjustment,
    required this.depositRefund,
  });
}

/// Builds the full chronological financial ledger for one tenant, combining
/// deposits, rent, and electricity charges from their source-of-truth tables.
class LedgerRepository {
  final DatabaseHelper _helper = DatabaseHelper.instance;

  Future<TenantLedger> getTenantLedger(int tenantId, {String? fromDate, String? toDate}) async {
    final db = await _helper.database;
    final entries = <LedgerEntry>[];

    final deposits = await db.query('deposits', where: 'tenant_id = ?', whereArgs: [tenantId]);
    for (final d in deposits) {
      entries.add(LedgerEntry(
        date: d['deposit_date'] as String,
        label: 'Deposit Received',
        amount: (d['deposit_amount'] as num).toDouble(),
        type: 'deposit',
      ));
    }

    final rents = await db.query('rent_transactions', where: 'tenant_id = ?', whereArgs: [tenantId]);
    for (final r in rents) {
      entries.add(LedgerEntry(
        date: r['from_date'] as String,
        label: 'Rent (${r['billing_month']})',
        amount: (r['rent_amount'] as num).toDouble(),
        type: 'rent',
      ));
    }

    final bills = await db.query('electricity_bills', where: 'tenant_id = ?', whereArgs: [tenantId]);
    for (final b in bills) {
      entries.add(LedgerEntry(
        date: b['to_date'] as String,
        label: 'Electricity (${b['from_date']} to ${b['to_date']})',
        amount: (b['bill_amount'] as num).toDouble(),
        type: 'electricity',
      ));
    }

    entries.sort((a, b) => a.date.compareTo(b.date));

    final filtered = entries.where((e) {
      if (fromDate != null && e.date.compareTo(fromDate) < 0) return false;
      if (toDate != null && e.date.compareTo(toDate) > 0) return false;
      return true;
    }).toList();

    final totalRent = (await db.rawQuery(
            'SELECT COALESCE(SUM(rent_amount),0) t FROM rent_transactions WHERE tenant_id = ?', [tenantId]))
        .first['t'] as num;
    final totalElectricity = (await db.rawQuery(
            'SELECT COALESCE(SUM(bill_amount),0) t FROM electricity_bills WHERE tenant_id = ?', [tenantId]))
        .first['t'] as num;
    final totalPayments = (await db.rawQuery(
            'SELECT COALESCE(SUM(amount),0) t FROM payments WHERE tenant_id = ? AND payment_type IN (?, ?)',
            [tenantId, 'rent', 'electricity']))
        .first['t'] as num;
    final pendingRent = (await db.rawQuery(
            'SELECT COALESCE(SUM(pending_amount),0) t FROM rent_transactions WHERE tenant_id = ?', [tenantId]))
        .first['t'] as num;
    final pendingElectricity = (await db.rawQuery(
            'SELECT COALESCE(SUM(pending_amount),0) t FROM electricity_bills WHERE tenant_id = ?', [tenantId]))
        .first['t'] as num;
    final depositTotal =
        (await db.rawQuery('SELECT COALESCE(SUM(deposit_amount),0) t FROM deposits WHERE tenant_id = ?', [tenantId]))
            .first['t'] as num;
    final depositAdjustment = (await db.rawQuery(
            'SELECT COALESCE(SUM(adjustment_amount),0) t FROM deposits WHERE tenant_id = ?', [tenantId]))
        .first['t'] as num;
    final depositRefund =
        (await db.rawQuery('SELECT COALESCE(SUM(refund_amount),0) t FROM deposits WHERE tenant_id = ?', [tenantId]))
            .first['t'] as num;

    return TenantLedger(
      entries: filtered,
      totalRent: totalRent.toDouble(),
      totalElectricity: totalElectricity.toDouble(),
      totalPayments: totalPayments.toDouble(),
      totalPending: pendingRent.toDouble() + pendingElectricity.toDouble(),
      deposit: depositTotal.toDouble(),
      depositAdjustment: depositAdjustment.toDouble(),
      depositRefund: depositRefund.toDouble(),
    );
  }
}
