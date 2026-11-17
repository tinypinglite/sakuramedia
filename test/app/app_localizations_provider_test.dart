import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/app/language/language_store.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/l10n/app_localizations_en.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  test('exposes the localization matching the current language', () async {
    final store = InMemoryLanguageStore(AppLanguage.zhCN);
    final container = ProviderContainer(
      overrides: [appLanguageStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(appLocalizationsProvider), isA<AppLocalizationsZh>());

    await container
        .read(appLanguageControllerProvider.notifier)
        .setLanguage(AppLanguage.en);

    expect(container.read(appLocalizationsProvider), isA<AppLocalizationsEn>());
  });
}
