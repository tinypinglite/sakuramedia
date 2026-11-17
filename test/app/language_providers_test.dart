import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/app/language/language_store.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';

void main() {
  test('defaults to zh-CN and persists explicit changes', () async {
    final store = InMemoryLanguageStore();
    final container = ProviderContainer(
      overrides: [appLanguageStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(appLanguageControllerProvider), AppLanguage.zhCN);

    await container
        .read(appLanguageControllerProvider.notifier)
        .setLanguage(AppLanguage.en);

    expect(container.read(appLanguageControllerProvider), AppLanguage.en);
    expect(store.read(), AppLanguage.en);
  });

  test('server language overrides local value and null keeps it', () async {
    final store = InMemoryLanguageStore(AppLanguage.en);
    final container = ProviderContainer(
      overrides: [appLanguageStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container
        .read(appLanguageControllerProvider.notifier)
        .applyServerLanguage('zh-CN');
    expect(container.read(appLanguageControllerProvider), AppLanguage.zhCN);

    await container
        .read(appLanguageControllerProvider.notifier)
        .applyServerLanguage(null);
    expect(container.read(appLanguageControllerProvider), AppLanguage.zhCN);
  });
}
