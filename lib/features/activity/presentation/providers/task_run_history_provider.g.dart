// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_run_history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 单个任务的全量运行记录：显式 `task_key` + `scope=all`，分页加载、不轮询。
///
/// family(taskKey) + autoDispose：离开历史弹层即释放，不参与任务中心的
/// 3 秒快轮询，也不占用默认操作列表的分页游标。

@ProviderFor(TaskRunHistory)
final taskRunHistoryProvider = TaskRunHistoryFamily._();

/// 单个任务的全量运行记录：显式 `task_key` + `scope=all`，分页加载、不轮询。
///
/// family(taskKey) + autoDispose：离开历史弹层即释放，不参与任务中心的
/// 3 秒快轮询，也不占用默认操作列表的分页游标。
final class TaskRunHistoryProvider
    extends $AsyncNotifierProvider<TaskRunHistory, TaskRunHistoryState> {
  /// 单个任务的全量运行记录：显式 `task_key` + `scope=all`，分页加载、不轮询。
  ///
  /// family(taskKey) + autoDispose：离开历史弹层即释放，不参与任务中心的
  /// 3 秒快轮询，也不占用默认操作列表的分页游标。
  TaskRunHistoryProvider._({
    required TaskRunHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'taskRunHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskRunHistoryHash();

  @override
  String toString() {
    return r'taskRunHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskRunHistory create() => TaskRunHistory();

  @override
  bool operator ==(Object other) {
    return other is TaskRunHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskRunHistoryHash() => r'2cdc93ae7ba990597e4c8c07b6920389febcfcfa';

/// 单个任务的全量运行记录：显式 `task_key` + `scope=all`，分页加载、不轮询。
///
/// family(taskKey) + autoDispose：离开历史弹层即释放，不参与任务中心的
/// 3 秒快轮询，也不占用默认操作列表的分页游标。

final class TaskRunHistoryFamily extends $Family
    with
        $ClassFamilyOverride<
          TaskRunHistory,
          AsyncValue<TaskRunHistoryState>,
          TaskRunHistoryState,
          FutureOr<TaskRunHistoryState>,
          String
        > {
  TaskRunHistoryFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'taskRunHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 单个任务的全量运行记录：显式 `task_key` + `scope=all`，分页加载、不轮询。
  ///
  /// family(taskKey) + autoDispose：离开历史弹层即释放，不参与任务中心的
  /// 3 秒快轮询，也不占用默认操作列表的分页游标。

  TaskRunHistoryProvider call(String taskKey) =>
      TaskRunHistoryProvider._(argument: taskKey, from: this);

  @override
  String toString() => r'taskRunHistoryProvider';
}

/// 单个任务的全量运行记录：显式 `task_key` + `scope=all`，分页加载、不轮询。
///
/// family(taskKey) + autoDispose：离开历史弹层即释放，不参与任务中心的
/// 3 秒快轮询，也不占用默认操作列表的分页游标。

abstract class _$TaskRunHistory extends $AsyncNotifier<TaskRunHistoryState> {
  late final _$args = ref.$arg as String;
  String get taskKey => _$args;

  FutureOr<TaskRunHistoryState> build(String taskKey);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<TaskRunHistoryState>, TaskRunHistoryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TaskRunHistoryState>, TaskRunHistoryState>,
              AsyncValue<TaskRunHistoryState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
