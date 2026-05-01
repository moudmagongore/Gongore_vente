import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Formatters partagés (devise, dates, nombres).
class Fmt {
  Fmt._();

  static final _moneyFr = NumberFormat.decimalPattern('fr_FR');
  static final _dateShort = DateFormat('dd/MM/yyyy', 'fr_FR');
  static final _dateLong = DateFormat('dd MMMM yyyy', 'fr_FR');
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

  /// "1 250 000 GNF"
  static String money(num value, {String? currency}) {
    final symbol = currency ?? AppConstants.defaultCurrencySymbol;
    return '${_moneyFr.format(value)} $symbol';
  }

  /// "1 250 000" (sans devise)
  static String number(num value) => _moneyFr.format(value);

  /// "30/04/2026"
  static String dateShort(DateTime d) => _dateShort.format(d);

  /// "30 avril 2026"
  static String dateLong(DateTime d) => _dateLong.format(d);

  /// "30/04/2026 14:32"
  static String dateTime(DateTime d) => _dateTime.format(d);
}
