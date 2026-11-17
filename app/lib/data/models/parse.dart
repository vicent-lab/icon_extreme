/// Small helpers so models read database maps safely (a missing column never crashes a screen).
String str(Object? v, [String fallback = '']) => v == null ? fallback : '$v';
String? strOrNull(Object? v) => (v == null || '$v'.isEmpty) ? null : '$v';
int intOf(Object? v, [int fallback = 0]) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? fallback);
int? intOrNull(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
num numOf(Object? v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);
num? numOrNull(Object? v) => v == null ? null : (v is num ? v : num.tryParse('$v'));
bool boolOf(Object? v) => v == true;
DateTime? dateOrNull(Object? v) => v == null ? null : DateTime.tryParse('$v');
