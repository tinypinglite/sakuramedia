import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

/// 单个任务的全量运行记录（历史弹层）。
@immutable
class TaskRunHistoryState {
  const TaskRunHistoryState({
    required this.paged,
    this.isRefreshing = false,
    this.refreshErrorMessage,
  });

  final PagedListState<TaskRunDto> paged;
  final bool isRefreshing;
  final String? refreshErrorMessage;

  List<TaskRunDto> get runs => paged.items;
  int get nextPage => paged.currentPage + 1;
  bool get hasMore => paged.hasMore;
  bool get isLoadingMore => paged.isLoadingMore;
  String? get loadMoreErrorMessage => paged.loadMoreErrorMessage;
  bool get canAutoLoadMore => !isRefreshing && paged.canAutoLoadMore;

  TaskRunHistoryState copyWith({
    PagedListState<TaskRunDto>? paged,
    bool? isRefreshing,
    Object? refreshErrorMessage = _unset,
  }) {
    return TaskRunHistoryState(
      paged: paged ?? this.paged,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshErrorMessage: identical(refreshErrorMessage, _unset)
          ? this.refreshErrorMessage
          : refreshErrorMessage as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TaskRunHistoryState &&
        other.paged == paged &&
        other.isRefreshing == isRefreshing &&
        other.refreshErrorMessage == refreshErrorMessage;
  }

  @override
  int get hashCode => Object.hash(paged, isRefreshing, refreshErrorMessage);
}

const Object _unset = Object();
