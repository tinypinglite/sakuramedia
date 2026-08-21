// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_preview_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 发现首屏「今日推荐」预览(只拉 page 1,不分页;family 参数=预览条数,
/// 桌面 6 / 移动 10)。
///
/// 迁移前对应 `DiscoveryController` 的 daily 半边;两条腿拆成独立 provider,
/// 天然获得「一侧失败不拖垮另一侧」(与旧双字段对称结构等价)。
/// autoDispose:离开页面即释放。同步 Notifier + 显式 flags(而非 AsyncNotifier),
/// 因为旧 UI 依赖「refresh 进行中 isLoading=true 且 items 保留」的复合态。

@ProviderFor(DiscoveryDailyPreview)
final discoveryDailyPreviewProvider = DiscoveryDailyPreviewFamily._();

/// 发现首屏「今日推荐」预览(只拉 page 1,不分页;family 参数=预览条数,
/// 桌面 6 / 移动 10)。
///
/// 迁移前对应 `DiscoveryController` 的 daily 半边;两条腿拆成独立 provider,
/// 天然获得「一侧失败不拖垮另一侧」(与旧双字段对称结构等价)。
/// autoDispose:离开页面即释放。同步 Notifier + 显式 flags(而非 AsyncNotifier),
/// 因为旧 UI 依赖「refresh 进行中 isLoading=true 且 items 保留」的复合态。
final class DiscoveryDailyPreviewProvider
    extends
        $NotifierProvider<
          DiscoveryDailyPreview,
          DiscoveryPreviewState<DailyRecommendationMovieDto>
        > {
  /// 发现首屏「今日推荐」预览(只拉 page 1,不分页;family 参数=预览条数,
  /// 桌面 6 / 移动 10)。
  ///
  /// 迁移前对应 `DiscoveryController` 的 daily 半边;两条腿拆成独立 provider,
  /// 天然获得「一侧失败不拖垮另一侧」(与旧双字段对称结构等价)。
  /// autoDispose:离开页面即释放。同步 Notifier + 显式 flags(而非 AsyncNotifier),
  /// 因为旧 UI 依赖「refresh 进行中 isLoading=true 且 items 保留」的复合态。
  DiscoveryDailyPreviewProvider._({
    required DiscoveryDailyPreviewFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'discoveryDailyPreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$discoveryDailyPreviewHash();

  @override
  String toString() {
    return r'discoveryDailyPreviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DiscoveryDailyPreview create() => DiscoveryDailyPreview();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    DiscoveryPreviewState<DailyRecommendationMovieDto> value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<
            DiscoveryPreviewState<DailyRecommendationMovieDto>
          >(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiscoveryDailyPreviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$discoveryDailyPreviewHash() =>
    r'0be559ab08f1383ff39d7ac0f685c23dc37a44ab';

/// 发现首屏「今日推荐」预览(只拉 page 1,不分页;family 参数=预览条数,
/// 桌面 6 / 移动 10)。
///
/// 迁移前对应 `DiscoveryController` 的 daily 半边;两条腿拆成独立 provider,
/// 天然获得「一侧失败不拖垮另一侧」(与旧双字段对称结构等价)。
/// autoDispose:离开页面即释放。同步 Notifier + 显式 flags(而非 AsyncNotifier),
/// 因为旧 UI 依赖「refresh 进行中 isLoading=true 且 items 保留」的复合态。

final class DiscoveryDailyPreviewFamily extends $Family
    with
        $ClassFamilyOverride<
          DiscoveryDailyPreview,
          DiscoveryPreviewState<DailyRecommendationMovieDto>,
          DiscoveryPreviewState<DailyRecommendationMovieDto>,
          DiscoveryPreviewState<DailyRecommendationMovieDto>,
          int
        > {
  DiscoveryDailyPreviewFamily._()
    : super(
        retry: null,
        name: r'discoveryDailyPreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 发现首屏「今日推荐」预览(只拉 page 1,不分页;family 参数=预览条数,
  /// 桌面 6 / 移动 10)。
  ///
  /// 迁移前对应 `DiscoveryController` 的 daily 半边;两条腿拆成独立 provider,
  /// 天然获得「一侧失败不拖垮另一侧」(与旧双字段对称结构等价)。
  /// autoDispose:离开页面即释放。同步 Notifier + 显式 flags(而非 AsyncNotifier),
  /// 因为旧 UI 依赖「refresh 进行中 isLoading=true 且 items 保留」的复合态。

  DiscoveryDailyPreviewProvider call(int pageSize) =>
      DiscoveryDailyPreviewProvider._(argument: pageSize, from: this);

  @override
  String toString() => r'discoveryDailyPreviewProvider';
}

/// 发现首屏「今日推荐」预览(只拉 page 1,不分页;family 参数=预览条数,
/// 桌面 6 / 移动 10)。
///
/// 迁移前对应 `DiscoveryController` 的 daily 半边;两条腿拆成独立 provider,
/// 天然获得「一侧失败不拖垮另一侧」(与旧双字段对称结构等价)。
/// autoDispose:离开页面即释放。同步 Notifier + 显式 flags(而非 AsyncNotifier),
/// 因为旧 UI 依赖「refresh 进行中 isLoading=true 且 items 保留」的复合态。

abstract class _$DiscoveryDailyPreview
    extends $Notifier<DiscoveryPreviewState<DailyRecommendationMovieDto>> {
  late final _$args = ref.$arg as int;
  int get pageSize => _$args;

  DiscoveryPreviewState<DailyRecommendationMovieDto> build(int pageSize);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              DiscoveryPreviewState<DailyRecommendationMovieDto>,
              DiscoveryPreviewState<DailyRecommendationMovieDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                DiscoveryPreviewState<DailyRecommendationMovieDto>,
                DiscoveryPreviewState<DailyRecommendationMovieDto>
              >,
              DiscoveryPreviewState<DailyRecommendationMovieDto>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(DiscoveryHotActressReleasePreview)
final discoveryHotActressReleasePreviewProvider =
    DiscoveryHotActressReleasePreviewFamily._();

final class DiscoveryHotActressReleasePreviewProvider
    extends
        $NotifierProvider<
          DiscoveryHotActressReleasePreview,
          DiscoveryPreviewState<HotActressReleaseMovieDto>
        > {
  DiscoveryHotActressReleasePreviewProvider._({
    required DiscoveryHotActressReleasePreviewFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'discoveryHotActressReleasePreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$discoveryHotActressReleasePreviewHash();

  @override
  String toString() {
    return r'discoveryHotActressReleasePreviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DiscoveryHotActressReleasePreview create() =>
      DiscoveryHotActressReleasePreview();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    DiscoveryPreviewState<HotActressReleaseMovieDto> value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<DiscoveryPreviewState<HotActressReleaseMovieDto>>(
            value,
          ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiscoveryHotActressReleasePreviewProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$discoveryHotActressReleasePreviewHash() =>
    r'99b9ab96cd15a663a1d8317ee6da0168f66362d6';

final class DiscoveryHotActressReleasePreviewFamily extends $Family
    with
        $ClassFamilyOverride<
          DiscoveryHotActressReleasePreview,
          DiscoveryPreviewState<HotActressReleaseMovieDto>,
          DiscoveryPreviewState<HotActressReleaseMovieDto>,
          DiscoveryPreviewState<HotActressReleaseMovieDto>,
          int
        > {
  DiscoveryHotActressReleasePreviewFamily._()
    : super(
        retry: null,
        name: r'discoveryHotActressReleasePreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DiscoveryHotActressReleasePreviewProvider call(int pageSize) =>
      DiscoveryHotActressReleasePreviewProvider._(
        argument: pageSize,
        from: this,
      );

  @override
  String toString() => r'discoveryHotActressReleasePreviewProvider';
}

abstract class _$DiscoveryHotActressReleasePreview
    extends $Notifier<DiscoveryPreviewState<HotActressReleaseMovieDto>> {
  late final _$args = ref.$arg as int;
  int get pageSize => _$args;

  DiscoveryPreviewState<HotActressReleaseMovieDto> build(int pageSize);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              DiscoveryPreviewState<HotActressReleaseMovieDto>,
              DiscoveryPreviewState<HotActressReleaseMovieDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                DiscoveryPreviewState<HotActressReleaseMovieDto>,
                DiscoveryPreviewState<HotActressReleaseMovieDto>
              >,
              DiscoveryPreviewState<HotActressReleaseMovieDto>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

/// 发现首屏「推荐时刻」预览,同上(family 参数=预览条数,桌面 8 / 移动 10)。

@ProviderFor(DiscoveryMomentPreview)
final discoveryMomentPreviewProvider = DiscoveryMomentPreviewFamily._();

/// 发现首屏「推荐时刻」预览,同上(family 参数=预览条数,桌面 8 / 移动 10)。
final class DiscoveryMomentPreviewProvider
    extends
        $NotifierProvider<
          DiscoveryMomentPreview,
          DiscoveryPreviewState<MomentRecommendationDto>
        > {
  /// 发现首屏「推荐时刻」预览,同上(family 参数=预览条数,桌面 8 / 移动 10)。
  DiscoveryMomentPreviewProvider._({
    required DiscoveryMomentPreviewFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'discoveryMomentPreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$discoveryMomentPreviewHash();

  @override
  String toString() {
    return r'discoveryMomentPreviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DiscoveryMomentPreview create() => DiscoveryMomentPreview();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    DiscoveryPreviewState<MomentRecommendationDto> value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<DiscoveryPreviewState<MomentRecommendationDto>>(
            value,
          ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiscoveryMomentPreviewProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$discoveryMomentPreviewHash() =>
    r'aed6796a230e0b4cf094aba140717e4af8a044aa';

/// 发现首屏「推荐时刻」预览,同上(family 参数=预览条数,桌面 8 / 移动 10)。

final class DiscoveryMomentPreviewFamily extends $Family
    with
        $ClassFamilyOverride<
          DiscoveryMomentPreview,
          DiscoveryPreviewState<MomentRecommendationDto>,
          DiscoveryPreviewState<MomentRecommendationDto>,
          DiscoveryPreviewState<MomentRecommendationDto>,
          int
        > {
  DiscoveryMomentPreviewFamily._()
    : super(
        retry: null,
        name: r'discoveryMomentPreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 发现首屏「推荐时刻」预览,同上(family 参数=预览条数,桌面 8 / 移动 10)。

  DiscoveryMomentPreviewProvider call(int pageSize) =>
      DiscoveryMomentPreviewProvider._(argument: pageSize, from: this);

  @override
  String toString() => r'discoveryMomentPreviewProvider';
}

/// 发现首屏「推荐时刻」预览,同上(family 参数=预览条数,桌面 8 / 移动 10)。

abstract class _$DiscoveryMomentPreview
    extends $Notifier<DiscoveryPreviewState<MomentRecommendationDto>> {
  late final _$args = ref.$arg as int;
  int get pageSize => _$args;

  DiscoveryPreviewState<MomentRecommendationDto> build(int pageSize);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              DiscoveryPreviewState<MomentRecommendationDto>,
              DiscoveryPreviewState<MomentRecommendationDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                DiscoveryPreviewState<MomentRecommendationDto>,
                DiscoveryPreviewState<MomentRecommendationDto>
              >,
              DiscoveryPreviewState<MomentRecommendationDto>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
