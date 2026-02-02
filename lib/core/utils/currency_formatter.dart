import 'package:intl/intl.dart';

class CurrencyFormatter {
  // Malaysian Ringgit
  static final NumberFormat _myrFormatter = NumberFormat.currency(
    locale: 'en_MY',
    symbol: 'RM',
    decimalDigits: 2,
  );

  static String format(double amount) {
    return _myrFormatter.format(amount);
  }

  static String get currencySymbol => 'RM';
}
