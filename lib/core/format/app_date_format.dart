import 'package:intl/intl.dart';

/// 应用内统一日期格式；`DateFormat` 构造需要解析 pattern，缓存后供列表高频复用。
final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm');
final DateFormat _dateCompactFormat = DateFormat('MM/dd');
final DateFormat _dateTimeCompactFormat = DateFormat('MM/dd HH:mm');

/// `yyyy/MM/dd`，统一转为本地时间。
String formatAppDate(DateTime value) => _dateFormat.format(value.toLocal());

/// `yyyy/MM/dd HH:mm`，统一转为本地时间。
String formatAppDateTime(DateTime value) =>
    _dateTimeFormat.format(value.toLocal());

/// `MM/dd`，用于空间紧张的列表/顶栏，统一转为本地时间。
String formatAppDateCompact(DateTime value) =>
    _dateCompactFormat.format(value.toLocal());

/// `MM/dd HH:mm`，用于空间紧张的列表/顶栏，统一转为本地时间。
String formatAppDateTimeCompact(DateTime value) =>
    _dateTimeCompactFormat.format(value.toLocal());
