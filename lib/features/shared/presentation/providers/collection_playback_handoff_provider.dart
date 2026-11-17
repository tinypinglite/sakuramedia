import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';

part 'collection_playback_handoff_provider.g.dart';

/// 合集详情页 → 连播页的一次性成员交接信箱（原生 Riverpod 装配）。
///
/// offer/take-and-clear 的信箱语义保持不变：写读都发生在页面 initState /
/// 跳转前的命令式代码里（`ref.read`，从不 watch），不存在声明式重建下的
/// 双触发问题。keepAlive 对应旧 MultiProvider 的全局单例。
@Riverpod(keepAlive: true)
CollectionPlaybackHandoff collectionPlaybackHandoff(Ref ref) {
  return CollectionPlaybackHandoff();
}
