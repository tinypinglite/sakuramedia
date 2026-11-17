import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/app/language/language_store.dart';

part 'language_providers.g.dart';

/// 语言偏好存储；生产在 `MyApp` 组合根注入 SharedPreferences 实现。
@Riverpod(keepAlive: true)
AppLanguageStore appLanguageStore(Ref ref) => InMemoryLanguageStore();

/// 当前界面语言。默认 zh-CN；登录成功后可用后端 user.language 覆盖。
@Riverpod(keepAlive: true)
class AppLanguageController extends _$AppLanguageController {
  @override
  AppLanguage build() {
    return ref.watch(appLanguageStoreProvider).read() ?? AppLanguage.zhCN;
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (state == language) {
      return;
    }
    state = language;
    await ref.read(appLanguageStoreProvider).save(language);
  }

  Future<void> applyServerLanguage(String? tag) async {
    final language = AppLanguage.tryFromTag(tag);
    if (language == null || state == language) {
      return;
    }
    state = language;
    await ref.read(appLanguageStoreProvider).save(language);
  }
}
