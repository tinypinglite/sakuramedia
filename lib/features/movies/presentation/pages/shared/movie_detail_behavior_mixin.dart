import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/media/data/media_play_url_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_support.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_clips_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_playback_options.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';

/// 影片详情页双端共用的**业务行为 mixin**——把桌面 / 移动详情页里逐字重复的
/// 方法与本地 override 态收敛到一处。
///
/// 已下沉（改一处两端生效）：订阅 / 合集 / 删媒体 / 标记点 / 保存图 / 找当前点 /
/// 空媒体项、**pageCache 挂载**（[mountPageCache]，key 由 [pageCacheKey] 抽象提供）、
/// build 前半段派生计算（[resolveDerived]）、[executeMovieAction]（远端动作装配）、
/// [showMediaPointActions]（4 个 descriptor + 分派）与 [buildMediaPointPreviewItem]。
///
/// **仍留在页面侧**（差异纯粹在呈现层，不放 mixin）：
/// - `_confirmDeleteMedia`——桌面弹 dialog、移动弹 bottom drawer
/// - `_openInspector`——桌面对话框 / 移动底部抽屉
/// - `_openMediaPointPreview`——预览浮层弹出方式两端不同
/// - `_showMovieActionMenu` / `_showMovieActionDrawer`
/// - `_confirmRefreshMetadata`（桌面）/ `_handleRefresh`（移动）
/// - `_handlePlaySourceChanged`（移动有 `_playMode` 附加逻辑）
/// - `_searchSimilarFromPoint`（桌面/移动 launcher 不同）
/// - `openPlayerForPoint`（桌面 push 播放路由 / 移动经 external player launcher）
/// - 移动独有的合并播放（`_playMode` / `_effectivePlayMode` / `_isMergedPlaybackAvailable`）是真业务差异
///
/// **约束**：宿主必须提供 `movieNumber` getter（同名 [MovieClipSectionMixin]
/// 也要）、`subscriptionChangeNotifier`（页面 `initState` 抓 `movieSubscriptionEventsProvider.notifier`）
/// 及 `pageCacheKey`（页面 initState 调 [mountPageCache]、dispose 调 [unmountPageCache]）。
mixin MovieDetailBehaviorMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// 页面对应的影片编号（如 `widget.movieNumber`）。
  String get movieNumber;

  /// 页面在 `initState` 抓的订阅广播 notifier（避免每次订阅都走 containerOf）。
  MovieSubscriptionEvents get subscriptionChangeNotifier;

  /// 页面挂 RiverpodPageCache 的 key（桌面 / 移动各用各自的 `xxxMovieDetailPageCacheKey`）。
  String get pageCacheKey;

  RiverpodPageHandle? _pageCacheHandle;

  /// 在 `initState` 调用：把详情 + 切片 provider 的 cacheLink 挂进 RiverpodPageCache，
  /// 跨导航保活；LRU 驱逐时统一 close。
  void mountPageCache() {
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: pageCacheKey,
          resolveLinks: () {
            final links = <KeepAliveLink>[];
            final detailLink = ref
                .read(movieDetailProvider(movieNumber).notifier)
                .cacheLink;
            final clipsLink = ref
                .read(movieClipsProvider(movieNumber).notifier)
                .cacheLink;
            if (detailLink != null) links.add(detailLink);
            if (clipsLink != null) links.add(clipsLink);
            return links;
          },
        );
  }

  /// 在 `dispose` 调用：释放 page cache handle。
  void unmountPageCache() {
    _pageCacheHandle?.release();
  }

  /// 页面自持的本地 override 态（跨 mixin 方法共享）。
  final Map<int, List<MovieMediaPointDto>> pointOverrides =
      <int, List<MovieMediaPointDto>>{};
  int? selectedMediaId;
  bool? isSubscribedOverride;
  bool? isBlacklistedOverride;
  bool? isCollectionOverride;
  bool isSubscriptionUpdating = false;
  bool isCollectionUpdating = false;
  int? deletingMediaId;
  MovieDetailActionType? activeMovieAction;
  MoviePlayUrlSource? playSource;

  /// 详情动作是否处于串行锁（订阅 / 合集切换 / remote action 三条互斥）。
  bool get isMovieActionLocked =>
      isSubscriptionUpdating ||
      isCollectionUpdating ||
      activeMovieAction != null;

  // ==========================================================================
  //  合集类型
  // ==========================================================================

  Future<void> loadMovieCollectionStatus() async {
    try {
      final status = await ref
          .read(moviesApiProvider)
          .getMovieCollectionStatus(movieNumber: movieNumber);
      if (!mounted) {
        return;
      }
      setState(() {
        isCollectionOverride = status.isCollection;
      });
    } catch (_) {
      // Fall back to detail payload value when status lookup fails.
    }
  }

  Future<void> toggleMovieCollectionType({required bool isCollection}) async {
    if (isCollectionUpdating) {
      return;
    }
    setState(() {
      isCollectionUpdating = true;
    });

    final targetType = isCollection
        ? MovieCollectionType.single
        : MovieCollectionType.collection;
    try {
      final result = await ref
          .read(moviesApiProvider)
          .updateMovieCollectionType(
            movieNumbers: <String>[movieNumber],
            collectionType: targetType,
          );
      if (!mounted) {
        return;
      }
      if (result.updatedCount <= 0) {
        showToast('未匹配到影片，未更新合集状态');
        return;
      }
      setState(() {
        isCollectionOverride = !isCollection;
      });
      ref
          .read(movieCollectionTypeEventsProvider.notifier)
          .reportChange(movieNumber: movieNumber, targetType: targetType);
      showToast(
        targetType == MovieCollectionType.collection ? '已标记为合集' : '已标记为单体',
      );
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '更新合集状态失败'));
      }
    } finally {
      if (mounted) {
        setState(() {
          isCollectionUpdating = false;
        });
      }
    }
  }

  // ==========================================================================
  //  删除媒体
  // ==========================================================================

  /// 页面级实现：桌面弹 dialog、移动弹 bottom drawer 确认。
  Future<bool?> confirmDeleteMedia(MovieMediaItemDto mediaItem);

  Future<void> deleteSelectedMedia(MovieMediaItemDto mediaItem) async {
    if (deletingMediaId != null) {
      return;
    }

    final confirmed = await confirmDeleteMedia(mediaItem);
    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      deletingMediaId = mediaItem.mediaId;
    });

    try {
      await ref.read(mediaApiProvider).deleteMedia(mediaId: mediaItem.mediaId);
      await refreshAfterMediaDelete(deletedMediaId: mediaItem.mediaId);
      if (mounted) {
        showToast('媒体文件已删除');
      }
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '删除媒体文件失败'));
      }
    } finally {
      if (mounted) {
        setState(() {
          deletingMediaId = null;
        });
      }
    }
  }

  Future<void> refreshAfterMediaDelete({required int deletedMediaId}) async {
    try {
      await ref.read(movieDetailProvider(movieNumber).notifier).refresh();
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }
    resetDetailOverridesAfterRefresh(deletedMediaId: deletedMediaId);
    await loadMovieCollectionStatus();
  }

  /// 详情 refresh 完成后：清 point overrides + subscription/collection override，
  /// 并把 selectedMediaId 保留到「仍在最新媒体列表里且不是刚删除的那个」，
  /// 否则回落到首个媒体。`deletedMediaId=null` 时（如 mobile 下拉刷新）
  /// 表示无特定删除动作，只要当前选中仍存在就保留。
  void resetDetailOverridesAfterRefresh({int? deletedMediaId}) {
    final refreshedMediaItems =
        ref.read(movieDetailProvider(movieNumber)).movie?.mediaItems ??
        const [];
    final currentId = selectedMediaId;
    final retainedSelectedMediaId =
        currentId != null &&
            currentId != deletedMediaId &&
            refreshedMediaItems.any((item) => item.mediaId == currentId)
        ? currentId
        : null;
    setState(() {
      pointOverrides.clear();
      selectedMediaId =
          retainedSelectedMediaId ??
          (refreshedMediaItems.isNotEmpty
              ? refreshedMediaItems.first.mediaId
              : null);
      isSubscribedOverride = null;
      isBlacklistedOverride = null;
      isCollectionOverride = null;
    });
  }

  String mediaStorageLabel(dynamic storage) {
    final libraryName = storage.normalizedLibraryName as String?;
    return libraryName == null
        ? storage.sourceLabel as String
        : '${storage.sourceLabel} · $libraryName';
  }

  String buildMediaDeleteLabel(MovieMediaItemDto mediaItem) {
    final label = mediaItem.specialTags.trim();
    if (label.isNotEmpty) {
      return label;
    }
    return '媒体源 ${mediaItem.mediaId}';
  }

  String mediaDeleteMessage(
    MovieMediaItemDto mediaItem, {
    required bool isCloud115,
    required bool isLocal,
  }) {
    final prefix = '确认删除媒体“${buildMediaDeleteLabel(mediaItem)}”？';
    if (isCloud115) {
      return '$prefix 该操作会删除 115 网盘中的媒体文件（进入 115 回收站），并删除 SakuraMedia 记录。';
    }
    if (isLocal) {
      return '$prefix 该操作会删除本地媒体文件且不可恢复。';
    }
    return '$prefix 该操作会删除媒体文件及 SakuraMedia 记录，且可能无法恢复。';
  }

  // ==========================================================================
  //  媒体 / 标记点辅助
  // ==========================================================================

  List<MovieMediaItemDto> resolveMediaItems(MovieDetailDto movie) {
    if (pointOverrides.isEmpty) {
      return movie.mediaItems;
    }
    return movie.mediaItems
        .map((item) {
          final pointsOverride = pointOverrides[item.mediaId];
          if (pointsOverride == null) {
            return item;
          }
          return item.copyWith(points: pointsOverride);
        })
        .toList(growable: false);
  }

  String resolvePointImageUrl(MovieMediaPointDto point) {
    final origin = point.image?.origin.trim() ?? '';
    if (origin.isNotEmpty) {
      return origin;
    }
    return point.image?.bestAvailableUrl.trim() ?? '';
  }

  String buildPointFileName(MovieMediaPointDto point) {
    final suffix = point.thumbnailId > 0 ? point.thumbnailId : point.pointId;
    return 'movie_point_${movieNumber}_$suffix.webp';
  }

  Future<void> savePointImageToLocal(MovieMediaPointDto point) async {
    final imageUrl = resolvePointImageUrl(point);
    if (imageUrl.isEmpty) {
      return;
    }
    final result =
        await ImageSaveService(
          fetchBytes: ref.read(apiClientProvider).getBytes,
        ).saveImageFromUrl(
          imageUrl: imageUrl,
          fileName: buildPointFileName(point),
          dialogTitle: '保存到本地',
        );
    if (!mounted) {
      return;
    }
    if (result.status == ImageSaveStatus.success) {
      showToast(result.message ?? '图片已保存');
    }
    if (result.status == ImageSaveStatus.failed) {
      showToast(result.message ?? '保存失败，请稍后重试');
    }
  }

  Future<void> toggleMediaPoint(
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
    MovieMediaPointDto? existingPoint,
  ) async {
    try {
      if (existingPoint == null) {
        final createdPoint = await ref
            .read(mediaApiProvider)
            .createMediaPoint(
              mediaId: mediaItem.mediaId,
              thumbnailId: point.thumbnailId,
            );
        if (!mounted) {
          return;
        }
        final nextPoints = <MovieMediaPointDto>[
          ...mediaItem.points,
          _movieMediaPointFromMediaPoint(createdPoint, fallback: point),
        ];
        applyPointListOverride(mediaItem.mediaId, nextPoints);
        showToast('已添加标记');
        return;
      }

      await ref
          .read(mediaApiProvider)
          .deleteMediaPoint(
            mediaId: mediaItem.mediaId,
            pointId: existingPoint.pointId,
          );
      if (!mounted) {
        return;
      }
      final nextPoints = mediaItem.points
          .where((candidate) => candidate.pointId != existingPoint.pointId)
          .toList(growable: false);
      applyPointListOverride(mediaItem.mediaId, nextPoints);
      showToast('已删除标记');
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '更新标记失败'));
      }
    }
  }

  MovieMediaPointDto? findCurrentPoint(int mediaId, int pointId) {
    final movie = ref.read(movieDetailProvider(movieNumber)).movie;
    if (movie == null) {
      return null;
    }
    final mediaItem = resolveMediaItems(movie).firstWhere(
      (item) => item.mediaId == mediaId,
      orElse: () => emptyMediaItem(mediaId),
    );
    for (final point in mediaItem.points) {
      if (point.pointId == pointId) {
        return point;
      }
    }
    return null;
  }

  MovieMediaItemDto emptyMediaItem(int mediaId) {
    return MovieMediaItemDto(
      mediaId: mediaId,
      libraryId: null,
      libraryBackend: null,
      playUrl: '',
      storageMode: '',
      resolution: '',
      fileSizeBytes: 0,
      durationSeconds: 0,
      specialTags: '',
      valid: false,
      progress: null,
      points: const <MovieMediaPointDto>[],
      videoInfo: null,
    );
  }

  MovieMediaPointDto _movieMediaPointFromMediaPoint(
    MediaPointDto point, {
    required MovieMediaPointDto fallback,
  }) {
    return MovieMediaPointDto(
      pointId: point.pointId,
      thumbnailId: point.thumbnailId,
      offsetSeconds: point.offsetSeconds > 0
          ? point.offsetSeconds
          : fallback.offsetSeconds,
      image: point.image ?? fallback.image,
    );
  }

  void applyPointListOverride(int mediaId, List<MovieMediaPointDto> points) {
    if (!mounted) {
      return;
    }
    setState(() {
      pointOverrides[mediaId] = points;
    });
  }

  // ==========================================================================
  //  派生计算 / 媒体点预览与动作（双端逐字相同）
  // ==========================================================================

  /// build 前半段的公共派生计算：媒体列表（含 point override）、订阅 / 合集
  /// override、播放源解析、按源过滤与当前选中媒体。`mergedPlaybackAvailable`
  /// 因两端语义不同（移动还吃 cloud115 合并）留在页面侧单独算。
  MovieDetailDerived resolveDerived(
    MovieDetailDto movie,
    MovieDetailState detailState,
  ) {
    final mediaItems = resolveMediaItems(movie);
    final isSubscribed = isSubscribedOverride ?? movie.isSubscribed;
    final isBlacklisted = isBlacklistedOverride ?? movie.isBlacklisted;
    final isCollection = isCollectionOverride ?? movie.isCollection;
    final sourceOptions = resolveMoviePlaybackSourceOptions(
      mediaItems: mediaItems,
      storageDescriptors: detailState.storageDescriptors,
    );
    final effectivePlaySource = playSource ?? sourceOptions.defaultSource;
    // 详情页下方媒体列表按当前播放源过滤,避免用户切了"本地"却仍能点到
    // 115 媒体、播放失败时收到"115 网盘媒体"文案的歧义。
    final visibleMediaItems = filterMediaItemsByPlaybackSource(
      mediaItems: mediaItems,
      storageDescriptors: detailState.storageDescriptors,
      source: effectivePlaySource,
    );
    final selectedMedia =
        visibleMediaItems
            .where((item) => item.mediaId == selectedMediaId)
            .firstOrNull ??
        (visibleMediaItems.isNotEmpty ? visibleMediaItems.first : null);
    return MovieDetailDerived(
      mediaItems: mediaItems,
      isSubscribed: isSubscribed,
      isBlacklisted: isBlacklisted,
      isCollection: isCollection,
      isActionControlsLocked: isMovieActionLocked,
      sourceOptions: sourceOptions,
      effectivePlaySource: effectivePlaySource,
      visibleMediaItems: visibleMediaItems,
      selectedMedia: selectedMedia,
    );
  }

  /// 媒体点预览条目（桌面 / 移动共用，供 `_openMediaPointPreview` 装配预览弹层）。
  MediaPreviewItem buildMediaPointPreviewItem(
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
  ) {
    return MediaPreviewItem(
      imageUrl: resolvePointImageUrl(point),
      fileName: buildPointFileName(point),
      mediaId: mediaItem.mediaId,
      movieNumber: movieNumber,
      thumbnailId: point.thumbnailId,
      offsetSeconds: point.offsetSeconds,
    );
  }

  /// 媒体点右键 / 长按菜单的 4 个 descriptor（两端逐字相同）。
  List<AppImageActionDescriptor> buildMediaPointActionDescriptors(
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
    MovieMediaPointDto? currentPoint,
    bool hasImage,
  ) {
    return <AppImageActionDescriptor>[
      AppImageActionDescriptor(
        type: AppImageActionType.searchSimilar,
        label: '相似图片',
        icon: Icons.image_search_outlined,
        enabled: hasImage,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.saveToLocal,
        label: '保存到本地',
        icon: Icons.download_outlined,
        enabled: hasImage,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.toggleMark,
        label: currentPoint == null ? '添加标记' : '删除标记',
        icon: currentPoint == null
            ? Icons.bookmark_add_outlined
            : Icons.bookmark_remove_outlined,
        enabled:
            mediaItem.mediaId > 0 &&
            (currentPoint != null || point.thumbnailId > 0),
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.play,
        label: '播放',
        icon: Icons.play_circle_outline_rounded,
        enabled: mediaItem.mediaId > 0 && mediaItem.hasPlayableUrl,
      ),
    ];
  }

  // ==========================================================================
  //  订阅
  // ==========================================================================

  Future<bool> toggleMovieSubscription({required bool isSubscribed}) async {
    if (isSubscriptionUpdating) {
      return false;
    }

    setState(() {
      isSubscriptionUpdating = true;
    });

    MovieSubscriptionToggleResult result;

    try {
      if (isSubscribed) {
        await ref
            .read(moviesApiProvider)
            .unsubscribeMovie(movieNumber: movieNumber, deleteMedia: false);
        result = const MovieSubscriptionToggleResult.unsubscribed();
        isSubscribedOverride = false;
      } else {
        await ref
            .read(moviesApiProvider)
            .subscribeMovie(movieNumber: movieNumber);
        result = const MovieSubscriptionToggleResult.subscribed();
        isSubscribedOverride = true;
      }
    } catch (error) {
      if (isBlockedByMedia(error)) {
        result = const MovieSubscriptionToggleResult.blockedByMedia();
      } else {
        result = MovieSubscriptionToggleResult.failed(
          message: apiErrorMessage(
            error,
            fallback: isSubscribed ? '取消订阅影片失败' : '订阅影片失败',
          ),
        );
      }
    }

    reportSubscriptionChange(result);

    if (!mounted) {
      return false;
    }

    setState(() {
      isSubscriptionUpdating = false;
    });
    showMovieSubscriptionFeedback(result);
    return result.status == MovieSubscriptionToggleStatus.subscribed ||
        result.status == MovieSubscriptionToggleStatus.unsubscribed;
  }

  Future<bool> toggleMovieBlacklist({required bool isBlacklisted}) async {
    if (isMovieActionLocked) {
      return false;
    }
    final targetBlacklisted = !isBlacklisted;
    if (targetBlacklisted) {
      final confirmed = await showAppConfirmDialog(
        context,
        title: '屏蔽影片',
        message: '已订阅影片无法屏蔽，请先取消订阅。屏蔽后将从正常列表和推荐中隐藏。',
        confirmLabel: '屏蔽',
        danger: true,
        failureFallback: '屏蔽影片失败',
        onConfirm: () => ref
            .read(moviesApiProvider)
            .setMoviesBlacklisted(
              movieNumbers: <String>[movieNumber],
              isBlacklisted: true,
            ),
      );
      if (confirmed && mounted) {
        setState(() {
          isBlacklistedOverride = true;
        });
        showToast('已屏蔽影片');
      }
      return confirmed;
    }

    setState(() {
      activeMovieAction = MovieDetailActionType.toggleBlacklist;
    });
    try {
      await ref
          .read(moviesApiProvider)
          .setMoviesBlacklisted(
            movieNumbers: <String>[movieNumber],
            isBlacklisted: false,
          );
      if (!mounted) {
        return false;
      }
      setState(() {
        isBlacklistedOverride = false;
      });
      showToast('已取消屏蔽影片');
      return true;
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '取消屏蔽影片失败'));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          activeMovieAction = null;
        });
      }
    }
  }

  bool isBlockedByMedia(Object error) {
    return error is ApiException &&
        error.error?.code == 'movie_subscription_has_media';
  }

  void reportSubscriptionChange(MovieSubscriptionToggleResult result) {
    switch (result.status) {
      case MovieSubscriptionToggleStatus.subscribed:
        subscriptionChangeNotifier.reportChange(
          movieNumber: movieNumber,
          isSubscribed: true,
        );
        break;
      case MovieSubscriptionToggleStatus.unsubscribed:
        subscriptionChangeNotifier.reportChange(
          movieNumber: movieNumber,
          isSubscribed: false,
        );
        break;
      case MovieSubscriptionToggleStatus.blockedByMedia:
      case MovieSubscriptionToggleStatus.failed:
      case MovieSubscriptionToggleStatus.ignored:
        break;
    }
  }

  // ==========================================================================
  //  媒体点动作菜单 / 详情动作执行（双端逐字相同）
  // ==========================================================================

  /// 媒体点右键 / 长按菜单：4 个 descriptor + 菜单呈现 + 动作分派两端共用；
  /// 播放与相似图跳转经抽象 `openPlayerForPoint` / `searchSimilarFromPoint` 落平台。
  Future<void> showMediaPointActions(
    BuildContext menuContext,
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
    Offset globalPosition,
  ) async {
    final hasImage = resolvePointImageUrl(point).isNotEmpty;
    final currentPoint = findCurrentPoint(mediaItem.mediaId, point.pointId);
    final action = await showAppImageActionMenu(
      context: menuContext,
      globalPosition: globalPosition,
      actions: buildMediaPointActionDescriptors(
        mediaItem,
        point,
        currentPoint,
        hasImage,
      ),
    );
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case AppImageActionType.searchSimilar:
        await searchSimilarFromPoint(point);
        break;
      case AppImageActionType.saveToLocal:
        await savePointImageToLocal(point);
        break;
      case AppImageActionType.toggleMark:
        await toggleMediaPoint(mediaItem, point, currentPoint);
        break;
      case AppImageActionType.play:
        openPlayerForPoint(mediaItem, point);
        break;
      case AppImageActionType.movieDetail:
        break;
    }
  }

  /// 详情动作统一入口：订阅走本 mixin 的订阅切换，其余远端动作经
  /// `executeMovieDetailRemoteAction` 装配（桌面 / 移动逐字相同）。
  Future<bool> executeMovieAction(MovieDetailActionType action) {
    if (action == MovieDetailActionType.toggleSubscription) {
      return toggleMovieSubscription(
        isSubscribed:
            isSubscribedOverride ??
            ref.read(movieDetailProvider(movieNumber)).movie?.isSubscribed ??
            false,
      );
    }
    if (action == MovieDetailActionType.toggleBlacklist) {
      return toggleMovieBlacklist(
        isBlacklisted:
            isBlacklistedOverride ??
            ref.read(movieDetailProvider(movieNumber)).movie?.isBlacklisted ??
            false,
      );
    }

    return executeMovieDetailRemoteAction(
      context: context,
      ref: ref,
      action: action,
      movieNumber: movieNumber,
      isLocked: isMovieActionLocked,
      selectedMediaId: selectedMediaId,
      onActiveActionChanged: (nextAction) {
        if (!mounted) {
          return;
        }
        setState(() {
          activeMovieAction = nextAction;
        });
      },
      onMovieApplied: (result) {
        if (!mounted) {
          return;
        }
        setState(() {
          selectedMediaId = result.selectedMediaId;
          isSubscribedOverride = result.isSubscribedOverride;
          isCollectionOverride = result.isCollectionOverride;
        });
      },
    );
  }

  // ==========================================================================
  //  page-specific 抽象（双端呈现差异）
  // ==========================================================================

  Future<void> openInspector(
    MovieDetailDto movie,
    MovieMediaItemDto? selectedMedia,
  );

  Future<void> openMediaPointPreview(
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
  );

  Future<bool> searchSimilarFromPoint(MovieMediaPointDto point);

  void openPlayerForPoint(
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
  );
}

/// [MovieDetailBehaviorMixin.resolveDerived] 的产物：详情页 build 前半段公共派生值。
class MovieDetailDerived {
  const MovieDetailDerived({
    required this.mediaItems,
    required this.isSubscribed,
    required this.isBlacklisted,
    required this.isCollection,
    required this.isActionControlsLocked,
    required this.sourceOptions,
    required this.effectivePlaySource,
    required this.visibleMediaItems,
    required this.selectedMedia,
  });

  final List<MovieMediaItemDto> mediaItems;
  final bool isSubscribed;
  final bool isBlacklisted;
  final bool isCollection;
  final bool isActionControlsLocked;
  final MoviePlaybackSourceOptions sourceOptions;
  final MoviePlayUrlSource? effectivePlaySource;
  final List<MovieMediaItemDto> visibleMediaItems;
  final MovieMediaItemDto? selectedMedia;
}
