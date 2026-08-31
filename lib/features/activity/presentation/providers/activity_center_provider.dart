import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/activity/data/activity_bootstrap_dto.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_api_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'activity_center_provider.g.dart';

@Riverpod(retry: kNoAsyncNotifierRetry)
class ActivityCenter extends _$ActivityCenter
    with AsyncNotifierDisposeGuardMixin<ActivityCenterState> {
  static const int _pageSize = 20;
  static const Duration _pollingInterval = Duration(seconds: 30);

  Timer? _pollTimer;
  late final DebouncedLatestRequest _taskFilterRequests =
      DebouncedLatestRequest();
  int _taskFilterGeneration = 0;
  ActivityTab? _pendingActiveTab;
  int? _pendingHighlightedTaskRunId;
  bool _hasPendingHighlight = false;

  ActivityCenterState get current => state.value ?? ActivityCenterState.initial;

  @override
  Future<ActivityCenterState> build() async {
    attachDisposeGuard();
    ref.onDispose(() {
      _pollTimer?.cancel();
      _taskFilterRequests.dispose();
    });
    final initial = await _loadInitialState();
    if (!isDisposed) {
      _startPolling();
    }
    return initial.copyWith(
      connectionState: ActivityConnectionState.polling,
      connectionMessage: '每 30 秒同步任务进度',
    );
  }

  Future<ActivityCenterState> _loadInitialState() async {
    try {
      final jobsFuture = _fetchJobs();
      final bootstrap = await _fetchBootstrap(ActivityTaskFilterState.initial);
      final jobsResult = await jobsFuture;
      if (isDisposed) return ActivityCenterState.initial;
      var next = _applyBootstrap(ActivityCenterState.initial, bootstrap).copyWith(
        initialized: true,
        jobs: jobsResult.jobs,
        jobErrorMessage: jobsResult.errorMessage,
      );
      if (_pendingActiveTab != null || _hasPendingHighlight) {
        next = next.copyWith(
          activeTab: _pendingActiveTab ?? next.activeTab,
          highlightedTaskRunId: _hasPendingHighlight
              ? _pendingHighlightedTaskRunId
              : next.highlightedTaskRunId,
        );
        _pendingActiveTab = null;
        _pendingHighlightedTaskRunId = null;
        _hasPendingHighlight = false;
      }
      return next;
    } catch (error) {
      return ActivityCenterState.initial.copyWith(
        initialErrorMessage: apiErrorMessage(error, fallback: '任务中心加载失败，请稍后重试'),
        connectionState: ActivityConnectionState.connecting,
      );
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollingInterval, (_) {
      unawaited(_refreshFromPolling());
    });
  }

  Future<void> reloadAll() async {
    _pollTimer?.cancel();
    _taskFilterRequests.cancel();
    _taskFilterGeneration++;
    state = AsyncData(
      current.copyWith(
        isInitialLoading: true,
        isLoadingJobs: true,
        isRefreshingTaskHistory: false,
        initialErrorMessage: null,
        jobErrorMessage: null,
        taskRefreshErrorMessage: null,
        taskFilterUpdate: const FilterUpdateState.idle(),
        connectionState: ActivityConnectionState.connecting,
        connectionMessage: '正在同步任务中心',
      ),
    );
    try {
      final filter = current.taskFilter;
      final jobsFuture = _fetchJobs();
      final bootstrap = await _fetchBootstrap(filter);
      final jobsResult = await jobsFuture;
      if (isDisposed) return;
      state = AsyncData(
        _applyBootstrap(current, bootstrap).copyWith(
          initialized: true,
          isInitialLoading: false,
          isLoadingJobs: false,
          initialErrorMessage: null,
          jobs: jobsResult.jobs,
          jobErrorMessage: jobsResult.errorMessage,
          connectionState: ActivityConnectionState.polling,
          connectionMessage: '每 30 秒同步任务进度',
        ),
      );
      _startPolling();
    } catch (error) {
      if (isDisposed) return;
      state = AsyncData(
        current.copyWith(
          isInitialLoading: false,
          isLoadingJobs: false,
          initialErrorMessage: apiErrorMessage(
            error,
            fallback: '任务中心加载失败，请稍后重试',
          ),
          connectionState: ActivityConnectionState.polling,
          connectionMessage: '任务同步失败，可手动刷新',
        ),
      );
      _startPolling();
    }
  }

  void setActiveTab(ActivityTab tab, {int? highlightTaskRunId}) {
    if (state.value == null) {
      _pendingActiveTab = tab;
      _pendingHighlightedTaskRunId = highlightTaskRunId;
      _hasPendingHighlight = true;
      return;
    }
    if (current.activeTab == tab &&
        highlightTaskRunId == current.highlightedTaskRunId) {
      return;
    }
    state = AsyncData(
      current.copyWith(activeTab: tab, highlightedTaskRunId: highlightTaskRunId),
    );
  }

  Future<void> applyTaskFilter(ActivityTaskFilterState next) {
    if (current.taskFilter == next) return Future<void>.value();
    _taskFilterGeneration++;
    state = AsyncData(
      current.copyWith(
        taskFilter: next,
        taskFilterUpdate: const FilterUpdateState.loading(),
        isRefreshingTaskHistory: true,
        isLoadingMoreTasks: false,
        taskRefreshErrorMessage: null,
        taskLoadMoreErrorMessage: null,
      ),
    );
    return _taskFilterRequests.schedule(_refreshTaskHistory);
  }

  Future<void> refreshTaskHistory() {
    _taskFilterGeneration++;
    state = AsyncData(
      current.copyWith(
        isRefreshingTaskHistory: true,
        isLoadingMoreTasks: false,
        taskFilterUpdate: const FilterUpdateState.loading(),
        taskRefreshErrorMessage: null,
        taskLoadMoreErrorMessage: null,
      ),
    );
    return _taskFilterRequests.runNow(_refreshTaskHistory);
  }

  Future<void> _refreshTaskHistory(int requestId) async {
    final filter = current.taskFilter;
    try {
      final response = await ref.read(activityApiProvider).getTaskRuns(
        page: 1,
        pageSize: _pageSize,
        state: filter.state,
        taskKey: filter.taskKey,
        triggerType: filter.triggerType,
        sort: filter.sort.apiValue,
      );
      if (isDisposed || !_taskFilterRequests.isCurrent(requestId)) return;
      final tasks = _sortHistoryTasks(response.items, filter);
      state = AsyncData(
        current.copyWith(
          taskRuns: tasks,
          taskNextPage: response.page + 1,
          hasMoreTasks: tasks.length < response.total,
          taskLoadMoreErrorMessage: null,
          taskRefreshErrorMessage: null,
          isRefreshingTaskHistory: false,
          taskFilterUpdate: const FilterUpdateState.idle(),
        ),
      );
    } catch (error) {
      if (isDisposed || !_taskFilterRequests.isCurrent(requestId)) return;
      final message = apiErrorMessage(error, fallback: '任务筛选刷新失败，请重试');
      state = AsyncData(
        current.copyWith(
          taskRefreshErrorMessage: message,
          isRefreshingTaskHistory: false,
          taskFilterUpdate: FilterUpdateState.failed(message),
        ),
      );
    }
  }

  Future<void> refreshJobs() async {
    if (current.isLoadingJobs) return;
    state = AsyncData(current.copyWith(isLoadingJobs: true, jobErrorMessage: null));
    final result = await _fetchJobs();
    if (!isDisposed) {
      state = AsyncData(
        current.copyWith(
          jobs: result.jobs,
          jobErrorMessage: result.errorMessage,
          isLoadingJobs: false,
        ),
      );
    }
  }

  Future<ManualJobTriggerResponseDto> triggerJob(
    String taskKey, {
    Map<String, dynamic>? params,
  }) async {
    if (current.triggeringTaskKeys.contains(taskKey)) {
      throw StateError('job trigger already running');
    }
    state = AsyncData(
      current.copyWith(
        triggeringTaskKeys: <String>{...current.triggeringTaskKeys, taskKey},
      ),
    );
    try {
      final response = await ref
          .read(activityApiProvider)
          .triggerJob(taskKey: taskKey, params: params);
      if (!isDisposed) {
        state = AsyncData(
          current.copyWith(
            activeTab: ActivityTab.tasks,
            highlightedTaskRunId: response.taskRunId,
          ),
        );
        await _refreshFromPolling();
      }
      return response;
    } finally {
      if (!isDisposed) {
        final keys = <String>{...current.triggeringTaskKeys}..remove(taskKey);
        state = AsyncData(current.copyWith(triggeringTaskKeys: keys));
      }
    }
  }

  Future<void> loadMoreTasks() async {
    final now = current;
    if (now.isLoadingMoreTasks ||
        now.isRefreshingTaskHistory ||
        !now.taskFilterUpdate.isIdle ||
        !now.hasMoreTasks) {
      return;
    }
    state = AsyncData(
      now.copyWith(isLoadingMoreTasks: true, taskLoadMoreErrorMessage: null),
    );
    final generation = _taskFilterGeneration;
    final filter = now.taskFilter;
    try {
      final response = await ref.read(activityApiProvider).getTaskRuns(
        page: now.taskNextPage,
        pageSize: _pageSize,
        state: filter.state,
        taskKey: filter.taskKey,
        triggerType: filter.triggerType,
        sort: filter.sort.apiValue,
      );
      if (isDisposed || generation != _taskFilterGeneration) return;
      final tasks = _appendUniqueTasks(current.taskRuns, response.items, filter);
      state = AsyncData(
        current.copyWith(
          taskRuns: tasks,
          taskNextPage: response.page + 1,
          hasMoreTasks: tasks.length < response.total,
          taskLoadMoreErrorMessage: null,
          isLoadingMoreTasks: false,
        ),
      );
    } catch (error) {
      if (isDisposed || generation != _taskFilterGeneration) return;
      state = AsyncData(
        current.copyWith(
          taskLoadMoreErrorMessage: apiErrorMessage(
            error,
            fallback: '加载更多任务失败，请点击重试',
          ),
          isLoadingMoreTasks: false,
        ),
      );
    }
  }

  Future<ActivityBootstrapDto> _fetchBootstrap(ActivityTaskFilterState filter) {
    return ref.read(activityApiProvider).getBootstrap(
      taskState: filter.state,
      taskKey: filter.taskKey,
      taskTriggerType: filter.triggerType,
      taskSort: filter.sort.apiValue,
    );
  }

  Future<_JobsResult> _fetchJobs() async {
    try {
      return _JobsResult(jobs: await ref.read(activityApiProvider).getJobs());
    } catch (error) {
      return _JobsResult(
        jobs: const <JobMetadataDto>[],
        errorMessage: apiErrorMessage(error, fallback: '可执行任务加载失败，请重试'),
      );
    }
  }

  ActivityCenterState _applyBootstrap(
    ActivityCenterState base,
    ActivityBootstrapDto response,
  ) {
    return base.copyWith(
      activeTaskRuns: response.activeTaskRuns,
      taskRuns: response.taskRuns.items,
      taskNextPage: response.taskRuns.page + 1,
      hasMoreTasks: response.taskRuns.items.length < response.taskRuns.total,
      taskLoadMoreErrorMessage: null,
      taskRefreshErrorMessage: null,
    );
  }

  Future<void> _refreshFromPolling() async {
    if (isDisposed || state.value == null) return;
    final generation = _taskFilterGeneration;
    try {
      final filter = current.taskFilter;
      final api = ref.read(activityApiProvider);
      final responses = await Future.wait<PaginatedResponseDto<TaskRunDto>>([
        api.getTaskRuns(
          page: 1,
          pageSize: _pageSize,
          state: filter.state,
          taskKey: filter.taskKey,
          triggerType: filter.triggerType,
          sort: filter.sort.apiValue,
        ),
        api.getTaskRuns(
          page: 1,
          pageSize: 100,
          sort: 'started_at:desc',
        ),
      ]);
      if (isDisposed) return;
      final now = current;
      if (generation != _taskFilterGeneration || !now.taskFilterUpdate.isIdle) {
        state = AsyncData(
          now.copyWith(
            activeTaskRuns: _activeTaskRuns(responses[1].items),
          ),
        );
        return;
      }
      final taskResponse = responses[0];
      state = AsyncData(
        now.copyWith(
          activeTaskRuns: _activeTaskRuns(responses[1].items),
          taskRuns: _sortHistoryTasks(taskResponse.items, filter),
          taskNextPage: taskResponse.page + 1,
          hasMoreTasks:
              taskResponse.items.length < taskResponse.total,
          taskLoadMoreErrorMessage: null,
          taskRefreshErrorMessage: null,
          connectionState: ActivityConnectionState.polling,
          connectionMessage: '每 30 秒同步任务进度',
        ),
      );
    } catch (_) {
      if (!isDisposed) {
        state = AsyncData(
          current.copyWith(
            connectionState: ActivityConnectionState.polling,
            connectionMessage: '任务同步失败，可手动刷新',
          ),
        );
      }
    }
  }

  List<TaskRunDto> _activeTaskRuns(List<TaskRunDto> items) {
    final active = items.where((item) => item.isActive).toList();
    active.sort((left, right) {
      final leftAt = left.startedAt?.millisecondsSinceEpoch ?? 0;
      final rightAt = right.startedAt?.millisecondsSinceEpoch ?? 0;
      return rightAt.compareTo(leftAt);
    });
    return active;
  }

  List<TaskRunDto> _sortHistoryTasks(
    List<TaskRunDto> items,
    ActivityTaskFilterState filter,
  ) {
    final sorted = items.where((item) => _matchesTaskFilter(item, filter)).toList();
    int timestampFor(TaskRunDto item) => switch (filter.sort) {
      ActivityTaskSort.startedAtDesc || ActivityTaskSort.startedAtAsc =>
        item.startedAt?.millisecondsSinceEpoch ?? 0,
      ActivityTaskSort.createdAtDesc || ActivityTaskSort.createdAtAsc =>
        item.createdAt?.millisecondsSinceEpoch ?? 0,
      ActivityTaskSort.updatedAtDesc || ActivityTaskSort.updatedAtAsc =>
        item.updatedAt?.millisecondsSinceEpoch ?? 0,
    };
    sorted.sort((left, right) {
      final comparison = timestampFor(left).compareTo(timestampFor(right));
      return switch (filter.sort) {
        ActivityTaskSort.startedAtDesc ||
        ActivityTaskSort.createdAtDesc ||
        ActivityTaskSort.updatedAtDesc => -comparison,
        _ => comparison,
      };
    });
    return sorted;
  }

  bool _matchesTaskFilter(TaskRunDto item, ActivityTaskFilterState filter) =>
      (filter.state == null || filter.state == item.state) &&
      (filter.taskKey == null || filter.taskKey == item.taskKey) &&
      (filter.triggerType == null || filter.triggerType == item.triggerType);

  List<TaskRunDto> _appendUniqueTasks(
    List<TaskRunDto> currentItems,
    List<TaskRunDto> incoming,
    ActivityTaskFilterState filter,
  ) {
    final next = List<TaskRunDto>.from(currentItems);
    for (final item in incoming) {
      if (next.every((existing) => existing.id != item.id)) next.add(item);
    }
    return _sortHistoryTasks(next, filter);
  }

  bool get initialized => current.initialized;
  bool get isInitialLoading => state.isLoading || current.isInitialLoading;
  String? get initialErrorMessage => current.initialErrorMessage;
  ActivityTab get activeTab => current.activeTab;
  ActivityConnectionState get connectionState => current.connectionState;
  String? get connectionMessage => current.connectionMessage;
  ActivityTaskFilterState get taskFilter => current.taskFilter;
  List<TaskRunDto> get activeTaskRuns => current.activeTaskRuns;
  List<TaskRunDto> get taskRuns => current.taskRuns;
  List<JobMetadataDto> get jobs => current.jobs;
  bool get hasMoreTasks => current.hasMoreTasks;
  bool get isLoadingMoreTasks => current.isLoadingMoreTasks;
  bool get isLoadingJobs => current.isLoadingJobs;
  bool get isRefreshingTaskHistory => current.isRefreshingTaskHistory;
  FilterUpdateState get taskFilterUpdate => current.taskFilterUpdate;
  String? get taskLoadMoreErrorMessage => current.taskLoadMoreErrorMessage;
  String? get jobErrorMessage => current.jobErrorMessage;
  String? get taskRefreshErrorMessage => current.taskRefreshErrorMessage;
  int? get highlightedTaskRunId => current.highlightedTaskRunId;
  bool isTriggeringJob(String taskKey) => current.isTriggeringJob(taskKey);
  bool get isPollingFallback => true;
  List<String> get knownTaskKeys => current.knownTaskKeys;
}

class _JobsResult {
  const _JobsResult({required this.jobs, this.errorMessage});

  final List<JobMetadataDto> jobs;
  final String? errorMessage;
}
