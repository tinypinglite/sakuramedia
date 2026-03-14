import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required SessionStore sessionStore,
    required Future<void> Function() refreshTokens,
    required Future<void> Function() clearSession,
    void Function()? onUnauthorized,
  }) : _dio = dio,
       _sessionStore = sessionStore,
       _refreshTokens = refreshTokens,
       _clearSession = clearSession,
       _onUnauthorized = onUnauthorized;

  final Dio _dio;
  final SessionStore _sessionStore;
  final Future<void> Function() _refreshTokens;
  final Future<void> Function() _clearSession;
  final void Function()? _onUnauthorized;

  Future<void>? _refreshingFuture;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final baseUrl = _sessionStore.baseUrl;
    if (baseUrl.isNotEmpty) {
      options.baseUrl = baseUrl;
    }

    final requiresAuth = options.extra['requiresAuth'] != false;
    if (requiresAuth && _sessionStore.accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${_sessionStore.accessToken}';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldAttemptRefresh(err)) {
      handler.next(err);
      return;
    }

    try {
      await _refreshTokensSerially();

      final retriedRequest = err.requestOptions.copyWith(
        headers: Map<String, dynamic>.from(err.requestOptions.headers)
          ..['Authorization'] = 'Bearer ${_sessionStore.accessToken}',
        extra: Map<String, dynamic>.from(err.requestOptions.extra)
          ..['retried_after_refresh'] = true,
      );
      final response = await _dio.fetch<dynamic>(retriedRequest);
      handler.resolve(response);
    } catch (_) {
      await _clearSession();
      _onUnauthorized?.call();
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: Response<dynamic>(
            requestOptions: err.requestOptions,
            statusCode: 401,
            data: <String, dynamic>{
              'error': <String, dynamic>{
                'code': 'invalid_refresh_token',
                'message': 'Refresh token invalid or expired',
              },
            },
          ),
          type: DioExceptionType.badResponse,
          error: ApiException.unauthorized(
            code: 'invalid_refresh_token',
            message: 'Refresh token invalid or expired',
          ),
        ),
      );
    }
  }

  bool _shouldAttemptRefresh(DioException err) {
    final statusCode = err.response?.statusCode;
    if (statusCode != 401) {
      return false;
    }

    if (_extractErrorCode(err.response?.data) == 'invalid_credentials') {
      return false;
    }

    final request = err.requestOptions;
    final requiresAuth = request.extra['requiresAuth'] != false;
    final retried = request.extra['retried_after_refresh'] == true;
    final isTokenEndpoint = request.path.endsWith('/auth/tokens');
    final isRefreshEndpoint = request.path.endsWith('/auth/token-refreshes');

    return requiresAuth &&
        !retried &&
        !isTokenEndpoint &&
        !isRefreshEndpoint &&
        _sessionStore.refreshToken.isNotEmpty;
  }

  String? _extractErrorCode(dynamic data) {
    final decoded = switch (data) {
      String() => _tryDecodeJson(data),
      _ => data,
    };
    if (decoded is! Map) {
      return null;
    }
    final error = decoded['error'];
    if (error is! Map) {
      return null;
    }
    return error['code'] as String?;
  }

  dynamic _tryDecodeJson(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  Future<void> _refreshTokensSerially() {
    final inFlight = _refreshingFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final completer = Completer<void>();
    _refreshingFuture = completer.future;

    () async {
      try {
        await _refreshTokens();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _refreshingFuture = null;
      }
    }();

    return completer.future;
  }
}
