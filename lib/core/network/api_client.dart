import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sakuramedia/core/network/api_error_dto.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/auth_interceptor.dart';
import 'package:sakuramedia/core/network/sse_decoder.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/auth/data/auth_tokens_dto.dart';

class ApiClient {
  ApiClient({
    required SessionStore sessionStore,
    void Function()? onUnauthorized,
  }) : _sessionStore = sessionStore,
       _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 30),
           receiveTimeout: const Duration(seconds: 30),
           sendTimeout: const Duration(seconds: 30),
           responseType: ResponseType.json,
           contentType: Headers.jsonContentType,
         ),
       ),
       _refreshDio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 30),
           receiveTimeout: const Duration(seconds: 30),
           sendTimeout: const Duration(seconds: 30),
           responseType: ResponseType.json,
           contentType: Headers.jsonContentType,
         ),
       ) {
    _dio.interceptors.add(
      AuthInterceptor(
        dio: _dio,
        sessionStore: _sessionStore,
        refreshTokens: _refreshTokens,
        clearSession: _sessionStore.clearSession,
        onUnauthorized: onUnauthorized,
      ),
    );
  }

  final SessionStore _sessionStore;
  final Dio _dio;
  final Dio _refreshDio;

  Dio get rawDio => _dio;
  Dio get rawRefreshDio => _refreshDio;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    final response = await _request<Map<String, dynamic>>(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
    return _asJsonMap(response.data);
  }

  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    final response = await _request<List<dynamic>>(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
    return _asJsonList(response.data);
  }

  Future<List<dynamic>> getValueList(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    final response = await _request<List<dynamic>>(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
    return _asValueList(response.data);
  }

  Future<Uint8List> getBytes(
    String pathOrUrl, {
    bool requiresAuth = true,
  }) async {
    final response = await _request<List<int>>(
      method: 'GET',
      path: pathOrUrl,
      requiresAuth: requiresAuth,
      responseType: ResponseType.bytes,
    );
    return _asBytes(response.data);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    final response = await _request<Map<String, dynamic>>(
      method: 'POST',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
    return _asJsonMap(response.data);
  }

  Stream<ApiSseEvent> postSse(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async* {
    yield* _sseRequest(
      method: 'POST',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Stream<ApiSseEvent> getSse(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async* {
    yield* _sseRequest(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    final response = await _request<Map<String, dynamic>>(
      method: 'PATCH',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
    return _asJsonMap(response.data);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    final response = await _request<Map<String, dynamic>>(
      method: 'PUT',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
    return _asJsonMap(response.data);
  }

  Future<void> postNoContent(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    await _request<void>(
      method: 'POST',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<void> putNoContent(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    await _request<void>(
      method: 'PUT',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    final response = await _request<Map<String, dynamic>>(
      method: 'DELETE',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
    return _asJsonMap(response.data);
  }

  Future<void> deleteNoContent(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    await _request<void>(
      method: 'DELETE',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<Response<T>> _request<T>({
    required String method,
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    ResponseType? responseType,
    Duration? receiveTimeout,
    Map<String, dynamic>? headers,
    bool Function(int?)? validateStatus,
  }) async {
    try {
      return await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          responseType: responseType,
          receiveTimeout: receiveTimeout,
          headers: headers,
          validateStatus: validateStatus,
          extra: <String, dynamic>{'requiresAuth': requiresAuth},
        ),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Stream<ApiSseEvent> _sseRequest({
    required String method,
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async* {
    final response = await _request<ResponseBody>(
      method: method,
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      responseType: ResponseType.stream,
      receiveTimeout: const Duration(minutes: 1),
      headers: const <String, dynamic>{
        Headers.acceptHeader: 'text/event-stream',
      },
      validateStatus: (_) => true,
    );

    final responseBody = response.data;
    if (responseBody is! ResponseBody) {
      throw const ApiException(
        message:
            'Expected event stream response but got unsupported data shape',
      );
    }

    final statusCode = response.statusCode ?? responseBody.statusCode;
    if (statusCode >= 400) {
      final bodyText = await _readResponseBody(responseBody);
      final parsedData = _decodeResponseData(bodyText);
      final errorPayload = _extractError(parsedData);
      throw ApiException(
        statusCode: statusCode,
        message: errorPayload?.message ?? 'Request failed',
        error: errorPayload,
      );
    }

    yield* responseBody.stream.transform(const SseDecoder());
  }

  Future<void> _refreshTokens() async {
    if (_sessionStore.baseUrl.isEmpty || _sessionStore.refreshToken.isEmpty) {
      throw ApiException.unauthorized(
        code: 'invalid_refresh_token',
        message: 'Refresh token invalid or expired',
      );
    }

    _refreshDio.options.baseUrl = _sessionStore.baseUrl;

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/token-refreshes',
        data: <String, dynamic>{'refresh_token': _sessionStore.refreshToken},
        options: Options(
          headers: <String, dynamic>{
            if (_sessionStore.accessToken.isNotEmpty)
              'Authorization': 'Bearer ${_sessionStore.accessToken}',
          },
        ),
      );
      final tokens = AuthTokensDto.fromJson(_asJsonMap(response.data));
      await _sessionStore.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt: tokens.expiresAt,
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  ApiException _mapDioException(DioException error) {
    if (error.error is ApiException) {
      return error.error! as ApiException;
    }

    final statusCode = error.response?.statusCode;
    final parsedData = _decodeResponseData(error.response?.data);
    final errorPayload = _extractError(parsedData);

    return ApiException(
      statusCode: statusCode,
      message: errorPayload?.message ?? error.message ?? 'Request failed',
      error: errorPayload,
    );
  }

  Map<String, dynamic> _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    }
    throw const ApiException(
      message: 'Expected JSON object response but got unsupported data shape',
    );
  }

  List<Map<String, dynamic>> _asJsonList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Object?>()
          .map((item) => _asJsonMap(item))
          .toList(growable: false);
    }
    throw const ApiException(
      message: 'Expected JSON array response but got unsupported data shape',
    );
  }

  List<dynamic> _asValueList(dynamic data) {
    if (data is List) {
      return List<dynamic>.from(data, growable: false);
    }
    throw const ApiException(
      message: 'Expected JSON array response but got unsupported data shape',
    );
  }

  Uint8List _asBytes(dynamic data) {
    if (data is Uint8List) {
      return data;
    }
    if (data is List<int>) {
      return Uint8List.fromList(data);
    }
    throw const ApiException(
      message: 'Expected byte response but got unsupported data shape',
    );
  }

  dynamic _decodeResponseData(dynamic data) {
    if (data is Uint8List) {
      return _decodeResponseData(utf8.decode(data));
    }
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return null;
      }
    }
    return data;
  }

  Future<String> _readResponseBody(ResponseBody responseBody) async {
    final bytes = <int>[];
    await for (final chunk in responseBody.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  ApiErrorDto? _extractError(dynamic data) {
    if (data is! Map) {
      return null;
    }
    final dynamic errorObject = data['error'];
    if (errorObject is! Map) {
      return null;
    }
    return ApiErrorDto.fromJson(
      errorObject.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
  }

  void dispose() {
    _dio.close(force: true);
    _refreshDio.close(force: true);
  }
}
