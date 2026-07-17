// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_rapid_upload_history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 秒传批次历史控制器（Riverpod）：只读分页 + 单批次覆盖更新。
///
/// 触发/重试成功后，页面调 [refreshBatch] 拉最新详情 upsert 进列表，
/// 避免整页 reload；State 就是 [PagedListState]（无附加字段）。
///
/// 迁移前对应：`MediaRapidUploadHistoryController extends PagedLoadController<...>`。

@ProviderFor(MediaRapidUploadHistory)
final mediaRapidUploadHistoryProvider = MediaRapidUploadHistoryProvider._();

/// 秒传批次历史控制器（Riverpod）：只读分页 + 单批次覆盖更新。
///
/// 触发/重试成功后，页面调 [refreshBatch] 拉最新详情 upsert 进列表，
/// 避免整页 reload；State 就是 [PagedListState]（无附加字段）。
///
/// 迁移前对应：`MediaRapidUploadHistoryController extends PagedLoadController<...>`。
final class MediaRapidUploadHistoryProvider
    extends
        $AsyncNotifierProvider<
          MediaRapidUploadHistory,
          PagedListState<MediaRapidUploadBatchListItemDto>
        > {
  /// 秒传批次历史控制器（Riverpod）：只读分页 + 单批次覆盖更新。
  ///
  /// 触发/重试成功后，页面调 [refreshBatch] 拉最新详情 upsert 进列表，
  /// 避免整页 reload；State 就是 [PagedListState]（无附加字段）。
  ///
  /// 迁移前对应：`MediaRapidUploadHistoryController extends PagedLoadController<...>`。
  MediaRapidUploadHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: noMediaRapidUploadHistoryRetry,
        name: r'mediaRapidUploadHistoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaRapidUploadHistoryHash();

  @$internal
  @override
  MediaRapidUploadHistory create() => MediaRapidUploadHistory();
}

String _$mediaRapidUploadHistoryHash() =>
    r'374ab03b4bc30101d4d1c8edd665a8df35bccd40';

/// 秒传批次历史控制器（Riverpod）：只读分页 + 单批次覆盖更新。
///
/// 触发/重试成功后，页面调 [refreshBatch] 拉最新详情 upsert 进列表，
/// 避免整页 reload；State 就是 [PagedListState]（无附加字段）。
///
/// 迁移前对应：`MediaRapidUploadHistoryController extends PagedLoadController<...>`。

abstract class _$MediaRapidUploadHistory
    extends $AsyncNotifier<PagedListState<MediaRapidUploadBatchListItemDto>> {
  FutureOr<PagedListState<MediaRapidUploadBatchListItemDto>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<PagedListState<MediaRapidUploadBatchListItemDto>>,
              PagedListState<MediaRapidUploadBatchListItemDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PagedListState<MediaRapidUploadBatchListItemDto>>,
                PagedListState<MediaRapidUploadBatchListItemDto>
              >,
              AsyncValue<PagedListState<MediaRapidUploadBatchListItemDto>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
