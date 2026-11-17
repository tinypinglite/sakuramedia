import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/app/language/language_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('in-memory store starts empty and persists a language', () async {
    final store = InMemoryLanguageStore();

    expect(store.read(), isNull);
    await store.save(AppLanguage.en);
    expect(store.read(), AppLanguage.en);
  });

  test('shared preferences store persists and reads zh-CN/en', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesLanguageStore(preferences);

    expect(store.read(), isNull);
    await store.save(AppLanguage.en);
    expect(
      preferences.getString(SharedPreferencesLanguageStore.languageKey),
      'en',
    );
    expect(store.read(), AppLanguage.en);

    await store.save(AppLanguage.zhCN);
    expect(store.read(), AppLanguage.zhCN);
  });
}
