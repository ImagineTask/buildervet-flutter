import 'package:intl/intl.dart';

class CurrencyUtils {
  CurrencyUtils._();

  static final _gbpFormat = NumberFormat.currency(symbol: '£', decimalDigits: 0);
  static final _gbpDecimalFormat = NumberFormat.currency(symbol: '£', decimalDigits: 2);

  static String formatPrice(double amount) {
    if (amount == amount.roundToDouble()) {
      return _gbpFormat.format(amount);
    }
    return _gbpDecimalFormat.format(amount);
  }

  static String formatPriceCompact(double amount) {
    if (amount >= 1000) {
      return '£${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
    }
    return formatPrice(amount);
  }
}
