import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_market_dto.dart';

import '../support/plugin_market_test_data.dart';

void main() {
  group('PluginMarketItemDisplay', () {
    test('resolves the display name and description in the current language', () {
      final item = PluginMarketItemDto.fromJson(
        pluginMarketItemJson(
          displayName: '演示插件',
          displayNameI18n: <String, String>{
            'zh-CN': '演示插件',
            'en': 'Demo Plugin',
          },
          descriptionI18n: <String, String>{
            'zh-CN': '演示插件的用途说明',
            'en': 'What the demo plugin does',
          },
        ),
      );

      expect(item.localizedDisplayName(AppLanguage.en), 'Demo Plugin');
      expect(item.localizedDisplayName(AppLanguage.zhCN), '演示插件');
      expect(
        item.localizedDescription(AppLanguage.en),
        'What the demo plugin does',
      );
      expect(item.localizedDescription(AppLanguage.zhCN), '演示插件的用途说明');
    });

    test('falls back to the source text without translations', () {
      final item = PluginMarketItemDto.fromJson(pluginMarketItemJson());

      expect(item.localizedDisplayName(AppLanguage.en), '演示插件');
      expect(item.localizedDescription(AppLanguage.en), '演示插件的用途说明');
    });

    test('exposes every language variant for search', () {
      final item = PluginMarketItemDto.fromJson(
        pluginMarketItemJson(
          displayNameI18n: <String, String>{
            'zh-CN': '演示插件',
            'en': 'Demo Plugin',
          },
          descriptionI18n: <String, String>{
            'zh-CN': '演示插件的用途说明',
            'en': 'What the demo plugin does',
          },
        ),
      );

      expect(
        item.searchTexts,
        containsAll(<String>[
          '演示插件',
          'Demo Plugin',
          '演示插件的用途说明',
          'What the demo plugin does',
        ]),
      );
    });
  });
}
