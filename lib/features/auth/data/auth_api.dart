import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/credential_store.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/auth/data/auth_tokens_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

class AuthApi {
  const AuthApi({
    required ApiClient apiClient,
    required SessionStore sessionStore,
    required CredentialStore credentialStore,
    AppLocalizations Function()? l10n,
  }) : _apiClient = apiClient,
       _sessionStore = sessionStore,
       _credentialStore = credentialStore,
       _l10n = l10n;

  final ApiClient _apiClient;
  final SessionStore _sessionStore;
  final CredentialStore _credentialStore;
  final AppLocalizations Function()? _l10n;

  AppLocalizations get _localizations => _l10n?.call() ?? AppLocalizationsZh();

  Future<AuthTokensDto> createToken({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/tokens',
      requiresAuth: false,
      data: <String, dynamic>{'username': username, 'password': password},
    );
    final dto = AuthTokensDto.fromJson(response, l10n: _localizations);
    await _sessionStore.saveTokens(
      accessToken: dto.accessToken,
      refreshToken: dto.refreshToken,
      expiresAt: dto.expiresAt,
    );
    await _credentialStore.saveCredentials(
      username: username,
      password: password,
    );
    return dto;
  }

  Future<AuthTokensDto> login({
    required String username,
    required String password,
  }) {
    return createToken(username: username, password: password);
  }
}
