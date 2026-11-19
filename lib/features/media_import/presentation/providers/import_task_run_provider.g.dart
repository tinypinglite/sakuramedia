// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_task_run_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 导入页「最近一次导入」状态卡的数据源。
///
/// 任务活跃期间每 3 秒拉一次单条任务运行；到达终态后流结束，页面不再轮询。
/// 离开页面时 provider autoDispose，流随之取消。

@ProviderFor(importTaskRun)
final importTaskRunProvider = ImportTaskRunFamily._();

/// 导入页「最近一次导入」状态卡的数据源。
///
/// 任务活跃期间每 3 秒拉一次单条任务运行；到达终态后流结束，页面不再轮询。
/// 离开页面时 provider autoDispose，流随之取消。

final class ImportTaskRunProvider
    extends
        $FunctionalProvider<
          AsyncValue<TaskRunDto>,
          TaskRunDto,
          Stream<TaskRunDto>
        >
    with $FutureModifier<TaskRunDto>, $StreamProvider<TaskRunDto> {
  /// 导入页「最近一次导入」状态卡的数据源。
  ///
  /// 任务活跃期间每 3 秒拉一次单条任务运行；到达终态后流结束，页面不再轮询。
  /// 离开页面时 provider autoDispose，流随之取消。
  ImportTaskRunProvider._({
    required ImportTaskRunFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'importTaskRunProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$importTaskRunHash();

  @override
  String toString() {
    return r'importTaskRunProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<TaskRunDto> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<TaskRunDto> create(Ref ref) {
    final argument = this.argument as int;
    return importTaskRun(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ImportTaskRunProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$importTaskRunHash() => r'e4682b4e419b3e223ade9e7f62a99cf24a8d53fd';

/// 导入页「最近一次导入」状态卡的数据源。
///
/// 任务活跃期间每 3 秒拉一次单条任务运行；到达终态后流结束，页面不再轮询。
/// 离开页面时 provider autoDispose，流随之取消。

final class ImportTaskRunFamily extends $Family
    with $FunctionalFamilyOverride<Stream<TaskRunDto>, int> {
  ImportTaskRunFamily._()
    : super(
        retry: null,
        name: r'importTaskRunProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 导入页「最近一次导入」状态卡的数据源。
  ///
  /// 任务活跃期间每 3 秒拉一次单条任务运行；到达终态后流结束，页面不再轮询。
  /// 离开页面时 provider autoDispose，流随之取消。

  ImportTaskRunProvider call(int taskRunId) =>
      ImportTaskRunProvider._(argument: taskRunId, from: this);

  @override
  String toString() => r'importTaskRunProvider';
}
