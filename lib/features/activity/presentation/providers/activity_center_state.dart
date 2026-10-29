import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

enum ActivityConnectionState { connecting, polling }

@immutable
class ActivityCenterState {
  ActivityCenterState({
    this.initialized = false,
    this.isInitialLoading = false,
    this.initialErrorMessage,
    this.connectionState = ActivityConnectionState.connecting,
    this.connectionMessage,
    this.taskFilter = ActivityTaskFilterState.initial,
    this.taskFilterUpdate = const FilterUpdateState.idle(),
    List<TaskRunDto> activeTaskRuns = const <TaskRunDto>[],
    List<TaskRunDto> taskRuns = const <TaskRunDto>[],
    List<JobMetadataDto> jobs = const <JobMetadataDto>[],
    this.hasMoreTasks = true,
    this.isLoadingMoreTasks = false,
    this.isLoadingJobs = false,
    this.isRefreshingTaskHistory = false,
    this.taskLoadMoreErrorMessage,
    this.jobErrorMessage,
    this.taskRefreshErrorMessage,
    Set<String> triggeringTaskKeys = const <String>{},
    this.highlightedTaskRunId,
    this.taskNextPage = 1,
  }) : activeTaskRuns = List<TaskRunDto>.unmodifiable(activeTaskRuns),
       taskRuns = List<TaskRunDto>.unmodifiable(taskRuns),
       jobs = List<JobMetadataDto>.unmodifiable(jobs),
       triggeringTaskKeys = Set<String>.unmodifiable(triggeringTaskKeys);

  static final ActivityCenterState initial = ActivityCenterState();

  final bool initialized;
  final bool isInitialLoading;
  final String? initialErrorMessage;
  final ActivityConnectionState connectionState;
  final String? connectionMessage;
  final ActivityTaskFilterState taskFilter;
  final FilterUpdateState taskFilterUpdate;
  final List<TaskRunDto> activeTaskRuns;
  final List<TaskRunDto> taskRuns;
  final List<JobMetadataDto> jobs;

  final bool hasMoreTasks;
  final bool isLoadingMoreTasks;
  final bool isLoadingJobs;
  final bool isRefreshingTaskHistory;
  final String? taskLoadMoreErrorMessage;
  final String? jobErrorMessage;
  final String? taskRefreshErrorMessage;
  final Set<String> triggeringTaskKeys;
  final int? highlightedTaskRunId;
  final int taskNextPage;

  bool get isPollingFallback =>
      connectionState == ActivityConnectionState.polling;

  /// 任务历史是否允许自动补页；失败后只保留页脚/筛选栏的显式重试。
  bool get canAutoLoadMoreTasks =>
      initialized &&
      !isInitialLoading &&
      initialErrorMessage == null &&
      taskFilterUpdate.isIdle &&
      !isRefreshingTaskHistory &&
      hasMoreTasks &&
      !isLoadingMoreTasks &&
      taskLoadMoreErrorMessage == null;

  bool isTriggeringJob(String taskKey) => triggeringTaskKeys.contains(taskKey);

  /// 任务 key 到中文展示名的映射（按 key 排序），原始 key 仍用于接口过滤。
  ///
  /// 展示名优先取任务运行里后端解析好的中文名，其次用任务定义的 cli_help，
  /// 都没有时回退 key 本身。
  Map<String, String> get knownTaskKeyLabels {
    final keys = <String>{};
    final names = <String, String>{};
    void register(String key, String? name) {
      final normalizedKey = key.trim();
      if (normalizedKey.isEmpty) return;
      keys.add(normalizedKey);
      final normalizedName = (name ?? '').trim();
      if (normalizedName.isNotEmpty) {
        names.putIfAbsent(normalizedKey, () => normalizedName);
      }
    }

    for (final item in <TaskRunDto>[...activeTaskRuns, ...taskRuns]) {
      register(item.taskKey, item.taskName);
    }
    for (final item in jobs) {
      register(item.taskKey, item.lastTaskRun?.taskName ?? item.cliHelp);
    }
    final sortedKeys = keys.toList()..sort();
    return <String, String>{
      for (final key in sortedKeys) key: names[key] ?? key,
    };
  }

  /// 出现过的任务 key，按字典序排序。
  List<String> get knownTaskKeys => knownTaskKeyLabels.keys.toList();

  ActivityCenterState copyWith({
    bool? initialized,
    bool? isInitialLoading,
    Object? initialErrorMessage = _unset,
    ActivityConnectionState? connectionState,
    Object? connectionMessage = _unset,
    ActivityTaskFilterState? taskFilter,
    FilterUpdateState? taskFilterUpdate,
    List<TaskRunDto>? activeTaskRuns,
    List<TaskRunDto>? taskRuns,
    List<JobMetadataDto>? jobs,
    bool? hasMoreTasks,
    bool? isLoadingMoreTasks,
    bool? isLoadingJobs,
    bool? isRefreshingTaskHistory,
    Object? taskLoadMoreErrorMessage = _unset,
    Object? jobErrorMessage = _unset,
    Object? taskRefreshErrorMessage = _unset,
    Set<String>? triggeringTaskKeys,
    Object? highlightedTaskRunId = _unset,
    int? taskNextPage,
  }) {
    return ActivityCenterState(
      initialized: initialized ?? this.initialized,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      initialErrorMessage: identical(initialErrorMessage, _unset)
          ? this.initialErrorMessage
          : initialErrorMessage as String?,
      connectionState: connectionState ?? this.connectionState,
      connectionMessage: identical(connectionMessage, _unset)
          ? this.connectionMessage
          : connectionMessage as String?,
      taskFilter: taskFilter ?? this.taskFilter,
      taskFilterUpdate: taskFilterUpdate ?? this.taskFilterUpdate,
      activeTaskRuns: activeTaskRuns ?? this.activeTaskRuns,
      taskRuns: taskRuns ?? this.taskRuns,
      jobs: jobs ?? this.jobs,
      hasMoreTasks: hasMoreTasks ?? this.hasMoreTasks,
      isLoadingMoreTasks: isLoadingMoreTasks ?? this.isLoadingMoreTasks,
      isLoadingJobs: isLoadingJobs ?? this.isLoadingJobs,
      isRefreshingTaskHistory:
          isRefreshingTaskHistory ?? this.isRefreshingTaskHistory,
      taskLoadMoreErrorMessage: identical(taskLoadMoreErrorMessage, _unset)
          ? this.taskLoadMoreErrorMessage
          : taskLoadMoreErrorMessage as String?,
      jobErrorMessage: identical(jobErrorMessage, _unset)
          ? this.jobErrorMessage
          : jobErrorMessage as String?,
      taskRefreshErrorMessage: identical(taskRefreshErrorMessage, _unset)
          ? this.taskRefreshErrorMessage
          : taskRefreshErrorMessage as String?,
      triggeringTaskKeys: triggeringTaskKeys ?? this.triggeringTaskKeys,
      highlightedTaskRunId: identical(highlightedTaskRunId, _unset)
          ? this.highlightedTaskRunId
          : highlightedTaskRunId as int?,
      taskNextPage: taskNextPage ?? this.taskNextPage,
    );
  }

  /// 内容相等：Riverpod 默认按 `==` 决定要不要通知订阅者（`updateShouldNotify`），
  /// 全等时跳过通知，3 秒轮询 tick 无实质变化就不会凭空重建整页。
  /// 必须覆盖全部字段：漏比的字段会静默丢掉该字段的更新。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityCenterState &&
        other.initialized == initialized &&
        other.isInitialLoading == isInitialLoading &&
        other.initialErrorMessage == initialErrorMessage &&
        other.connectionState == connectionState &&
        other.connectionMessage == connectionMessage &&
        other.taskFilter == taskFilter &&
        other.taskFilterUpdate == taskFilterUpdate &&
        listEquals(other.activeTaskRuns, activeTaskRuns) &&
        listEquals(other.taskRuns, taskRuns) &&
        listEquals(other.jobs, jobs) &&
        other.hasMoreTasks == hasMoreTasks &&
        other.isLoadingMoreTasks == isLoadingMoreTasks &&
        other.isLoadingJobs == isLoadingJobs &&
        other.isRefreshingTaskHistory == isRefreshingTaskHistory &&
        other.taskLoadMoreErrorMessage == taskLoadMoreErrorMessage &&
        other.jobErrorMessage == jobErrorMessage &&
        other.taskRefreshErrorMessage == taskRefreshErrorMessage &&
        setEquals(other.triggeringTaskKeys, triggeringTaskKeys) &&
        other.highlightedTaskRunId == highlightedTaskRunId &&
        other.taskNextPage == taskNextPage;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    initialized,
    isInitialLoading,
    initialErrorMessage,
    connectionState,
    connectionMessage,
    taskFilter,
    taskFilterUpdate,
    Object.hashAll(activeTaskRuns),
    Object.hashAll(taskRuns),
    Object.hashAll(jobs),
    hasMoreTasks,
    isLoadingMoreTasks,
    isLoadingJobs,
    isRefreshingTaskHistory,
    taskLoadMoreErrorMessage,
    jobErrorMessage,
    taskRefreshErrorMessage,
    Object.hashAllUnordered(triggeringTaskKeys),
    highlightedTaskRunId,
    taskNextPage,
  ]);
}

const Object _unset = Object();
