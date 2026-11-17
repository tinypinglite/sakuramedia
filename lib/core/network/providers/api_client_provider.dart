import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';

part 'api_client_provider.g.dart';

/// 全局 [ApiClient] 的 Riverpod 入口。
///
/// 原生装配：依赖（[SessionStore]）经 `ref.watch` 拉取，组合根不再 override。
/// 语言头用回调在每次请求时读取，避免切语言重建 client、中断 SSE/在飞请求。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  final client = ApiClient(
    sessionStore: ref.watch(sessionStoreProvider),
    languageProvider: () => ref.read(appLanguageControllerProvider).apiTag,
    localizationsProvider: () => ref.read(appLocalizationsProvider),
  );
  ref.onDispose(client.dispose);
  return client;
}
