// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// activity 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 活动中心和通知中心通过它访问任务与通知快照。测试需要替身时用
/// `overrideWithValue(...)`。

@ProviderFor(activityApi)
final activityApiProvider = ActivityApiProvider._();

/// activity 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 活动中心和通知中心通过它访问任务与通知快照。测试需要替身时用
/// `overrideWithValue(...)`。

final class ActivityApiProvider
    extends $FunctionalProvider<ActivityApi, ActivityApi, ActivityApi>
    with $Provider<ActivityApi> {
  /// activity 域 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 活动中心和通知中心通过它访问任务与通知快照。测试需要替身时用
  /// `overrideWithValue(...)`。
  ActivityApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activityApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activityApiHash();

  @$internal
  @override
  $ProviderElement<ActivityApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ActivityApi create(Ref ref) {
    return activityApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActivityApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActivityApi>(value),
    );
  }
}

String _$activityApiHash() => r'd2735d3da948b00941af11648cf37eb62b9c080d';
