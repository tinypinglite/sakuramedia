// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_client_probe_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 按调用组件 identity 隔离的本地探针状态；请求闭包由 UI 注入，避免新增 API bridge。

@ProviderFor(DownloadClientProbe)
final downloadClientProbeProvider = DownloadClientProbeFamily._();

/// 按调用组件 identity 隔离的本地探针状态；请求闭包由 UI 注入，避免新增 API bridge。
final class DownloadClientProbeProvider
    extends $NotifierProvider<DownloadClientProbe, DownloadClientProbeState> {
  /// 按调用组件 identity 隔离的本地探针状态；请求闭包由 UI 注入，避免新增 API bridge。
  DownloadClientProbeProvider._({
    required DownloadClientProbeFamily super.from,
    required Object super.argument,
  }) : super(
         retry: null,
         name: r'downloadClientProbeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$downloadClientProbeHash();

  @override
  String toString() {
    return r'downloadClientProbeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DownloadClientProbe create() => DownloadClientProbe();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadClientProbeState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadClientProbeState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadClientProbeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$downloadClientProbeHash() =>
    r'80e14fad10760473c48a62e334f5fad29465e106';

/// 按调用组件 identity 隔离的本地探针状态；请求闭包由 UI 注入，避免新增 API bridge。

final class DownloadClientProbeFamily extends $Family
    with
        $ClassFamilyOverride<
          DownloadClientProbe,
          DownloadClientProbeState,
          DownloadClientProbeState,
          DownloadClientProbeState,
          Object
        > {
  DownloadClientProbeFamily._()
    : super(
        retry: null,
        name: r'downloadClientProbeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 按调用组件 identity 隔离的本地探针状态；请求闭包由 UI 注入，避免新增 API bridge。

  DownloadClientProbeProvider call(Object scope) =>
      DownloadClientProbeProvider._(argument: scope, from: this);

  @override
  String toString() => r'downloadClientProbeProvider';
}

/// 按调用组件 identity 隔离的本地探针状态；请求闭包由 UI 注入，避免新增 API bridge。

abstract class _$DownloadClientProbe
    extends $Notifier<DownloadClientProbeState> {
  late final _$args = ref.$arg as Object;
  Object get scope => _$args;

  DownloadClientProbeState build(Object scope);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<DownloadClientProbeState, DownloadClientProbeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DownloadClientProbeState, DownloadClientProbeState>,
              DownloadClientProbeState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
