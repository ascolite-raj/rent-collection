class Validators {
  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? mobileNumber(String? value, {bool optional = true}) {
    if (value == null || value.trim().isEmpty) {
      return optional ? null : 'Mobile number is required';
    }
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10 || digitsOnly.length > 13) {
      return 'Enter a valid mobile number';
    }
    return null;
  }

  static String? nonNegativeAmount(String? value, {String label = 'Amount'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    final parsed = double.tryParse(value);
    if (parsed == null) return 'Enter a valid $label';
    if (parsed < 0) return '$label cannot be negative';
    return null;
  }

  static String? positiveAmount(String? value, {String label = 'Amount'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    final parsed = double.tryParse(value);
    if (parsed == null) return 'Enter a valid $label';
    if (parsed <= 0) return '$label must be greater than zero';
    return null;
  }

  static String? meterReading(String? value, {double? minAllowed, String label = 'Meter reading'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    final parsed = double.tryParse(value);
    if (parsed == null) return 'Enter a valid $label';
    if (parsed < 0) return '$label cannot be negative';
    if (minAllowed != null && parsed < minAllowed) {
      return '$label cannot be lower than previous reading ($minAllowed)';
    }
    return null;
  }
}
