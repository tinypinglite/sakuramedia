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
@immutable
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
