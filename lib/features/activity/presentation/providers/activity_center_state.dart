import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/activity/data/job_metadata_dto.dart';
import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

enum ActivityTab { tasks, downloadTasks }

enum ActivityConnectionState { connecting, polling }

@immutable
class ActivityCenterState {
  ActivityCenterState({
    this.initialized = false,
    this.isInitialLoading = false,
    this.initialErrorMessage,
    this.activeTab = ActivityTab.tasks,
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
  final ActivityTab activeTab;
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

  bool isTriggeringJob(String taskKey) => triggeringTaskKeys.contains(taskKey);

  List<String> get knownTaskKeys {
    final values = <String>{};
    for (final item in <TaskRunDto>[...activeTaskRuns, ...taskRuns]) {
      if (item.taskKey.trim().isNotEmpty) values.add(item.taskKey);
    }
    for (final item in jobs) {
      if (item.taskKey.trim().isNotEmpty) values.add(item.taskKey);
    }
    return values.toList()..sort();
  }

  ActivityCenterState copyWith({
    bool? initialized,
    bool? isInitialLoading,
    Object? initialErrorMessage = _unset,
    ActivityTab? activeTab,
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
      activeTab: activeTab ?? this.activeTab,
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
}

const Object _unset = Object();
