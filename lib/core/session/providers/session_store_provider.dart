import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/session/session_store.dart';

part 'session_store_provider.g.dart';

/// 全局 [SessionStore] 的 Riverpod 入口。
///
/// 会话是应用输入：body 保持抛 [UnimplementedError]，实例由组合根
/// （`lib/app/app.dart`，main 传入持久化实例 / 测试传 inMemory）用
/// `overrideWithValue` 注入。
@Riverpod(keepAlive: true)
SessionStore sessionStore(Ref ref) {
  throw UnimplementedError('Override sessionStoreProvider at the app root');
}

/// 细粒度派生：当前会话的 baseUrl。
///
/// [SessionStore] 是 ChangeNotifier，`ref.watch(sessionStoreProvider)` 拿到的
/// 是稳定实例、变更不会自动传播——这里手动 addListener 并在值变化时
/// `invalidateSelf`，让只关心 baseUrl 的组件（masked_image 等）精准重建。
@Riverpod(keepAlive: true)
String baseUrl(Ref ref) {
  final store = ref.watch(sessionStoreProvider);
  final current = store.baseUrl;
  void onChanged() {
    if (store.baseUrl != current) {
      ref.invalidateSelf();
    }
  }

  store.addListener(onChanged);
  ref.onDispose(() => store.removeListener(onChanged));
  return current;
}
