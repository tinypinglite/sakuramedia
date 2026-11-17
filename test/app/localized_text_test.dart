import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/app/language/localized_text.dart';

void main() {
  group('resolveLocalizedText', () {
    test('uses the text of the current language', () {
      expect(
        resolveLocalizedText(
          translations: <String, String>{'zh-CN': '演示', 'en': 'Demo'},
          fallback: '原文',
          language: AppLanguage.en,
        ),
        'Demo',
      );
    });

    test('falls back to zh-CN when the current language is missing', () {
      expect(
        resolveLocalizedText(
          translations: <String, String>{'zh-CN': '演示', 'en': 'Demo'},
          fallback: '原文',
          language: AppLanguage.zhCN,
        ),
        '演示',
      );
    });

    test('falls back to the source text when no translation matches', () {
      expect(
        resolveLocalizedText(
          translations: <String, String>{'en': 'Demo'},
          fallback: '原文',
          language: AppLanguage.zhCN,
        ),
        '原文',
      );
    });

    test('treats an empty translation as missing', () {
      expect(
        resolveLocalizedText(
          translations: <String, String>{'zh-CN': '', 'en': '  '},
          fallback: '原文',
          language: AppLanguage.en,
        ),
        '原文',
      );
    });

    test('returns the source text when there is no translation at all', () {
      expect(
        resolveLocalizedText(
          translations: const <String, String>{},
          fallback: '原文',
          language: AppLanguage.en,
        ),
        '原文',
      );
    });
  });
}
