// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_browse_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 「媒体管理」列表控制器（Riverpod）：分页拉取全局 `/media`，持有筛选与多选。
///
/// 筛选状态遵循项目主流约定：值对象 [MediaBrowseFilterState] 由 State 持有，
/// `fetchPage` 通过内部 [_activeFilter] 字段读取拼参数。UI 改完调 [applyFilterState]
/// 才 reload。多选独立于 filter，reload 会清空。
///
/// 迁移前对应：`MediaBrowseController extends PagedLoadController<MediaListItemDto>`。

@ProviderFor(MediaBrowse)
final mediaBrowseProvider = MediaBrowseProvider._();

/// 「媒体管理」列表控制器（Riverpod）：分页拉取全局 `/media`，持有筛选与多选。
///
/// 筛选状态遵循项目主流约定：值对象 [MediaBrowseFilterState] 由 State 持有，
/// `fetchPage` 通过内部 [_activeFilter] 字段读取拼参数。UI 改完调 [applyFilterState]
/// 才 reload。多选独立于 filter，reload 会清空。
///
/// 迁移前对应：`MediaBrowseController extends PagedLoadController<MediaListItemDto>`。
final class MediaBrowseProvider
    extends $AsyncNotifierProvider<MediaBrowse, MediaBrowseState> {
  /// 「媒体管理」列表控制器（Riverpod）：分页拉取全局 `/media`，持有筛选与多选。
  ///
  /// 筛选状态遵循项目主流约定：值对象 [MediaBrowseFilterState] 由 State 持有，
  /// `fetchPage` 通过内部 [_activeFilter] 字段读取拼参数。UI 改完调 [applyFilterState]
  /// 才 reload。多选独立于 filter，reload 会清空。
  ///
  /// 迁移前对应：`MediaBrowseController extends PagedLoadController<MediaListItemDto>`。
  MediaBrowseProvider._()
    : super(
        from: null,
        argument: null,
        retry: noMediaBrowseRetry,
        name: r'mediaBrowseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaBrowseHash();

  @$internal
  @override
  MediaBrowse create() => MediaBrowse();
}

String _$mediaBrowseHash() => r'03d3002338f0e60fb6ae141d0199c202ab7c11bb';

/// 「媒体管理」列表控制器（Riverpod）：分页拉取全局 `/media`，持有筛选与多选。
///
/// 筛选状态遵循项目主流约定：值对象 [MediaBrowseFilterState] 由 State 持有，
/// `fetchPage` 通过内部 [_activeFilter] 字段读取拼参数。UI 改完调 [applyFilterState]
/// 才 reload。多选独立于 filter，reload 会清空。
///
/// 迁移前对应：`MediaBrowseController extends PagedLoadController<MediaListItemDto>`。

abstract class _$MediaBrowse extends $AsyncNotifier<MediaBrowseState> {
  FutureOr<MediaBrowseState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<MediaBrowseState>, MediaBrowseState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MediaBrowseState>, MediaBrowseState>,
              AsyncValue<MediaBrowseState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
