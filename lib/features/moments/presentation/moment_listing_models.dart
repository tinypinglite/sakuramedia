import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// moments 列表的值类型集合(原与 `PagedMomentController` 同文件,控制器迁
/// Riverpod 后独立成文件):排序/内容类型枚举、筛选值对象、列表项 ViewModel。
/// `MomentListItem` 被 discovery 域与 `widgets/domain/moments/` 复用。

enum MomentSortOrder {
  latest(apiValue: 'created_at:desc'),
  earliest(apiValue: 'created_at:asc');

  const MomentSortOrder({required this.apiValue});

  final String apiValue;

  String label(AppLocalizations l10n) => switch (this) {
    MomentSortOrder.latest => l10n.momentSortLatest,
    MomentSortOrder.earliest => l10n.momentSortEarliest,
  };
}

enum MomentKindFilter {
  jav(apiValue: 'jav'),
  video(apiValue: 'video');

  const MomentKindFilter({required this.apiValue});

  final String apiValue;

  /// `JAV` 是内容类型代号，中英文一致，不进语言包。
  String label(AppLocalizations l10n) => switch (this) {
    MomentKindFilter.jav => 'JAV',
    MomentKindFilter.video => l10n.momentKindVideo,
  };
}

/// 时刻列表筛选值对象:`==` 即「筛选未变」,驱动
/// `FilterablePagedAsyncNotifierMixin.applyFilterState` 的短路语义。
@immutable
class MomentsFilter {
  const MomentsFilter({
    this.sortOrder = MomentSortOrder.latest,
    this.kindFilter = MomentKindFilter.jav,
  });

  static const MomentsFilter initial = MomentsFilter();

  final MomentSortOrder sortOrder;
  final MomentKindFilter kindFilter;

  MomentsFilter copyWith({
    MomentSortOrder? sortOrder,
    MomentKindFilter? kindFilter,
  }) {
    return MomentsFilter(
      sortOrder: sortOrder ?? this.sortOrder,
      kindFilter: kindFilter ?? this.kindFilter,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MomentsFilter &&
        other.sortOrder == sortOrder &&
        other.kindFilter == kindFilter;
  }

  @override
  int get hashCode => Object.hash(sortOrder, kindFilter);
}

class MomentListItem {
  const MomentListItem({
    required this.pointId,
    required this.mediaId,
    required this.movieNumber,
    this.videoItemId,
    required this.thumbnailId,
    required this.offsetSeconds,
    required this.image,
  });

  final int pointId;
  final int mediaId;
  // JAV 时刻带番号；视频时刻为 null（用 videoItemId 区分归属）。
  final String? movieNumber;
  final int? videoItemId;
  final int thumbnailId;
  final int offsetSeconds;
  final MovieImageDto? image;

  bool get isVideo => videoItemId != null && videoItemId! > 0;

  // 卡片标签 / 播放器标题 / 副标题统一走这里，避免三处各拼一遍导致 pointId / videoItemId 不一致。
  String localizedDisplayLabel(AppLocalizations l10n) {
    final number = movieNumber;
    if (number != null && number.isNotEmpty) {
      return number;
    }
    final videoId = videoItemId;
    if (videoId != null && videoId > 0) {
      return l10n.momentVideoLabel(videoId);
    }
    return l10n.momentLabel(pointId);
  }

  /// 卡片悬停面板的副信息：`JAV / 视频 · 时刻位置`；来源媒体已删除（[mediaId]
  /// <= 0）时补提示，与预览里的播放入口语义一致。
  String localizedHoverMeta(AppLocalizations l10n) {
    final kind = isVideo ? l10n.momentKindVideo : 'JAV';
    final buffer = StringBuffer(
      '$kind · ${formatMediaTimecode(offsetSeconds)}',
    );
    if (mediaId <= 0) {
      buffer.write(' · ${l10n.momentSourceDeleted}');
    }
    return buffer.toString();
  }
}
