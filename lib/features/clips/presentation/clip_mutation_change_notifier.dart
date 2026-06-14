import 'package:flutter/foundation.dart';

/// 切片跨页变更的类别。
enum ClipMutationKind {
  /// 切片被删除（连同文件，影响「全部切片」网格与其所在合集的封面 / 计数）。
  deleted,

  /// 切片所在合集的可见信息发生变化（加入 / 移出 / 拖序 / 改名，
  /// 影响合集卡的封面、计数与名称）。
  collectionMembershipChanged,
}

/// 一次切片变更事件的载荷。
class ClipMutationChange {
  const ClipMutationChange({
    required this.kind,
    this.clipId,
    this.collectionId,
  });

  final ClipMutationKind kind;

  /// 涉及的切片 id；[ClipMutationKind.deleted] 时必有，合集类变更可能为空
  /// （如拖序 / 改名 / 批量加入，并非针对单个切片）。
  final int? clipId;

  /// 涉及的合集 id；仅 [ClipMutationKind.collectionMembershipChanged] 时可能有意义。
  final int? collectionId;
}

/// 切片变更的全局广播器：与 videos 的 [VideoMutationChangeNotifier] 同构。
///
/// 发起方在某页改完切片后 `reportXxx(...)`，其它持有缓存副本的页面监听后读
/// [lastChange] 做就地补丁（如把该切片从网格移除）或重拉合集列表，避免跨页 stale。
///
/// 与 videos 不同的是，切片合集详情还支持拖序与改名，这些同样会改变合集卡的
/// 封面 / 名称，故统一归入 [ClipMutationKind.collectionMembershipChanged]，
/// 由监听方重拉合集列表校准。
class ClipMutationChangeNotifier extends ChangeNotifier {
  ClipMutationChange? _lastChange;
  ClipMutationChange? get lastChange => _lastChange;

  void reportDeleted(int clipId) {
    _lastChange = ClipMutationChange(
      kind: ClipMutationKind.deleted,
      clipId: clipId,
    );
    notifyListeners();
  }

  void reportCollectionMembershipChanged({int? clipId, int? collectionId}) {
    _lastChange = ClipMutationChange(
      kind: ClipMutationKind.collectionMembershipChanged,
      clipId: clipId,
      collectionId: collectionId,
    );
    notifyListeners();
  }
}
