import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/auth/data/auth_tokens_dto.dart';

class AuthApi {
  const AuthApi({
    required ApiClient apiClient,
    required SessionStore sessionStore,
  }) : _apiClient = apiClient,
       _sessionStore = sessionStore;

  final ApiClient _apiClient;
  final SessionStore _sessionStore;

  Future<AuthTokensDto> createToken({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/tokens',
      requiresAuth: false,
      data: <String, dynamic>{'username': username, 'password': password},
    );
    final dto = AuthTokensDto.fromJson(response);
    await _sessionStore.saveTokens(
      accessToken: dto.accessToken,
      refreshToken: dto.refreshToken,
      expiresAt: dto.expiresAt,
    );
    return dto;
  }

  Future<AuthTokensDto> refreshToken(String refreshToken) async {
    final response = await _apiClient.post(
      '/auth/token-refreshes',
      data: <String, dynamic>{'refresh_token': refreshToken},
    );
    final dto = AuthTokensDto.fromJson(response);
    await _sessionStore.saveTokens(
      accessToken: dto.accessToken,
      refreshToken: dto.refreshToken,
      expiresAt: dto.expiresAt,
    );
    return dto;
  }

  Future<AuthTokensDto> login({
    required String username,
    required String password,
  }) {
    return createToken(username: username, password: password);
  }

  Future<AuthTokensDto> refresh(String token) {
    return refreshToken(token);
  }
}
