import 'package:intl/intl.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

/// 系统概览的纯展示格式化与状态口径（不依赖状态对象，输入即 DTO）。

final _countFormatter = NumberFormat.decimalPattern();
final _percentFormatter = NumberFormat.decimalPercentPattern(decimalDigits: 1);

/// 千分位计数：`1286` → `1,286`。
String formatCount(int value) => _countFormatter.format(value);

/// 比例格式化：`0.049` → `4.9%`，跟随当前语言的小数符号。
String formatPercent(double value) => _percentFormatter.format(value);

/// 订阅率；分母为 0 时显示 `0.0%`。
String formatSubscriptionRate(int subscribed, int total) {
  if (total <= 0) {
    return formatPercent(0);
  }
  return formatPercent(subscribed / total);
}

/// 单个媒体库的容量拆分：SakuraMedia 占用 / 其他占用 / 空闲。
class StorageUsageBreakdown {
  const StorageUsageBreakdown({
    required this.sakuraBytes,
    required this.otherBytes,
    required this.freeBytes,
  });

  final int sakuraBytes;
  final int otherBytes;
  final int freeBytes;
}

/// provider 容量可用时拆分三段；总量或已用量缺失、总量无效时返回 null，
/// 由调用方退回旧展示。
///
/// `totalSizeBytes` 可能超过存储端已用量（账号级数据滞后等），按已用量收口，
/// 空闲取「总量 − 已用」，保证三段之和恒等于总量、长条不溢出。
StorageUsageBreakdown? storageUsageBreakdown(MediaLibraryUsageDto library) {
  final totalBytes = library.spaceTotalBytes;
  final usedBytes = library.spaceUsedBytes;
  if (totalBytes == null || totalBytes <= 0 || usedBytes == null) {
    return null;
  }
  final used = usedBytes.clamp(0, totalBytes).toInt();
  final sakuraBytes = library.totalSizeBytes.clamp(0, used).toInt();
  return StorageUsageBreakdown(
    sakuraBytes: sakuraBytes,
    otherBytes: used - sakuraBytes,
    freeBytes: totalBytes - used,
  );
}

/// 嵌入服务（JoyTag）连通性；未启用 / 探测失败各有单独文案。
String embeddingServiceHealthLabel(
  StatusImageSearchDto? status,
  AppLocalizations l10n,
) {
  if (status?.enabled == false) return l10n.systemMaintenanceDisabled;
  if (status == null) {
    return l10n.overviewStatusUnavailable;
  }
  return status.embeddingService.healthy
      ? l10n.overviewStatusHealthy
      : l10n.overviewStatusAbnormal;
}

AppTextTone embeddingServiceHealthTone(StatusImageSearchDto? status) {
  if (status == null || status.enabled == false) {
    return AppTextTone.muted;
  }
  return status.embeddingService.healthy
      ? AppTextTone.success
      : AppTextTone.error;
}

/// 待索引缩略图数；未启用或状态不可用时为 0（不展示积压项）。
int pendingIndexCount(StatusImageSearchDto? status) {
  if (status == null || status.enabled == false) {
    return 0;
  }
  return status.indexing.pendingThumbnails;
}

String imageSearchIndexSpaceLabel(
  StatusImageSearchDto? status,
  AppLocalizations l10n,
) {
  if (status?.enabled == false) return l10n.systemMaintenanceDisabled;
  if (status == null) {
    return l10n.overviewStatusUnavailable;
  }
  if (status.indexSpace.isRebuilding) {
    return l10n.systemMaintenanceRebuilding;
  }
  return switch (status.indexSpace.state) {
    'ready' => l10n.overviewIndexSpaceReady,
    'rebuild_required' => l10n.overviewIndexSpaceRebuildRequired,
    'uninitialized' => l10n.overviewIndexSpaceUninitialized,
    'unavailable' => l10n.overviewStatusUnavailable,
    _ => l10n.commonUnknown,
  };
}

/// 观看趋势时间窗口的完整描述（用于「近 30 天」这类句子）。
String watchTrendRangePeriodLabel(
  WatchTrendRange range,
  AppLocalizations l10n,
) {
  return switch (range) {
    WatchTrendRange.last7Days => l10n.overviewRangeLast7Days,
    WatchTrendRange.last30Days => l10n.overviewRangeLast30Days,
    WatchTrendRange.last90Days => l10n.overviewRangeLast90Days,
    WatchTrendRange.lastYear => l10n.overviewRangeLastYear,
    WatchTrendRange.all => l10n.overviewRangeAllTime,
  };
}

/// 观看趋势时间窗口的短标签（用于分段控件）。
String watchTrendRangeShortLabel(WatchTrendRange range, AppLocalizations l10n) {
  return switch (range) {
    WatchTrendRange.last7Days => l10n.overviewRangeLast7DaysShort,
    WatchTrendRange.last30Days => l10n.overviewRangeLast30DaysShort,
    WatchTrendRange.last90Days => l10n.overviewRangeLast90DaysShort,
    WatchTrendRange.lastYear => l10n.overviewRangeLastYearShort,
    WatchTrendRange.all => l10n.overviewRangeAllTimeShort,
  };
}

AppTextTone imageSearchIndexSpaceTone(StatusImageSearchDto? status) {
  if (status == null || status.enabled == false) {
    return AppTextTone.muted;
  }
  if (status.indexSpace.isRebuilding) {
    return AppTextTone.info;
  }
  return switch (status.indexSpace.state) {
    'ready' => AppTextTone.success,
    'rebuild_required' => AppTextTone.warning,
    _ => AppTextTone.muted,
  };
}
