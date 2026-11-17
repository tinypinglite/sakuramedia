import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

/// 失效媒体列表状态：分页数据和当前正在删除的媒体 id。
@immutable
class InvalidMediaState {
  const InvalidMediaState({
    this.paged = const PagedListState<InvalidMediaDto>(),
    this.deletingMediaId,
  });

  static const InvalidMediaState initial = InvalidMediaState();

  final PagedListState<InvalidMediaDto> paged;
  final int? deletingMediaId;

  InvalidMediaState copyWith({
    PagedListState<InvalidMediaDto>? paged,
    Object? deletingMediaId = _kSentinel,
  }) {
    return InvalidMediaState(
      paged: paged ?? this.paged,
      deletingMediaId: identical(deletingMediaId, _kSentinel)
          ? this.deletingMediaId
          : deletingMediaId as int?,
    );
  }
}

const Object _kSentinel = Object();
