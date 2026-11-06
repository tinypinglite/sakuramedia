import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/core/format/file_size.dart' as legacy;

void main() {
  group('formatAppCount', () {
    test('zh/en 都使用千分位', () {
      expect(formatAppCount(1286, locale: 'en'), '1,286');
      expect(formatAppCount(1286, locale: 'zh'), '1,286');
      expect(formatAppCount(0, locale: 'en'), '0');
    });
  });

  group('formatAppCompactCount', () {
    test('en 使用 K/M 紧凑单位', () {
      expect(formatAppCompactCount(1286, locale: 'en'), '1.29K');
      expect(formatAppCompactCount(1200000, locale: 'en'), '1.2M');
    });

    test('zh 使用万/亿紧凑单位', () {
      expect(formatAppCompactCount(1286, locale: 'zh'), '1286');
      expect(formatAppCompactCount(12860, locale: 'zh'), '1.29万');
    });

    test('支持 num 小数', () {
      expect(formatAppCompactCount(1500.5, locale: 'en'), '1.5K');
    });
  });

  group('formatAppPercent', () {
    test('默认 1 位小数并跟随 locale', () {
      expect(formatAppPercent(0.049, locale: 'en'), '4.9%');
      expect(formatAppPercent(0.049, locale: 'zh'), '4.9%');
    });

    test('decimals 控制小数位', () {
      expect(formatAppPercent(0.5, decimals: 0, locale: 'en'), '50%');
      expect(formatAppPercent(0.049, decimals: 2, locale: 'en'), '4.90%');
    });
  });

  group('formatFileSize', () {
    test('空值与非法值回落到 0 B', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(-1), '0 B');
    });

    test('B 单位不带小数', () {
      expect(formatFileSize(1023), '1023 B');
    });

    test('默认 1 位小数并 trim 尾随 0', () {
      expect(formatFileSize(1024), '1 KB');
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(1024 * 1024), '1 MB');
      expect(formatFileSize(1024 * 1024 * 1024 * 1024), '1 TB');
    });

    test('maxDecimals 控制精度', () {
      expect(formatFileSize(1310720, maxDecimals: 2), '1.25 MB');
      expect(formatFileSize(1536, maxDecimals: 0), '2 KB');
    });

    test('可关闭 trim 保留固定小数位', () {
      expect(formatFileSize(1024, trimTrailingZeros: false), '1.0 KB');
    });

    test('file_size.dart 旧导入路径保持兼容', () {
      expect(legacy.formatFileSize(1536), formatFileSize(1536));
    });
  });
}
