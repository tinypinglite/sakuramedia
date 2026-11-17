import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';

/// 会话/服务器级 provider 的统一失效样板。
///
/// keepAlive 的状态不随页面卸载释放,组合根的 `ProviderScope` 又在同一次运行
/// 内跨登录复用（`lib/app/app.dart` 的 key 绑 `SessionStore` 实例），所以
/// 账号级数据必须自行处理会话边沿:
///
/// - **登出**（`hasSession` true→false）:立即失效。页面此刻通常还挂着
///   （路由要到下一帧才跳登录页），失效会带出一次**无 token** 的重建请求；
///   这次重建只用于清理，不代表下一个会话。
/// - **重新登录 / 换服务器**（`hasSession` false→true，或已登录时 baseUrl
///   变化）:再次失效，用新 token 重取。漏掉这一半的话，登出瞬间缓存下来的
///   401 会一直留到进程结束，重新登录后页面仍是「请先登录」。
/// - 未登录时只改 baseUrl（登录页里编辑服务器地址）不失效:没有 token，
///   重建只会多打一次 401；登录边沿会统一处理。
///
/// 用法:在 `build()` **首行**调一次（`ref.watch` 不能跨 await,异步 build 里
/// 尤其注意顺序）:
///
/// ```dart
/// @override
/// Future<XxxState> build() async {
///   invalidateOnSessionChange(ref);
///   attachDisposeGuard();
///   ...
/// }
/// ```
void invalidateOnSessionChange(Ref ref) {
  final sessionStore = ref.watch(sessionStoreProvider);
  var lastIdentity = (sessionStore.baseUrl, sessionStore.hasSession);

  void handleSessionChanged() {
    final hasSession = sessionStore.hasSession;
    final identity = (sessionStore.baseUrl, hasSession);
    if (identity == lastIdentity) return;
    final previousHasSession = lastIdentity.$2;
    lastIdentity = identity;
    // 未登录时只改服务器地址:没有可用 token，重建只会多打一次 401。
    // 登录边沿（false→true）会再失效一次，用新会话重取。
    if (!previousHasSession && !hasSession) return;
    ref.invalidateSelf();
  }

  sessionStore.addListener(handleSessionChanged);
  ref.onDispose(() => sessionStore.removeListener(handleSessionChanged));
}
