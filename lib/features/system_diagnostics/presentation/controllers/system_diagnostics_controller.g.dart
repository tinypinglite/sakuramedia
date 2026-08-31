// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_diagnostics_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 一次「组件诊断」检测的调度器。
///
/// 调度算法（[runAll]）：
///   Stage A（基础资源）：媒体库。空 → 后置全部 blocked。
///   Stage B（独立探针，与 A 并行）：JavDB / JoyTag。
///   Stage C（依赖 A）：下载器（每个 client → 连通性 + 存储 两项，全部并发）。
///   Stage D（依赖 C）：索引器 —— 静态校验、下载器绑定核对和真实搜索测试。
///
/// 单项 try/catch 隔离，任何一项抛异常不影响整体流水推进。

@ProviderFor(SystemDiagnostics)
final systemDiagnosticsProvider = SystemDiagnosticsFamily._();

/// 一次「组件诊断」检测的调度器。
///
/// 调度算法（[runAll]）：
///   Stage A（基础资源）：媒体库。空 → 后置全部 blocked。
///   Stage B（独立探针，与 A 并行）：JavDB / JoyTag。
///   Stage C（依赖 A）：下载器（每个 client → 连通性 + 存储 两项，全部并发）。
///   Stage D（依赖 C）：索引器 —— 静态校验、下载器绑定核对和真实搜索测试。
///
/// 单项 try/catch 隔离，任何一项抛异常不影响整体流水推进。
final class SystemDiagnosticsProvider
    extends $NotifierProvider<SystemDiagnostics, SystemDiagnosticsState> {
  /// 一次「组件诊断」检测的调度器。
  ///
  /// 调度算法（[runAll]）：
  ///   Stage A（基础资源）：媒体库。空 → 后置全部 blocked。
  ///   Stage B（独立探针，与 A 并行）：JavDB / JoyTag。
  ///   Stage C（依赖 A）：下载器（每个 client → 连通性 + 存储 两项，全部并发）。
  ///   Stage D（依赖 C）：索引器 —— 静态校验、下载器绑定核对和真实搜索测试。
  ///
  /// 单项 try/catch 隔离，任何一项抛异常不影响整体流水推进。
  SystemDiagnosticsProvider._({
    required SystemDiagnosticsFamily super.from,
    required SystemDiagnosticsHost super.argument,
  }) : super(
         retry: null,
         name: r'systemDiagnosticsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$systemDiagnosticsHash();

  @override
  String toString() {
    return r'systemDiagnosticsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SystemDiagnostics create() => SystemDiagnostics();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemDiagnosticsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemDiagnosticsState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SystemDiagnosticsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$systemDiagnosticsHash() => r'df1d4ffaa16ceef6ea47807407c190a34c2efefa';

/// 一次「组件诊断」检测的调度器。
///
/// 调度算法（[runAll]）：
///   Stage A（基础资源）：媒体库。空 → 后置全部 blocked。
///   Stage B（独立探针，与 A 并行）：JavDB / JoyTag。
///   Stage C（依赖 A）：下载器（每个 client → 连通性 + 存储 两项，全部并发）。
///   Stage D（依赖 C）：索引器 —— 静态校验、下载器绑定核对和真实搜索测试。
///
/// 单项 try/catch 隔离，任何一项抛异常不影响整体流水推进。

final class SystemDiagnosticsFamily extends $Family
    with
        $ClassFamilyOverride<
          SystemDiagnostics,
          SystemDiagnosticsState,
          SystemDiagnosticsState,
          SystemDiagnosticsState,
          SystemDiagnosticsHost
        > {
  SystemDiagnosticsFamily._()
    : super(
        retry: null,
        name: r'systemDiagnosticsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 一次「组件诊断」检测的调度器。
  ///
  /// 调度算法（[runAll]）：
  ///   Stage A（基础资源）：媒体库。空 → 后置全部 blocked。
  ///   Stage B（独立探针，与 A 并行）：JavDB / JoyTag。
  ///   Stage C（依赖 A）：下载器（每个 client → 连通性 + 存储 两项，全部并发）。
  ///   Stage D（依赖 C）：索引器 —— 静态校验、下载器绑定核对和真实搜索测试。
  ///
  /// 单项 try/catch 隔离，任何一项抛异常不影响整体流水推进。

  SystemDiagnosticsProvider call(SystemDiagnosticsHost host) =>
      SystemDiagnosticsProvider._(argument: host, from: this);

  @override
  String toString() => r'systemDiagnosticsProvider';
}

/// 一次「组件诊断」检测的调度器。
///
/// 调度算法（[runAll]）：
///   Stage A（基础资源）：媒体库。空 → 后置全部 blocked。
///   Stage B（独立探针，与 A 并行）：JavDB / JoyTag。
///   Stage C（依赖 A）：下载器（每个 client → 连通性 + 存储 两项，全部并发）。
///   Stage D（依赖 C）：索引器 —— 静态校验、下载器绑定核对和真实搜索测试。
///
/// 单项 try/catch 隔离，任何一项抛异常不影响整体流水推进。

abstract class _$SystemDiagnostics extends $Notifier<SystemDiagnosticsState> {
  late final _$args = ref.$arg as SystemDiagnosticsHost;
  SystemDiagnosticsHost get host => _$args;

  SystemDiagnosticsState build(SystemDiagnosticsHost host);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<SystemDiagnosticsState, SystemDiagnosticsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SystemDiagnosticsState, SystemDiagnosticsState>,
              SystemDiagnosticsState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
