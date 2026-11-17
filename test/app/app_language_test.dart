import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/language/app_language.dart';

void main() {
  test('tryFromTag normalizes supported aliases', () {
    expect(AppLanguage.tryFromTag('zh-CN'), AppLanguage.zhCN);
    expect(AppLanguage.tryFromTag('zh_CN'), AppLanguage.zhCN);
    expect(AppLanguage.tryFromTag('zh-Hans'), AppLanguage.zhCN);
    expect(AppLanguage.tryFromTag('en-US'), AppLanguage.en);
    expect(AppLanguage.tryFromTag('EN-gb'), AppLanguage.en);
    expect(AppLanguage.tryFromTag('zh-TW'), isNull);
    expect(AppLanguage.tryFromTag('zh-Hant'), isNull);
    expect(AppLanguage.tryFromTag('fr'), isNull);
    expect(AppLanguage.tryFromTag(null), isNull);
  });

  test('maps backend tags to Flutter locales', () {
    expect(AppLanguage.zhCN.apiTag, 'zh-CN');
    expect(AppLanguage.zhCN.locale, const Locale('zh'));
    expect(AppLanguage.en.apiTag, 'en');
    expect(AppLanguage.en.locale, const Locale('en'));
  });
}
