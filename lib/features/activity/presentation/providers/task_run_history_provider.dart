import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_api_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/task_run_history_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'task_run_history_provider.g.dart';

/// 单个任务的全量运行记录：显式 `task_key` + `scope=all`，分页加载、不轮询。
///
/// family(taskKey) + autoDispose：离开历史弹层即释放，不参与任务中心的
/// 3 秒快轮询，也不占用默认操作列表的分页游标。
@Riverpod(retry: kNoAsyncNotifierRetry)
class TaskRunHistory extends _$TaskRunHistory
    with PagedAsyncNotifierMixin<TaskRunHistoryState, TaskRunDto> {
  static const int _pageSize = 20;

  @override
  int get pageSize => _pageSize;

  @override
  String get initialLoadErrorText =>
      ref.read(appLocalizationsProvider).errorTaskFilterRefreshFailed;

  @override
  String get loadMoreErrorText =>
      ref.read(appLocalizationsProvider).errorLoadMoreTasksFailed;

  @override
  Future<TaskRunHistoryState> build(String taskKey) async {
    attachDisposeGuard();
    return TaskRunHistoryState(paged: await loadInitialPage());
  }

  @override
  PagedListState<TaskRunDto> pagedOf(TaskRunHistoryState state) => state.paged;

  @override
  TaskRunHistoryState applyPaged(
    TaskRunHistoryState state,
    PagedListState<TaskRunDto> paged,
  ) {
    return state.copyWith(paged: paged);
  }

  @override
  Object? itemKeyOf(TaskRunDto item) => item.id;

  /// 重新拉取第一页；失败时保留已展示的记录，只在页头暴露错误。
  @override
  Future<String?> refresh() async {
    final now = state.value;
    if (now == null || now.isRefreshing || now.isLoadingMore) return null;
    state = AsyncData(
      now.copyWith(isRefreshing: true, refreshErrorMessage: null),
    );
    final errorMessage = await super.refresh();
    if (!isDisposed) {
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          current.copyWith(
            isRefreshing: false,
            refreshErrorMessage: errorMessage,
          ),
        );
      }
    }
    return errorMessage;
  }

  @override
  Future<PaginatedResponseDto<TaskRunDto>> fetchPage(int page, int pageSize) {
    return ref
        .read(activityApiProvider)
        .getTaskRuns(
          page: page,
          pageSize: pageSize,
          taskKey: taskKey,
          scope: ActivityTaskRunScope.all,
          sort: ActivityTaskSort.startedAtDesc.apiValue,
        );
  }
}
