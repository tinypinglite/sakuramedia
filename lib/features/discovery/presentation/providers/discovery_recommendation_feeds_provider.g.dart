// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_recommendation_feeds_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 「发现 → 全部推荐影片」分页列表(桌面/移动共用页面,family 参数为每页条数:
/// 桌面 24 / 移动 18)。
///
/// autoDispose:离开页面即释放,与迁移前「裸 `PagedLoadController` 随页面
/// State 生灭」的语义等价;本页无跨导航保活需求。

@ProviderFor(DailyRecommendationFeed)
final dailyRecommendationFeedProvider = DailyRecommendationFeedFamily._();

/// 「发现 → 全部推荐影片」分页列表(桌面/移动共用页面,family 参数为每页条数:
/// 桌面 24 / 移动 18)。
///
/// autoDispose:离开页面即释放,与迁移前「裸 `PagedLoadController` 随页面
/// State 生灭」的语义等价;本页无跨导航保活需求。
final class DailyRecommendationFeedProvider
    extends
        $AsyncNotifierProvider<
          DailyRecommendationFeed,
          PagedListState<DailyRecommendationMovieDto>
        > {
  /// 「发现 → 全部推荐影片」分页列表(桌面/移动共用页面,family 参数为每页条数:
  /// 桌面 24 / 移动 18)。
  ///
  /// autoDispose:离开页面即释放,与迁移前「裸 `PagedLoadController` 随页面
  /// State 生灭」的语义等价;本页无跨导航保活需求。
  DailyRecommendationFeedProvider._({
    required DailyRecommendationFeedFamily super.from,
    required int super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'dailyRecommendationFeedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dailyRecommendationFeedHash();

  @override
  String toString() {
    return r'dailyRecommendationFeedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DailyRecommendationFeed create() => DailyRecommendationFeed();

  @override
  bool operator ==(Object other) {
    return other is DailyRecommendationFeedProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dailyRecommendationFeedHash() =>
    r'9ac74832d0620d9c1205133007da1340d0b7d4df';

/// 「发现 → 全部推荐影片」分页列表(桌面/移动共用页面,family 参数为每页条数:
/// 桌面 24 / 移动 18)。
///
/// autoDispose:离开页面即释放,与迁移前「裸 `PagedLoadController` 随页面
/// State 生灭」的语义等价;本页无跨导航保活需求。

final class DailyRecommendationFeedFamily extends $Family
    with
        $ClassFamilyOverride<
          DailyRecommendationFeed,
          AsyncValue<PagedListState<DailyRecommendationMovieDto>>,
          PagedListState<DailyRecommendationMovieDto>,
          FutureOr<PagedListState<DailyRecommendationMovieDto>>,
          int
        > {
  DailyRecommendationFeedFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'dailyRecommendationFeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 「发现 → 全部推荐影片」分页列表(桌面/移动共用页面,family 参数为每页条数:
  /// 桌面 24 / 移动 18)。
  ///
  /// autoDispose:离开页面即释放,与迁移前「裸 `PagedLoadController` 随页面
  /// State 生灭」的语义等价;本页无跨导航保活需求。

  DailyRecommendationFeedProvider call(int itemsPerPage) =>
      DailyRecommendationFeedProvider._(argument: itemsPerPage, from: this);

  @override
  String toString() => r'dailyRecommendationFeedProvider';
}

/// 「发现 → 全部推荐影片」分页列表(桌面/移动共用页面,family 参数为每页条数:
/// 桌面 24 / 移动 18)。
///
/// autoDispose:离开页面即释放,与迁移前「裸 `PagedLoadController` 随页面
/// State 生灭」的语义等价;本页无跨导航保活需求。

abstract class _$DailyRecommendationFeed
    extends $AsyncNotifier<PagedListState<DailyRecommendationMovieDto>> {
  late final _$args = ref.$arg as int;
  int get itemsPerPage => _$args;

  FutureOr<PagedListState<DailyRecommendationMovieDto>> build(int itemsPerPage);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<PagedListState<DailyRecommendationMovieDto>>,
              PagedListState<DailyRecommendationMovieDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PagedListState<DailyRecommendationMovieDto>>,
                PagedListState<DailyRecommendationMovieDto>
              >,
              AsyncValue<PagedListState<DailyRecommendationMovieDto>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(HotActressReleaseFeed)
final hotActressReleaseFeedProvider = HotActressReleaseFeedFamily._();

final class HotActressReleaseFeedProvider
    extends
        $AsyncNotifierProvider<
          HotActressReleaseFeed,
          PagedListState<HotActressReleaseMovieDto>
        > {
  HotActressReleaseFeedProvider._({
    required HotActressReleaseFeedFamily super.from,
    required int super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'hotActressReleaseFeedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$hotActressReleaseFeedHash();

  @override
  String toString() {
    return r'hotActressReleaseFeedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  HotActressReleaseFeed create() => HotActressReleaseFeed();

  @override
  bool operator ==(Object other) {
    return other is HotActressReleaseFeedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$hotActressReleaseFeedHash() =>
    r'51cd3c7eb28df3e9edfe7a0257fb7909d61645f2';

final class HotActressReleaseFeedFamily extends $Family
    with
        $ClassFamilyOverride<
          HotActressReleaseFeed,
          AsyncValue<PagedListState<HotActressReleaseMovieDto>>,
          PagedListState<HotActressReleaseMovieDto>,
          FutureOr<PagedListState<HotActressReleaseMovieDto>>,
          int
        > {
  HotActressReleaseFeedFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'hotActressReleaseFeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  HotActressReleaseFeedProvider call(int itemsPerPage) =>
      HotActressReleaseFeedProvider._(argument: itemsPerPage, from: this);

  @override
  String toString() => r'hotActressReleaseFeedProvider';
}

abstract class _$HotActressReleaseFeed
    extends $AsyncNotifier<PagedListState<HotActressReleaseMovieDto>> {
  late final _$args = ref.$arg as int;
  int get itemsPerPage => _$args;

  FutureOr<PagedListState<HotActressReleaseMovieDto>> build(int itemsPerPage);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<PagedListState<HotActressReleaseMovieDto>>,
              PagedListState<HotActressReleaseMovieDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PagedListState<HotActressReleaseMovieDto>>,
                PagedListState<HotActressReleaseMovieDto>
              >,
              AsyncValue<PagedListState<HotActressReleaseMovieDto>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

/// 「发现 → 全部推荐时刻」分页列表,同上(family 参数为每页条数)。
///
/// `MomentRecommendationPageDto` 不是 `PaginatedResponseDto` 子类(多携带
/// `generatedAt`),这里做一次类型适配;适配只此一处,页面不再各自复制。

@ProviderFor(MomentRecommendationFeed)
final momentRecommendationFeedProvider = MomentRecommendationFeedFamily._();

/// 「发现 → 全部推荐时刻」分页列表,同上(family 参数为每页条数)。
///
/// `MomentRecommendationPageDto` 不是 `PaginatedResponseDto` 子类(多携带
/// `generatedAt`),这里做一次类型适配;适配只此一处,页面不再各自复制。
final class MomentRecommendationFeedProvider
    extends
        $AsyncNotifierProvider<
          MomentRecommendationFeed,
          PagedListState<MomentRecommendationDto>
        > {
  /// 「发现 → 全部推荐时刻」分页列表,同上(family 参数为每页条数)。
  ///
  /// `MomentRecommendationPageDto` 不是 `PaginatedResponseDto` 子类(多携带
  /// `generatedAt`),这里做一次类型适配;适配只此一处,页面不再各自复制。
  MomentRecommendationFeedProvider._({
    required MomentRecommendationFeedFamily super.from,
    required int super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'momentRecommendationFeedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$momentRecommendationFeedHash();

  @override
  String toString() {
    return r'momentRecommendationFeedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MomentRecommendationFeed create() => MomentRecommendationFeed();

  @override
  bool operator ==(Object other) {
    return other is MomentRecommendationFeedProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$momentRecommendationFeedHash() =>
    r'07cbf260c2fd33d954c98c829e029943926d60bd';

/// 「发现 → 全部推荐时刻」分页列表,同上(family 参数为每页条数)。
///
/// `MomentRecommendationPageDto` 不是 `PaginatedResponseDto` 子类(多携带
/// `generatedAt`),这里做一次类型适配;适配只此一处,页面不再各自复制。

final class MomentRecommendationFeedFamily extends $Family
    with
        $ClassFamilyOverride<
          MomentRecommendationFeed,
          AsyncValue<PagedListState<MomentRecommendationDto>>,
          PagedListState<MomentRecommendationDto>,
          FutureOr<PagedListState<MomentRecommendationDto>>,
          int
        > {
  MomentRecommendationFeedFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'momentRecommendationFeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 「发现 → 全部推荐时刻」分页列表,同上(family 参数为每页条数)。
  ///
  /// `MomentRecommendationPageDto` 不是 `PaginatedResponseDto` 子类(多携带
  /// `generatedAt`),这里做一次类型适配;适配只此一处,页面不再各自复制。

  MomentRecommendationFeedProvider call(int itemsPerPage) =>
      MomentRecommendationFeedProvider._(argument: itemsPerPage, from: this);

  @override
  String toString() => r'momentRecommendationFeedProvider';
}

/// 「发现 → 全部推荐时刻」分页列表,同上(family 参数为每页条数)。
///
/// `MomentRecommendationPageDto` 不是 `PaginatedResponseDto` 子类(多携带
/// `generatedAt`),这里做一次类型适配;适配只此一处,页面不再各自复制。

abstract class _$MomentRecommendationFeed
    extends $AsyncNotifier<PagedListState<MomentRecommendationDto>> {
  late final _$args = ref.$arg as int;
  int get itemsPerPage => _$args;

  FutureOr<PagedListState<MomentRecommendationDto>> build(int itemsPerPage);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<PagedListState<MomentRecommendationDto>>,
              PagedListState<MomentRecommendationDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PagedListState<MomentRecommendationDto>>,
                PagedListState<MomentRecommendationDto>
              >,
              AsyncValue<PagedListState<MomentRecommendationDto>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
