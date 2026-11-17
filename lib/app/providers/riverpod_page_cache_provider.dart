import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';

part 'riverpod_page_cache_provider.g.dart';

/// 全局 [RiverpodPageCache] 的 Riverpod 入口。
///
/// 原生装配：构造即 `bindSessionStore`（登出自动全清）。cache 本身
/// keepAlive 常驻——它
/// 持有的只是「link 句柄」而非业务状态，业务 provider 的释放由 link close
/// 触发，cache 常驻不会泄漏任何列表数据。
@Riverpod(keepAlive: true)
RiverpodPageCache riverpodPageCache(Ref ref) {
  final cache =
      RiverpodPageCache()..bindSessionStore(ref.watch(sessionStoreProvider));
  ref.onDispose(cache.dispose);
  return cache;
}
