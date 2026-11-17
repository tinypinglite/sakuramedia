import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/format/app_date_format.dart';
import 'package:sakuramedia/core/format/synced_at_label.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  test('日期 helper 输出固定 pattern', () {
    final value = DateTime(2026, 1, 2, 3, 4, 5);

    expect(formatAppDate(value), '2026/01/02');
    expect(formatAppDateTime(value), '2026/01/02 03:04');
    expect(formatAppDateCompact(value), '01/02');
    expect(formatAppDateTimeCompact(value), '01/02 03:04');
  });

  test('UTC 输入统一转为本地时间', () {
    final utc = DateTime.utc(2026, 1, 2, 3, 4);
    final local = utc.toLocal();

    expect(formatAppDateTime(utc), _localDateTime(local));
    expect(formatAppDate(utc), _localDate(local));
  });

  test('updated_at_label 保留旧 API 并委托新 helper', () {
    final value = DateTime(2026, 1, 2, 3, 4, 5);

    expect(formatUpdatedAtLabel(null), isNull);
    expect(formatUpdatedAtLabel(value), formatAppDateTime(value));
  });

  test('synced_at_label 空值与 compact 行为保持', () {
    final l10n = AppLocalizationsZh();
    final value = DateTime(2026, 1, 2, 3, 4, 5);

    expect(formatSyncedAtLabel(null, l10n: l10n), isNull);
    expect(
      formatSyncedAtLabel(value, l10n: l10n, withPrefix: false),
      formatAppDateTimeCompact(value),
    );
  });
}

String _localDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}

String _localDateTime(DateTime value) {
  return '${_localDate(value)} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
