// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_selection_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 标签云及选择草稿。
///
/// 使用同步 Notifier 保留旧控制器的复合态（旧数据 + loading/error），根页面按
/// scope 的 cacheKey 交给 RiverpodPageCache 限量保活；详情预选页则 autoDispose。

@ProviderFor(TagSelection)
final tagSelectionProvider = TagSelectionFamily._();

/// 标签云及选择草稿。
///
/// 使用同步 Notifier 保留旧控制器的复合态（旧数据 + loading/error），根页面按
/// scope 的 cacheKey 交给 RiverpodPageCache 限量保活；详情预选页则 autoDispose。
final class TagSelectionProvider
    extends $NotifierProvider<TagSelection, TagSelectionState> {
  /// 标签云及选择草稿。
  ///
  /// 使用同步 Notifier 保留旧控制器的复合态（旧数据 + loading/error），根页面按
  /// scope 的 cacheKey 交给 RiverpodPageCache 限量保活；详情预选页则 autoDispose。
  TagSelectionProvider._({
    required TagSelectionFamily super.from,
    required TagSelectionScope super.argument,
  }) : super(
         retry: null,
         name: r'tagSelectionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tagSelectionHash();

  @override
  String toString() {
    return r'tagSelectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TagSelection create() => TagSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TagSelectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TagSelectionState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TagSelectionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tagSelectionHash() => r'0da06578cf1fa7b0a11ca5088477ad6862263141';

/// 标签云及选择草稿。
///
/// 使用同步 Notifier 保留旧控制器的复合态（旧数据 + loading/error），根页面按
/// scope 的 cacheKey 交给 RiverpodPageCache 限量保活；详情预选页则 autoDispose。

final class TagSelectionFamily extends $Family
    with
        $ClassFamilyOverride<
          TagSelection,
          TagSelectionState,
          TagSelectionState,
          TagSelectionState,
          TagSelectionScope
        > {
  TagSelectionFamily._()
    : super(
        retry: null,
        name: r'tagSelectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 标签云及选择草稿。
  ///
  /// 使用同步 Notifier 保留旧控制器的复合态（旧数据 + loading/error），根页面按
  /// scope 的 cacheKey 交给 RiverpodPageCache 限量保活；详情预选页则 autoDispose。

  TagSelectionProvider call(TagSelectionScope scope) =>
      TagSelectionProvider._(argument: scope, from: this);

  @override
  String toString() => r'tagSelectionProvider';
}

/// 标签云及选择草稿。
///
/// 使用同步 Notifier 保留旧控制器的复合态（旧数据 + loading/error），根页面按
/// scope 的 cacheKey 交给 RiverpodPageCache 限量保活；详情预选页则 autoDispose。

abstract class _$TagSelection extends $Notifier<TagSelectionState> {
  late final _$args = ref.$arg as TagSelectionScope;
  TagSelectionScope get scope => _$args;

  TagSelectionState build(TagSelectionScope scope);
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
