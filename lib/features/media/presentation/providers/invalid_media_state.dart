import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

/// 「媒体维护」（失效媒体巡检）State：
/// - [paged]：失效媒体分页；
/// - [checkingMediaId]：正在复查的媒体 id（单飞）；
/// - [deletingMediaId]：正在删除的媒体 id（单飞）；
/// - [deleteEnabledMediaIds]：已复查确认「仍失效」的 id 集合——只有位于此集合的条目
///   才允许 [deleteInvalidMedia]（对齐 legacy 语义）。
@immutable
class InvalidMediaState {
  InvalidMediaState({
    this.paged = const PagedListState<InvalidMediaDto>(),
    this.checkingMediaId,
    this.deletingMediaId,
    Set<int> deleteEnabledMediaIds = const <int>{},
  }) : deleteEnabledMediaIds = Set<int>.unmodifiable(deleteEnabledMediaIds);

  static final InvalidMediaState initial = InvalidMediaState();

  final PagedListState<InvalidMediaDto> paged;
  final int? checkingMediaId;
  final int? deletingMediaId;
  final Set<int> deleteEnabledMediaIds;

  bool canDeleteMedia(int mediaId) => deleteEnabledMediaIds.contains(mediaId);

  InvalidMediaState copyWith({
    PagedListState<InvalidMediaDto>? paged,
    Object? checkingMediaId = _kSentinel,
    Object? deletingMediaId = _kSentinel,
    Set<int>? deleteEnabledMediaIds,
  }) {
    return InvalidMediaState(
      paged: paged ?? this.paged,
      checkingMediaId: identical(checkingMediaId, _kSentinel)
          ? this.checkingMediaId
          : checkingMediaId as int?,
      deletingMediaId: identical(deletingMediaId, _kSentinel)
          ? this.deletingMediaId
          : deletingMediaId as int?,
      deleteEnabledMediaIds:
          deleteEnabledMediaIds ?? this.deleteEnabledMediaIds,
    );
  }
}

const Object _kSentinel = Object();
