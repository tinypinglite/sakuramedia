import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';

/// 秒传状态 badge 映射：null / unknown 不显示；其余按后端语义配色。
///
/// - `in_progress` → info（当前批次未终态；同时行也被禁选）
/// - `cleanup_failed` → warning（云端已备份、本地待清理，重试仅做本地清理）
/// - `failed` → warning（其它可重试失败）
/// - `not_hit` → neutral（115 库无相同 sha1，重传大概率仍未命中）
///
/// 桌面媒体行与移动端媒体卡共用同一映射，保证双端信息一致。
AppBadge? rapidUploadStatusBadge(LastRapidUploadStatus? status) {
  if (status == null || status == LastRapidUploadStatus.unknown) {
    return null;
  }
  final tone = switch (status) {
    LastRapidUploadStatus.inProgress => AppBadgeTone.info,
    LastRapidUploadStatus.cleanupFailed => AppBadgeTone.warning,
    LastRapidUploadStatus.failed => AppBadgeTone.warning,
    LastRapidUploadStatus.notHit => AppBadgeTone.neutral,
    LastRapidUploadStatus.unknown => AppBadgeTone.neutral,
  };
  // 不加 key：与行内其它 badge 一致，tone/label 已足够做定位与视觉区分。
  return AppBadge(label: status.label, tone: tone, size: AppBadgeSize.compact);
}
