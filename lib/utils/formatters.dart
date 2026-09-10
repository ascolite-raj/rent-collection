import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _currencyFormatDecimal =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _displayDateFormat = DateFormat('dd-MMM-yyyy');
final _storageDateFormat = DateFormat('yyyy-MM-dd');
final _monthLabelFormat = DateFormat('MMMM yyyy');

String formatCurrency(double amount, {bool decimals = false}) {
  return decimals ? _currencyFormatDecimal.format(amount) : _currencyFormat.format(amount);
}

/// Parses a storage-format date string (yyyy-MM-dd) for display as dd-MMM-yyyy.
String formatDisplayDate(String? storageDate) {
  if (storageDate == null || storageDate.isEmpty) return '-';
  try {
    final date = _storageDateFormat.parse(storageDate);
    return _displayDateFormat.format(date);
  } catch (_) {
    return storageDate;
  }
}

String formatDateForStorage(DateTime date) => _storageDateFormat.format(date);

DateTime parseStorageDate(String storageDate) => _storageDateFormat.parse(storageDate);

String todayForStorage() => formatDateForStorage(DateTime.now());

/// Full timestamp (date + time) for records that need chat-style time display.
String nowIsoForStorage() => DateTime.now().toIso8601String();

final _timeOfDayFormat = DateFormat('h:mm a');
final _chatDateFormat = DateFormat('d MMM yyyy');

/// Formats an ISO timestamp (from [nowIsoForStorage]) as "9:02 AM". Falls back
/// gracefully for plain yyyy-MM-dd values (no time component) by returning ''.
String formatTimeOfDay(String timestamp) {
  try {
    final parsed = DateTime.parse(timestamp);
    return _timeOfDayFormat.format(parsed);
  } catch (_) {
    return '';
  }
}

/// Chat-style date separator label: Today / Yesterday / d MMM yyyy.
String formatChatDateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return _chatDateFormat.format(date);
}

/// Parses either a full ISO timestamp or a plain yyyy-MM-dd date string.
DateTime parseFlexibleDate(String value) {
  try {
    return DateTime.parse(value);
  } catch (_) {
    return parseStorageDate(value);
  }
}

/// e.g. "2026-02" -> "February 2026"
String formatBillingMonthLabel(String billingMonth) {
  try {
    final date = DateFormat('yyyy-MM').parse(billingMonth);
    return _monthLabelFormat.format(date);
  } catch (_) {
    return billingMonth;
  }
}

String currentBillingMonth() => DateFormat('yyyy-MM').format(DateTime.now());

String billingMonthFor(DateTime date) => DateFormat('yyyy-MM').format(date);
