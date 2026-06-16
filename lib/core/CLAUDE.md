# lib/core/ — 基础能力层

统一 HTTP 客户端(含 token 自动刷新与 SSE)、会话/凭据持久化、媒体 URL 拼接与图片保存、宽松 JSON 解析、格式化。对所有 `features/*` 暴露 `ApiClient`、`SessionStore` 及一批纯函数工具。

## network/ — ApiClient 与 token 刷新

**`ApiClient`** 是所有 feature API 的**唯一 HTTP 入口**(`features/*/data/*_api.dart` 构造注入它)。动词方法:`get/post/put/patch` + `getList`/`getValueList`(非分页列表)+ `putNoContent`/`deleteNoContent`/`postNoContent` + `getBytes`(字幕/图片字节)+ `getSse`/`postSse`(流式)。

- **`requiresAuth`** 经 `Options.extra` 透传给拦截器,默认 `true`;登录/刷新端点传 `false`。
- **baseUrl 来自 `SessionStore`**(拦截器 `onRequest` 每次动态写 `options.baseUrl`),切后端无需重建 Dio。
- 分页响应统一 `PaginatedResponseDto<T>.fromJson(resp, Dto.fromJson)`,含 `synced_at`(整批抓取时间)。

### token 刷新是三处联动,改任一处看全部

1. **`AuthInterceptor`**(`auth_interceptor.dart`):触发 + 单飞 + 重试。`_refreshingFuture` 单飞——并发 401 共享同一刷新 future。**不触发刷新的情况**:非 401、错误码 `invalid_credentials`、`requiresAuth=false`、已重试过(`retried_after_refresh` 标记)、路径以 `/auth/tokens` 或 `/auth/token-refreshes` 结尾、refreshToken 为空。刷新失败 → `clearSession()` + `onUnauthorized` 回调 + 抛 401 `invalid_refresh_token`。
2. **`ApiClient._refreshTokens`**:实际刷新,用**独立的 `_refreshDio`(无拦截器)**手动带旧 token 打 `/auth/token-refreshes`,避免递归;成功 `saveTokens`。
3. **`SessionStore.saveTokens / clearSession`**:落地。

> 端点路径常量在拦截器里**硬编码字符串后缀**;改后端路由要同步 `_shouldAttemptRefresh`。`AuthApi.refreshToken`(主动调用)与 `ApiClient._refreshTokens`(拦截器内)是两条刷新路径。

### SSE

- 单独走 `validateStatus:(_)=>true` + 流式,`receiveTimeout` 放宽到 1 分钟;≥400 时先 drain body 再抛 `ApiException`(**不走 `_mapDioException`**)。
- `sse_decoder.dart` 按 `\n\n` 分帧、解析 `id:`/`event:`/`data:`,多行 data 用 `\n` join,默认 event 名 `message`。`api_sse_event.dart` 的 `jsonData` 空 data 返回空 map、非法 JSON 抛异常。
- **Web 平台 dio 不支持流式**:活动域的 SSE 用条件导入在 Web 走 `fetch`+`ReadableStream`(见 `features/activity`)。

### 异常与文案

传输失败分类(`_mapDioException`):无 response→connection、各 timeout→timeout,生成**中文用户文案**(`api_error_message.dart`,内置 baseUrl)。`error.error is ApiException` 时优先透传。判错误码用 `ApiException.code`。

## session/ — 会话与凭据(两套存储,分工明确)

- **`SessionStore`**(`ChangeNotifier`):baseUrl / accessToken / refreshToken / expiresAt,落 `shared_preferences`(键前缀 `session.*`)。`hasSession` 驱动 GoRouter 重定向。**expiresAt 一律存 UTC**;`saveBaseUrl('')` 会 `remove` 而非存空。可插拔后端(真实 / 内存,测试用)。
- **`CredentialStore`**:明文账密,落 `flutter_secure_storage`,**仅用于登录页预填**,失败静默不阻断。
- 登出统一走 `BuildContext.logOut()` = `clearSession()`(触发跳登录)+ `clearCredentials()`。

## media/ · json/ · format/

- **`media_url_resolver.dart`** `resolveMediaUrl(raw, baseUrl)`:空→null;已有 scheme 直接返回;否则去尾/头 `/` 再拼;baseUrl 空→null。**所有远程图/直链都经此**。
- **`image_save_service.dart`**:跨平台保存(桌面文件选择器 / 移动相册 / Web 下载),全依赖可注入;移动按 iOS/Android 分别请求权限;字节源通常是 `ApiClient.getBytes`。
- **`json/json_parse.dart`**:`asInt`/`asIntOrNull`/`asDoubleOrNull`/`asDateTime`/`asStringOrNull`/`asMap`/`asMapOrNull`,容忍后端类型漂移(键 `toString`、数字串宽松转、空串当 null)。**新 DTO 一律复用这些,不自写私有解析。**
- **`format/`**:`formatFileSize` / `formatMediaTimecode` / `formatMediaDurationLabel` / `formatSyncedAtLabel` / `composeTotalWithSyncedAt`。

## 编辑前必须知道的坑

- **core 反向依赖 features**:`ApiClient` import 了 `features/auth/data/auth_tokens_dto.dart` 解析刷新响应——改 `AuthTokensDto` 会波及 token 刷新。
- 改 token 刷新逻辑务必三处一起看(见上)。
- SSE 错误不走 Dio 异常通道,别指望 `_mapDioException` 处理。
- 桌面窗口 `minimumSize == size`(在 `lib/app/`),非本层但相关。

## 与测试的关系

`test/core/network/`(`api_client_bytes_test` / `api_client_sse_test` / `api_client_transport_error_test` / `auth_interceptor_test` / `api_error_message_test`)、`test/core/session/session_store_test`、`test/core/media/`(`media_url_resolver_test` / `image_save_service_test`)。
**注意**:`format/`、`json/`、`credential_store`、`paginated_response_dto`、`sse_decoder` 当前缺直接单测,改它们没有回归网,建议补测试。
