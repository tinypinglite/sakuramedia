import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/app/language/app_language.dart';

/// 界面语言偏好存储；生产使用 SharedPreferences，测试/预览使用内存实现。
abstract class AppLanguageStore {
  AppLanguage? read();
  Future<void> save(AppLanguage language);
}

class SharedPreferencesLanguageStore implements AppLanguageStore {
  SharedPreferencesLanguageStore(this._preferences);

  static const String languageKey = 'app.language';

  final SharedPreferences _preferences;

  static Future<AppLanguageStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesLanguageStore(preferences);
  }

  @override
  AppLanguage? read() {
    return AppLanguage.tryFromTag(_preferences.getString(languageKey));
  }

  @override
  Future<void> save(AppLanguage language) async {
    try {
      await _preferences.setString(languageKey, language.apiTag);
    } catch (_) {
      // 持久化失败不阻塞切换；下次启动回退默认语言。
    }
  }
}

class InMemoryLanguageStore implements AppLanguageStore {
  InMemoryLanguageStore([this._language]);

  AppLanguage? _language;

  @override
  AppLanguage? read() => _language;

  @override
  Future<void> save(AppLanguage language) async {
    _language = language;
  }
}
