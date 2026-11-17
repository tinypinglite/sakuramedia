import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/clips/presentation/controllers/clip_mutation_change.dart';

export 'package:sakuramedia/features/clips/presentation/controllers/clip_mutation_change.dart';

part 'clip_mutation_events_provider.g.dart';

/// 切片跨页变更广播 —— 与 `movieSubscriptionEventsProvider` 同范式：
/// 单一 provider 同时承载事件流与发布 API。
///
/// **消费方**：`ref.listen(clipMutationEventsProvider, (prev, next) {
/// final change = next.value; if (change != null) ...; })`；就地补丁，不整页重拉。
///
/// **发起方**：`ref.read(clipMutationEventsProvider.notifier).reportDeleted(...)`
/// 或 `reportCollectionMembershipChanged(...)`。
///
/// 与 videos 的 [videoMutationEventsProvider] 同构；由于切片合集详情还支持拖序与
/// 改名，这些同样归入 [ClipMutationKind.collectionMembershipChanged]，由监听方
/// 重拉合集列表校准。
@Riverpod(keepAlive: true)
class ClipMutationEvents extends _$ClipMutationEvents {
  final StreamController<ClipMutationChange> _controller =
      StreamController<ClipMutationChange>.broadcast(sync: true);

  @override
  Stream<ClipMutationChange> build() {
    ref.onDispose(_controller.close);
    return _controller.stream;
  }

  /// 直接暴露底层 broadcast stream；非 Riverpod 上下文（如手工控制器 / 测试）
  /// 需要 `listen` 时用它，Riverpod widget 侧走 `ref.listen(provider, ...)`。
  Stream<ClipMutationChange> get stream => _controller.stream;

  void reportDeleted(int clipId) {
    if (_controller.isClosed) return;
    _controller.add(
      ClipMutationChange(kind: ClipMutationKind.deleted, clipId: clipId),
    );
  }

  void reportCollectionMembershipChanged({int? clipId, int? collectionId}) {
    if (_controller.isClosed) return;
    _controller.add(
      ClipMutationChange(
        kind: ClipMutationKind.collectionMembershipChanged,
        clipId: clipId,
        collectionId: collectionId,
      ),
    );
  }
}
