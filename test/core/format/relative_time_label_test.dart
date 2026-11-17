import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/format/relative_time_label.dart';
import 'package:sakuramedia/l10n/app_localizations_en.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  final now = DateTime.parse('2026-07-28T12:00:00');
  final zh = AppLocalizationsZh();
  final en = AppLocalizationsEn();

  test('一分钟以内归「刚刚」', () {
    expect(
      formatRelativeTimeLabel(
        DateTime.parse('2026-07-28T11:59:30'),
        l10n: zh,
        now: now,
      ),
      '刚刚',
    );
    expect(formatRelativeTimeLabel(now, l10n: zh, now: now), '刚刚');
  });

  test('按分钟 / 小时 / 天分档', () {
    expect(
      formatRelativeTimeLabel(
        DateTime.parse('2026-07-28T11:15:00'),
        l10n: zh,
        now: now,
      ),
      '45 分钟前',
    );
    expect(
      formatRelativeTimeLabel(
        DateTime.parse('2026-07-28T09:00:00'),
        l10n: zh,
        now: now,
      ),
      '3 小时前',
    );
    expect(
      formatRelativeTimeLabel(
        DateTime.parse('2026-07-25T12:00:00'),
        l10n: zh,
        now: now,
      ),
      '3 天前',
    );
  });

  test('语境后缀由完整 ARB key 组合，中英语序都自然', () {
    expect(
      zh.lastCheckedRelative(
        formatRelativeTimeLabel(
          DateTime.parse('2026-07-25T12:00:00'),
          l10n: zh,
          now: now,
        ),
      ),
      '3 天前检测',
    );
    expect(
      en.lastCheckedRelative(
        formatRelativeTimeLabel(
          DateTime.parse('2026-07-25T12:00:00'),
          l10n: en,
          now: now,
        ),
      ),
      'Checked 3 days ago',
    );
  });

  test('英文使用单复数', () {
    expect(
      formatRelativeTimeLabel(
        DateTime.parse('2026-07-28T11:00:00'),
        l10n: en,
        now: now,
      ),
      '1 hour ago',
    );
    expect(
      formatRelativeTimeLabel(
        DateTime.parse('2026-07-27T12:00:00'),
        l10n: en,
        now: now,
      ),
      '1 day ago',
    );
    expect(
      formatRelativeTimeLabel(
        DateTime.parse('2026-07-25T12:00:00'),
        l10n: en,
        now: now,
      ),
      '3 days ago',
    );
  });

  test('未来时间归「刚刚」而不是负数', () {
    expect(
      formatRelativeTimeLabel(
        DateTime.parse('2026-07-28T12:30:00'),
        l10n: zh,
        now: now,
      ),
      '刚刚',
    );
  });

  test('边界：整 60 分钟进「小时」档、整 24 小时进「天」档', () {
    expect(
      formatRelativeTimeLabel(
        DateTime.parse('2026-07-28T11:00:00'),
        l10n: zh,
        now: now,
      ),
      '1 小时前',
    );
    expect(
      formatRelativeTimeLabel(
        DateTime.parse('2026-07-27T12:00:00'),
        l10n: zh,
        now: now,
      ),
      '1 天前',
    );
  });
}
