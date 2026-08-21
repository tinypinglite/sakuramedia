import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';

/// 「会话级常驻列表」(`@Riverpod(keepAlive: true)`) 的登出失效样板。
///
/// keepAlive 的列表状态不随页面卸载释放,不处理登出边沿的话,换账号登录后新
/// 会话会读到上一账号的数据（`lib/features/AGENTS.md`「状态与数据」
/// 对这一轨的硬性要求）。导航级保活列表不需要它——那一轨由
/// `RiverpodPageCache` 在登出边沿统一 `clearAll`。
///
/// 用法:在 `build()` **首行**调一次（`ref.watch` 不能跨 await,异步 build 里
/// 尤其注意顺序）:
///
/// ```dart
/// @override
/// Future<XxxState> build() async {
///   invalidateOnSignOut(ref);
///   attachDisposeGuard();
///   ...
/// }
/// ```
///
/// 语义:登出边沿（`hasSession` true→false）触发 `invalidateSelf()`——此时页面
/// 已被路由踢回登录页、通常没有监听者,provider 直接释放（SSE / Timer 等走各自
/// `onDispose` 收尾）;若仍有监听者则立即重建,拉到的也是新会话的数据。两条路径
/// 都不会把旧账号的数据留在内存里。
void invalidateOnSignOut(Ref ref) {
  final sessionStore = ref.watch(sessionStoreProvider);
  var lastHasSession = sessionStore.hasSession;

  void handleSessionChanged() {
    final hasSession = sessionStore.hasSession;
    if (hasSession == lastHasSession) return;
    lastHasSession = hasSession;
    if (!hasSession) {
      ref.invalidateSelf();
    }
  }

  sessionStore.addListener(handleSessionChanged);
  ref.onDispose(() => sessionStore.removeListener(handleSessionChanged));
}
