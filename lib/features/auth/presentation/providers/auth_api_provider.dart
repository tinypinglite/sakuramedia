import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/providers/credential_store_provider.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';

part 'auth_api_provider.g.dart';

/// auth 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖（[ApiClient] / [SessionStore] / [CredentialStore]）经
/// `ref.watch` 拉取，组合根不再 override。测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
AuthApi authApi(Ref ref) {
  return AuthApi(
    apiClient: ref.watch(apiClientProvider),
    sessionStore: ref.watch(sessionStoreProvider),
    credentialStore: ref.watch(credentialStoreProvider),
    l10n: () => ref.read(appLocalizationsProvider),
  );
}
