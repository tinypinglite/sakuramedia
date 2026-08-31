// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'duplicate_media_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 重复媒体分组列表：JAV / PornBox 各自缓存一份分页结果。

@ProviderFor(DuplicateMedia)
final duplicateMediaProvider = DuplicateMediaFamily._();

/// 重复媒体分组列表：JAV / PornBox 各自缓存一份分页结果。
final class DuplicateMediaProvider
    extends
        $AsyncNotifierProvider<
          DuplicateMedia,
          PagedListState<DuplicateMediaGroupDto>
        > {
  /// 重复媒体分组列表：JAV / PornBox 各自缓存一份分页结果。
  DuplicateMediaProvider._({
    required DuplicateMediaFamily super.from,
    required MediaListItemKind super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'duplicateMediaProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$duplicateMediaHash();

  @override
  String toString() {
    return r'duplicateMediaProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DuplicateMedia create() => DuplicateMedia();

  @override
  bool operator ==(Object other) {
    return other is DuplicateMediaProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$duplicateMediaHash() => r'9d7e5cef6eeaae16da8627f6021a20d87f29d472';

/// 重复媒体分组列表：JAV / PornBox 各自缓存一份分页结果。

final class DuplicateMediaFamily extends $Family
    with
        $ClassFamilyOverride<
          DuplicateMedia,
          AsyncValue<PagedListState<DuplicateMediaGroupDto>>,
          PagedListState<DuplicateMediaGroupDto>,
          FutureOr<PagedListState<DuplicateMediaGroupDto>>,
          MediaListItemKind
        > {
  DuplicateMediaFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'duplicateMediaProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// 重复媒体分组列表：JAV / PornBox 各自缓存一份分页结果。

  DuplicateMediaProvider call(MediaListItemKind kind) =>
      DuplicateMediaProvider._(argument: kind, from: this);

  @override
  String toString() => r'duplicateMediaProvider';
}

/// 重复媒体分组列表：JAV / PornBox 各自缓存一份分页结果。

abstract class _$DuplicateMedia
    extends $AsyncNotifier<PagedListState<DuplicateMediaGroupDto>> {
  late final _$args = ref.$arg as MediaListItemKind;
  MediaListItemKind get kind => _$args;

  FutureOr<PagedListState<DuplicateMediaGroupDto>> build(
    MediaListItemKind kind,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<PagedListState<DuplicateMediaGroupDto>>,
              PagedListState<DuplicateMediaGroupDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PagedListState<DuplicateMediaGroupDto>>,
                PagedListState<DuplicateMediaGroupDto>
              >,
              AsyncValue<PagedListState<DuplicateMediaGroupDto>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
