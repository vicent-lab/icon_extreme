import 'package:intl/intl.dart';

/// One place for how money, dates and labels look, so the same figure reads the same everywhere.
final _num = NumberFormat.decimalPattern();

/// "UGX 4,500,000". Accepts numbers or numeric strings (the database returns both).
String ugx(Object? v) => 'UGX ${_num.format(num.tryParse('${v ?? 0}') ?? 0)}';

String number(Object? v) => _num.format(num.tryParse('${v ?? 0}') ?? 0);

/// East Africa Time is UTC+3 all year. Dates from the database are shown in the viewer's local time.
String dateShort(DateTime? d) => d == null ? '' : DateFormat('d MMM yyyy').format(d.toLocal());
String dateLong(DateTime? d) => d == null ? '' : DateFormat('EEE d MMM yyyy').format(d.toLocal());
String dateTime(DateTime? d) => d == null ? '' : DateFormat('d MMM yyyy, h:mm a').format(d.toLocal());
String isoDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// "in_progress" -> "In progress"
String pretty(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
