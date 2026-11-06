// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'actor_tag_filter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 女优详情作品区的标签条件与当前女优作品标签。
///
/// 标签列表只在该面板首次打开时加载，接口返回的 `movie_count` 已经按当前
/// 女优的作品统计；选择状态由本 provider 持有，关闭面板后继续保留。

@ProviderFor(ActorTagFilter)
final actorTagFilterProvider = ActorTagFilterFamily._();

/// 女优详情作品区的标签条件与当前女优作品标签。
///
/// 标签列表只在该面板首次打开时加载，接口返回的 `movie_count` 已经按当前
/// 女优的作品统计；选择状态由本 provider 持有，关闭面板后继续保留。
final class ActorTagFilterProvider
    extends $NotifierProvider<ActorTagFilter, TagSelectionState> {
  /// 女优详情作品区的标签条件与当前女优作品标签。
  ///
  /// 标签列表只在该面板首次打开时加载，接口返回的 `movie_count` 已经按当前
  /// 女优的作品统计；选择状态由本 provider 持有，关闭面板后继续保留。
  ActorTagFilterProvider._({
    required ActorTagFilterFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'actorTagFilterProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$actorTagFilterHash();

  @override
  String toString() {
    return r'actorTagFilterProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ActorTagFilter create() => ActorTagFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TagSelectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TagSelectionState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ActorTagFilterProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$actorTagFilterHash() => r'6727e11fb244be3359af590164dfe938daff7044';

/// 女优详情作品区的标签条件与当前女优作品标签。
///
/// 标签列表只在该面板首次打开时加载，接口返回的 `movie_count` 已经按当前
/// 女优的作品统计；选择状态由本 provider 持有，关闭面板后继续保留。

final class ActorTagFilterFamily extends $Family
    with
        $ClassFamilyOverride<
          ActorTagFilter,
          TagSelectionState,
          TagSelectionState,
          TagSelectionState,
          int
        > {
  ActorTagFilterFamily._()
    : super(
        retry: null,
        name: r'actorTagFilterProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 女优详情作品区的标签条件与当前女优作品标签。
  ///
  /// 标签列表只在该面板首次打开时加载，接口返回的 `movie_count` 已经按当前
  /// 女优的作品统计；选择状态由本 provider 持有，关闭面板后继续保留。

  ActorTagFilterProvider call(int actorId) =>
      ActorTagFilterProvider._(argument: actorId, from: this);

  @override
  String toString() => r'actorTagFilterProvider';
}

/// 女优详情作品区的标签条件与当前女优作品标签。
///
/// 标签列表只在该面板首次打开时加载，接口返回的 `movie_count` 已经按当前
/// 女优的作品统计；选择状态由本 provider 持有，关闭面板后继续保留。

abstract class _$ActorTagFilter extends $Notifier<TagSelectionState> {
  late final _$args = ref.$arg as int;
  int get actorId => _$args;

  TagSelectionState build(int actorId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TagSelectionState, TagSelectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TagSelectionState, TagSelectionState>,
              TagSelectionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
