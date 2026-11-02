import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sakuramedia/core/network/api_error_dto.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/auth_interceptor.dart';
import 'package:sakuramedia/core/network/debug_latency_interceptor.dart';
import 'package:sakuramedia/core/network/sse_decoder.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/core/session/session_token_payload.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class ApiClient {
  ApiClient({
    required SessionStore sessionStore,
    void Function()? onUnauthorized,
    String Function()? languageProvider,
    AppLocalizations Function()? localizationsProvider,
  }) : _sessionStore = sessionStore,
       _languageProvider = languageProvider,
       _localizationsProvider = localizationsProvider,
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
    _dio.interceptors.add(_languageInterceptor());
    _refreshDio.interceptors.add(_languageInterceptor());
    _dio.interceptors.add(
      AuthInterceptor(
        dio: _dio,
        sessionStore: _sessionStore,
        refreshTokens: _refreshTokens,
        clearSession: _sessionStore.clearSession,
        onUnauthorized: onUnauthorized,
      ),
    );
    final debugLatency = DebugLatencyInterceptor.fromEnvironment();
    if (debugLatency != null) {
      _dio.interceptors.add(debugLatency);
    }
  }

  final SessionStore _sessionStore;
  final String Function()? _languageProvider;
  final AppLocalizations Function()? _localizationsProvider;
  final Dio _dio;
  final Dio _refreshDio;

  InterceptorsWrapper _languageInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['Accept-Language'] = _currentLanguageTag();
        handler.next(options);
      },
    );
  }

  String _currentLanguageTag() {
    final tag = _languageProvider?.call().trim() ?? '';
    return tag.isEmpty ? 'zh-CN' : tag;
  }

  /// 当前语言的文案；未注入时返回 `null`，调用点回退英文文案。
  AppLocalizations? get _currentLocalizations => _localizationsProvider?.call();

  Dio get rawDio => _dio;
  Dio get rawRefreshDio => _refreshDio;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    final response = await _request<Map<String, dynamic>>(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
    );
    return _asJsonMap(response.data);
  }

  /// 请求文本响应，不按 JSON 解析（无论响应 `Content-Type`）。
  ///
  /// 用于 content-type 非 JSON 但内容是 JSON 的接口（如 GitHub raw
  /// 返回 `text/plain`）；调用方拿到原始字符串后自行解析。
  Future<String> getText(
    String pathOrUrl, {
    bool requiresAuth = true,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    final response = await _request<String>(
      method: 'GET',
      path: pathOrUrl,
      requiresAuth: requiresAuth,
      responseType: ResponseType.plain,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
    );
    return response.data ?? '';
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
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    Duration? receiveTimeout,
  }) async {
    final response = await _request<List<int>>(
      method: 'GET',
      path: pathOrUrl,
      requiresAuth: requiresAuth,
      queryParameters: queryParameters,
      responseType: ResponseType.bytes,
      headers: headers,
      receiveTimeout: receiveTimeout,
    );
    return _asBytes(response.data);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    Duration? receiveTimeout,
  }) async {
    final response = await _request<Map<String, dynamic>>(
      method: 'POST',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      receiveTimeout: receiveTimeout,
    );
    return _asJsonMap(response.data);
  }

  Stream<ApiSseEvent> postSse(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _sseRequest(
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
  }) {
    return _sseRequest(
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
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Map<String, dynamic>? headers,
    bool Function(int?)? validateStatus,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          responseType: responseType,
          connectTimeout: connectTimeout,
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

  /// SSE 请求包一层 [StreamController] 是为了把下游 `subscription.cancel()`
  /// 桥回 dio 的 [CancelToken] —— dio 的 `handleResponseStream` 只在
  /// `whenCancel` 分支同步取消 `receiveTimeout` 定时器，若直接 `yield*` 响应流，
  /// 下游取消不会传导到那个定时器，测试环境（`fake_async`）会因 1 分钟计时器
  /// 挂起而报 `!timersPending`。生产上真实 SSE 有心跳会 reset 定时器不会出问题，
  /// 但依赖这个巧合并不稳（网络断了就是纯挂）。
  Stream<ApiSseEvent> _sseRequest({
    required String method,
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    final cancelToken = CancelToken();
    late StreamController<ApiSseEvent> controller;
    var isStarting = false;

    Future<void> start() async {
      try {
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
          cancelToken: cancelToken,
        );
        if (controller.isClosed) return;

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

        responseBody.stream
            .transform(const SseDecoder())
            .listen(
              (event) {
                if (!controller.isClosed) controller.add(event);
              },
              onError: (Object error, StackTrace stackTrace) {
                // 主动取消触发的 DioException 是我们自己发起的（widget dispose），
                // dio 在 cancelToken.whenCancel 里会 `addErrorAndClose(cancelError)`——
                // 属于预期收尾，不透传给消费者，否则会变成 zone 未处理错误。
                if (_isCancellationError(error)) {
                  if (!controller.isClosed) controller.close();
                  return;
                }
                if (!controller.isClosed)
                  controller.addError(error, stackTrace);
              },
              onDone: () {
                if (!controller.isClosed) controller.close();
              },
            );
      } catch (error, stackTrace) {
        if (controller.isClosed) return;
        if (_isCancellationError(error)) {
          await controller.close();
          return;
        }
        controller.addError(error, stackTrace);
        await controller.close();
      }
    }

    controller = StreamController<ApiSseEvent>(
      onListen: () {
        if (isStarting) return;
        isStarting = true;
        unawaited(start());
      },
      onCancel: () {
        // 只取消 CancelToken，不主动 cancel 内部 subscription：
        // 1. dio 的 receiveTimeout 定时器**只**在 whenCancel 分支里同步取消；
        //    subscription.cancel 反向传导到 dio 是无效的（responseSink 没挂
        //    onCancel），所以 token 必须取消。
        // 2. 触发 whenCancel 后 dio 会 `addErrorAndClose(cancelError)` 关闭
        //    responseSink——我们的 subscription 会先在 onError 收到 cancelError
        //    （被 [_isCancellationError] 过滤），再在 onDone 里 close 外层
        //    controller，全流程自然收尾。如果这里主动 cancel subscription，
        //    这条错误会因下游没人监听变成 zone 未处理错误。
        if (!cancelToken.isCancelled) {
          cancelToken.cancel();
        }
      },
    );

    return controller.stream;
  }

  static bool _isCancellationError(Object error) {
    return error is DioException && error.type == DioExceptionType.cancel;
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
      final response = await _refreshDio.post<dynamic>(
        '/auth/token-refreshes',
        data: <String, dynamic>{'refresh_token': _sessionStore.refreshToken},
        options: Options(
          headers: <String, dynamic>{
            if (_sessionStore.accessToken.isNotEmpty)
              'Authorization': 'Bearer ${_sessionStore.accessToken}',
          },
        ),
      );
      final responseData = response.data;
      if (responseData is! Map) {
        throw SessionTokenPayload.invalidResponseException(
          l10n: _currentLocalizations,
        );
      }
      final tokens = SessionTokenPayload.fromJson(
        _asJsonMap(responseData),
        l10n: _currentLocalizations,
      );
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
    final transportFailureKind = _transportFailureKind(error);
    if (statusCode == null && transportFailureKind != null) {
      return ApiException(
        message: _transportFailureMessage(transportFailureKind),
        transportFailureKind: transportFailureKind,
        baseUrl: _requestTarget(error.requestOptions),
      );
    }
    final parsedData = _decodeResponseData(error.response?.data);
    final errorPayload = _extractError(parsedData);

    return ApiException(
      statusCode: statusCode,
      message: errorPayload?.message ?? error.message ?? 'Request failed',
      error: errorPayload,
    );
  }

  ApiTransportFailureKind? _transportFailureKind(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
        return ApiTransportFailureKind.connection;
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiTransportFailureKind.timeout;
      case DioExceptionType.unknown:
        // 只有真实网络栈异常才算连接失败；类型转换、解析等非网络异常
        // 不能误报为「无法连接」，否则会把排查方向带偏。
        if (error.response == null && error.error is SocketException) {
          return ApiTransportFailureKind.connection;
        }
        return null;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
        return null;
    }
  }

  String _transportFailureMessage(ApiTransportFailureKind kind) {
    return switch (kind) {
      ApiTransportFailureKind.connection => 'Connection failed',
      ApiTransportFailureKind.timeout => 'Request timed out',
    };
  }

  String? get _normalizedBaseUrl {
    final baseUrl = _sessionStore.baseUrl.trim();
    if (baseUrl.isEmpty) {
      return null;
    }
    return baseUrl;
  }

  /// 传输失败提示里展示的目标地址：取实际请求的 `scheme://host[:port]`。
  ///
  /// 直连外部服务（插件市场索引、GitHub Release）失败时不能显示会话里的
  /// 后端地址，否则会误导用户去排查后端。
  String? _requestTarget(RequestOptions options) {
    final uri = options.uri;
    if (uri.host.isEmpty) {
      return _normalizedBaseUrl;
    }
    try {
      return uri.origin;
    } on StateError {
      return _normalizedBaseUrl;
    }
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
