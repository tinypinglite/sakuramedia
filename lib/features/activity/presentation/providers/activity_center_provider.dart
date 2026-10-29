import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/activity/data/activity_bootstrap_dto.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_api_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';

part 'activity_center_provider.g.dart';

@Riverpod(retry: kNoAsyncNotifierRetry)
class ActivityCenter extends _$ActivityCenter
    with AsyncNotifierDisposeGuardMixin<ActivityCenterState> {
  static const int _pageSize = 20;
  static const Duration _pollingInterval = Duration(seconds: 3);

  /// 任务定义变化慢：独立走 30 秒慢轮询，不跟随 3 秒任务进度 tick。
  static const Duration _slowPollingInterval = Duration(seconds: 30);

  Timer? _pollTimer;
  Timer? _slowPollTimer;
  bool _isPolling = false;
  bool _isSlowPolling = false;
  bool _pollingEnabled = true;
  late final DebouncedLatestRequest _taskFilterRequests =
      DebouncedLatestRequest();
  int _taskFilterGeneration = 0;

  ActivityCenterState get current => state.value ?? ActivityCenterState.initial;

  @override
  Future<ActivityCenterState> build() async {
    attachDisposeGuard();
    ref.onDispose(() {
      _pollTimer?.cancel();
      _slowPollTimer?.cancel();
      _taskFilterRequests.dispose();
    });
    final initial = await _loadInitialState();
    if (!isDisposed) {
      _startPolling();
    }
    return initial.copyWith(
      connectionState: ActivityConnectionState.polling,
      connectionMessage: ref
          .read(appLocalizationsProvider)
          .activityConnectionPollingTasks,
    );
  }

  Future<ActivityCenterState> _loadInitialState() async {
    try {
      final jobsFuture = _fetchJobs();
      final bootstrap = await _fetchBootstrap(ActivityTaskFilterState.initial);
      final jobsResult = await jobsFuture;
      if (isDisposed) return ActivityCenterState.initial;
      return _applyBootstrap(ActivityCenterState.initial, bootstrap).copyWith(
        initialized: true,
        jobs: jobsResult.jobs,
        jobErrorMessage: jobsResult.errorMessage,
      );
    } catch (error) {
      return ActivityCenterState.initial.copyWith(
        initialErrorMessage: ref.apiErrorMessage(
          error,
          fallback: ref.read(appLocalizationsProvider).errorActivityLoadFailed,
        ),
        connectionState: ActivityConnectionState.connecting,
      );
    }
  }

  void _startPolling() {
    if (isDisposed || !_pollingEnabled) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollingInterval, (_) {
      unawaited(_refreshFromPolling());
    });
    _slowPollTimer?.cancel();
    _slowPollTimer = Timer.periodic(_slowPollingInterval, (_) {
      unawaited(_refreshSlowData());
    });
  }

  /// 暂停页面不可见期间的任务快照轮询，但保留已加载数据和筛选条件。
  void pausePolling() {
    _pollingEnabled = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _slowPollTimer?.cancel();
    _slowPollTimer = null;
  }

  /// 恢复页面可见后的任务快照轮询，并立即同步一次当前筛选结果。
  Future<void> resumePolling() async {
    if (_pollingEnabled) return;
    _pollingEnabled = true;
    if (isDisposed || state.value == null) return;
    _startPolling();
    await _refreshFromPolling();
  }

  Future<void> reloadAll() async {
    _pollTimer?.cancel();
    _slowPollTimer?.cancel();
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
        connectionMessage: ref
            .read(appLocalizationsProvider)
            .activityConnectionConnectingTasks,
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
          connectionMessage: ref
              .read(appLocalizationsProvider)
              .activityConnectionPollingTasks,
        ),
      );
      _startPolling();
    } catch (error) {
      if (isDisposed) return;
      state = AsyncData(
        current.copyWith(
          isInitialLoading: false,
          isLoadingJobs: false,
          initialErrorMessage: ref.apiErrorMessage(
            error,
            fallback: ref
                .read(appLocalizationsProvider)
                .errorActivityLoadFailed,
          ),
          connectionState: ActivityConnectionState.polling,
          connectionMessage: ref
              .read(appLocalizationsProvider)
              .activityConnectionTaskSyncFailed,
        ),
      );
      _startPolling();
    }
  }

  Future<void> applyTaskFilter(ActivityTaskFilterState next) {
    if (current.taskFilter == next) return Future<void>.value();
    _taskFilterGeneration++;
    state = AsyncData(
      current.copyWith(
        taskFilter: next,
        taskFilterUpdate: const FilterUpdateState.waiting(),
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
    if (isDisposed || !_taskFilterRequests.isCurrent(requestId)) return;
    state = AsyncData(
      current.copyWith(taskFilterUpdate: const FilterUpdateState.loading()),
    );
    try {
      final response = await ref
          .read(activityApiProvider)
          .getTaskRuns(
            page: 1,
            pageSize: _pageSize,
            state: filter.state,
            taskKey: filter.taskKey,
            triggerType: filter.triggerType,
            sort: filter.sort.apiValue,
            scope: filter.taskRunScope,
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
      final message = ref.apiErrorMessage(
        error,
        fallback: ref
            .read(appLocalizationsProvider)
            .errorTaskFilterRefreshFailed,
      );
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
    state = AsyncData(
      current.copyWith(isLoadingJobs: true, jobErrorMessage: null),
    );
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

  /// 下拉刷新 / 显式刷新入口：运行记录与任务定义一起刷新。
  Future<void> refreshAll() async {
    await Future.wait<void>(<Future<void>>[
      refreshTaskHistory(),
      refreshJobs(),
    ]);
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
          current.copyWith(highlightedTaskRunId: response.taskRunId),
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
      final response = await ref
          .read(activityApiProvider)
          .getTaskRuns(
            page: now.taskNextPage,
            pageSize: _pageSize,
            state: filter.state,
            taskKey: filter.taskKey,
            triggerType: filter.triggerType,
            sort: filter.sort.apiValue,
            scope: filter.taskRunScope,
          );
      if (isDisposed || generation != _taskFilterGeneration) return;
      final tasks = _appendUniqueTasks(
        current.taskRuns,
        response.items,
        filter,
      );
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
          taskLoadMoreErrorMessage: ref.apiErrorMessage(
            error,
            fallback: ref
                .read(appLocalizationsProvider)
                .errorLoadMoreTasksFailed,
          ),
          isLoadingMoreTasks: false,
        ),
      );
    }
  }

  Future<ActivityBootstrapDto> _fetchBootstrap(ActivityTaskFilterState filter) {
    return ref
        .read(activityApiProvider)
        .getBootstrap(
          taskState: filter.state,
          taskKey: filter.taskKey,
          taskTriggerType: filter.triggerType,
          taskSort: filter.sort.apiValue,
          taskScope: filter.taskRunScope,
        );
  }

  Future<_JobsResult> _fetchJobs() async {
    try {
      return _JobsResult(jobs: await ref.read(activityApiProvider).getJobs());
    } catch (error) {
      return _JobsResult(
        jobs: const <JobMetadataDto>[],
        errorMessage: ref.apiErrorMessage(
          error,
          fallback: ref
              .read(appLocalizationsProvider)
              .errorExecutableTaskLoadFailed,
        ),
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

  /// 30 秒慢轮询：任务定义。与 3 秒快轮询互不阻塞，
  /// 刷新失败时保留上一次成功的数据，只在有内容时静默更新。
  Future<void> _refreshSlowData() async {
    if (isDisposed || !_pollingEnabled || state.value == null) return;
    if (_isSlowPolling) return;
    _isSlowPolling = true;
    try {
      final jobsResult = await _fetchJobs();
      if (isDisposed || !_pollingEnabled) return;
      final now = current;
      state = AsyncData(
        now.copyWith(
          jobs: jobsResult.jobs.isEmpty && jobsResult.errorMessage != null
              ? now.jobs
              : jobsResult.jobs,
          jobErrorMessage: jobsResult.errorMessage,
        ),
      );
    } finally {
      _isSlowPolling = false;
    }
  }

  Future<void> _refreshFromPolling() async {
    if (isDisposed || !_pollingEnabled || state.value == null || _isPolling) {
      return;
    }
    _isPolling = true;
    final generation = _taskFilterGeneration;
    try {
      final filter = current.taskFilter;
      final api = ref.read(activityApiProvider);
      final (taskResponse, activeTaskRuns) = await (
        api.getTaskRuns(
          page: 1,
          pageSize: _pageSize,
          state: filter.state,
          taskKey: filter.taskKey,
          triggerType: filter.triggerType,
          sort: filter.sort.apiValue,
          scope: filter.taskRunScope,
        ),
        api.getActiveTaskRuns(),
      ).wait;
      if (isDisposed || !_pollingEnabled) return;
      final now = current;
      if (generation != _taskFilterGeneration || !now.taskFilterUpdate.isIdle) {
        // 筛选过渡期只刷新活动区；无变化时 state 相等，Riverpod 不通知。
        state = AsyncData(now.copyWith(activeTaskRuns: activeTaskRuns));
        return;
      }
      if (now.taskNextPage > 2) {
        // 已翻页：只按 id 就地刷新首页命中的条目，保留已加载的后续页。
        // 整体替换会把列表截回第一页，移动端在底部滚动时表现为列表塌缩、
        // 视口回弹闪屏，并让自动加载更多反复重拉第二页。
        state = AsyncData(
          now.copyWith(
            activeTaskRuns: activeTaskRuns,
            taskRuns: _patchLoadedTasks(now.taskRuns, taskResponse.items),
            connectionState: ActivityConnectionState.polling,
            connectionMessage: ref
                .read(appLocalizationsProvider)
                .activityConnectionPollingTasks,
          ),
        );
        return;
      }
      state = AsyncData(
        now.copyWith(
          activeTaskRuns: activeTaskRuns,
          taskRuns: _sortHistoryTasks(taskResponse.items, filter),
          taskNextPage: taskResponse.page + 1,
          hasMoreTasks: taskResponse.items.length < taskResponse.total,
          taskLoadMoreErrorMessage: null,
          taskRefreshErrorMessage: null,
          connectionState: ActivityConnectionState.polling,
          connectionMessage: ref
              .read(appLocalizationsProvider)
              .activityConnectionPollingTasks,
        ),
      );
    } catch (_) {
      if (!isDisposed && _pollingEnabled) {
        state = AsyncData(
          current.copyWith(
            connectionState: ActivityConnectionState.polling,
            connectionMessage: ref
                .read(appLocalizationsProvider)
                .activityConnectionTaskSyncFailed,
          ),
        );
      }
    } finally {
      _isPolling = false;
    }
  }

  List<TaskRunDto> _sortHistoryTasks(
    List<TaskRunDto> items,
    ActivityTaskFilterState filter,
  ) {
    final sorted = items
        .where((item) => _matchesTaskFilter(item, filter))
        .toList();
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

  /// 已翻页时的轮询合并：按 id 就地更新已加载条目，不增删条目、不重置
  /// [ActivityCenterState.taskNextPage] / [ActivityCenterState.hasMoreTasks]。
  List<TaskRunDto> _patchLoadedTasks(
    List<TaskRunDto> currentItems,
    List<TaskRunDto> freshItems,
  ) {
    final freshById = <int, TaskRunDto>{
      for (final item in freshItems) item.id: item,
    };
    if (freshById.isEmpty) return currentItems;
    return <TaskRunDto>[
      for (final item in currentItems) freshById[item.id] ?? item,
    ];
  }

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
  Map<String, String> get knownTaskKeyLabels => current.knownTaskKeyLabels;
}

class _JobsResult {
  const _JobsResult({required this.jobs, this.errorMessage});

  final List<JobMetadataDto> jobs;
  final String? errorMessage;
}
