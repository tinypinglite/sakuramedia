import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/cast/presentation/actions/cast_movie_playback.dart';
import 'package:sakuramedia/features/cast/presentation/providers/cast_session_provider.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_tag_assignment_editor.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_collection_type_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_copy.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_support.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_clips_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_detail_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/system_playlist_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';

/// 影片详情页双端共用的**业务行为 mixin**——把桌面 / 移动详情页里逐字重复的
/// 方法与本地 override 态收敛到一处。
///
/// 已下沉（改一处两端生效）：订阅 / 合集 / 删媒体 / 标记点 / 保存图 / 找当前点 /
/// 空媒体项、**pageCache 挂载**（[mountPageCache]，key 由 [pageCacheKey] 抽象提供）、
/// build 前半段派生计算（[resolveDerived]）、[executeMovieAction]（远端动作装配）、
/// [handleMovieActionSelection] / [confirmRefreshMetadata]（详情动作菜单分派与
/// 刷新确认）、[showMediaPointActions]（4 个 descriptor + 分派）与
/// [buildMediaPointPreviewItem]。
///
/// **仍留在页面侧**（差异纯粹在呈现层，不放 mixin）：
/// - `_confirmDeleteMedia`——桌面弹 dialog、移动弹 bottom drawer
/// - `_openInspector`——桌面对话框 / 移动底部抽屉，按入口键传功能
/// - `_openMediaPointPreview`——预览浮层弹出方式两端不同
/// - `_searchSimilarFromPoint`（桌面/移动 launcher 不同）
/// - `openPlayerForPoint`（桌面 push 播放路由 / 移动经 external player launcher）
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

  /// 详情动作是否处于串行锁（订阅 / 合集切换 / remote action 三条互斥）。
  bool get isMovieActionLocked =>
      isSubscriptionUpdating ||
      isCollectionUpdating ||
      activeMovieAction != null;

  Future<bool> reloadPlaylistMembership() async {
    try {
      final movie = await ref
          .read(moviesApiProvider)
          .getMovieDetail(movieNumber: movieNumber);
      if (!mounted) return true;
      ref.read(movieDetailProvider(movieNumber).notifier).applyMovie(movie);
      return true;
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.moviePagePlaylistUpdateFailed,
            l10n: l10n,
          ),
        );
      }
      return false;
    }
  }

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
        showToast(AppLocalizations.of(context).moviePageCollectionNotMatched);
        return;
      }
      setState(() {
        isCollectionOverride = !isCollection;
      });
      ref
          .read(movieCollectionTypeEventsProvider.notifier)
          .reportChange(movieNumber: movieNumber, targetType: targetType);
      final l10n = AppLocalizations.of(context);
      showToast(
        targetType == MovieCollectionType.collection
            ? l10n.moviePageMarkedAsCollection
            : l10n.moviePageMarkedAsSingle,
      );
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.moviePageCollectionUpdateFailed,
            l10n: l10n,
          ),
        );
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
        showToast(AppLocalizations.of(context).moviePageMediaDeleted);
      }
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.moviePageMediaDeleteFailed,
            l10n: l10n,
          ),
        );
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
    final detailNotifier = ref.read(movieDetailProvider(movieNumber).notifier);
    try {
      await detailNotifier.refresh();
    } catch (_) {
      return;
    }
    detailNotifier.reportView();
    if (!mounted) {
      return;
    }
    final movie = ref.read(movieDetailProvider(movieNumber)).movie;
    if (movie != null) {
      ref
          .read(movieMediaEventsProvider.notifier)
          .reportChange(
            MovieMediaChange(
              movieNumber: movie.movieNumber,
              canPlay: movie.canPlay,
              isSubscribed: movie.isSubscribed,
            ),
          );
    }
    resetDetailOverridesAfterRefresh(deletedMediaId: deletedMediaId);
    await loadMovieCollectionStatus();
  }

  Future<void> editMediaTags(
    MovieMediaItemDto mediaItem, {
    required bool mobile,
  }) async {
    final assignment = await showMediaTagAssignmentEditor(
      context,
      mediaId: mediaItem.mediaId,
      mobile: mobile,
    );
    if (assignment == null || !mounted) return;
    try {
      await ref.read(movieDetailProvider(movieNumber).notifier).refresh();
    } catch (_) {
      // 标签已经存到后端，只是详情刷新失败：页面保留旧标签，下一次进入会
      // 重新拉取。这种情况不能报「已更新」，否则界面没变却提示成功。
      if (mounted) {
        showToast(
          AppLocalizations.of(context).mediaTagsAssignmentSavedRefreshFailed,
        );
      }
      return;
    }
    if (mounted) {
      showToast(AppLocalizations.of(context).mediaTagsAssignmentSaved);
    }
  }

  /// 详情 refresh 完成后：清 point overrides + subscription/collection override，
  /// 并把 selectedMediaId 保留到「仍在最新媒体列表里且不是刚删除的那个」，
  /// 否则回落到首个媒体。`deletedMediaId=null` 表示无特定删除动作，
  /// 只要当前选中仍存在就保留。
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
    final nextSelectedMediaId =
        retainedSelectedMediaId ??
        (refreshedMediaItems.isNotEmpty
            ? refreshedMediaItems.first.mediaId
            : null);
    setState(() {
      pointOverrides.clear();
      selectedMediaId = nextSelectedMediaId;
      isSubscribedOverride = null;
      isBlacklistedOverride = null;
      isCollectionOverride = null;
    });
  }

  String buildMediaDeleteLabel(MovieMediaItemDto mediaItem) {
    final fileName = mediaItem.fileName.trim();
    if (fileName.isNotEmpty) {
      return fileName;
    }
    return AppLocalizations.of(
      context,
    ).moviePageMediaSourceLabel(mediaItem.mediaId);
  }

  String mediaDeleteMessage(MovieMediaItemDto mediaItem) {
    final l10n = AppLocalizations.of(context);
    final prefix = l10n.moviePageMediaDeleteConfirm(
      buildMediaDeleteLabel(mediaItem),
    );
    return '$prefix ${l10n.moviePageMediaDeleteWarning}';
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
    return point.image?.origin.trim() ?? '';
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
    final l10n = AppLocalizations.of(context);
    final result =
        await ImageSaveService(
          fetchBytes: ref.read(apiClientProvider).getBytes,
        ).saveImageFromUrl(
          imageUrl: imageUrl,
          fileName: buildPointFileName(point),
          dialogTitle: l10n.moviePageSaveToLocal,
          l10n: l10n,
        );
    if (!mounted) {
      return;
    }
    if (result.status == ImageSaveStatus.success) {
      showToast(result.message ?? l10n.moviePageImageSaved);
    }
    if (result.status == ImageSaveStatus.failed) {
      showToast(result.message ?? l10n.moviePageImageSaveFailed);
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
        showToast(AppLocalizations.of(context).moviePageMarkAdded);
        return;
      }

      await ref
          .read(mediaApiProvider)
          .deleteMediaPoint(pointId: existingPoint.pointId);
      if (!mounted) {
        return;
      }
      final nextPoints = mediaItem.points
          .where((candidate) => candidate.pointId != existingPoint.pointId)
          .toList(growable: false);
      applyPointListOverride(mediaItem.mediaId, nextPoints);
      showToast(AppLocalizations.of(context).moviePageMarkRemoved);
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.moviePageMarkUpdateFailed,
            l10n: l10n,
          ),
        );
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
      providerKey: null,
      playUrl: '',
      fileName: '',
      resolution: '',
      fileSizeBytes: 0,
      durationSeconds: 0,
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
  /// override 与当前选中媒体。
  MovieDetailDerived resolveDerived(
    MovieDetailDto movie,
    MovieDetailState detailState,
  ) {
    final mediaItems = resolveMediaItems(movie);
    final isSubscribed = isSubscribedOverride ?? movie.isSubscribed;
    final isBlacklisted = isBlacklistedOverride ?? movie.isBlacklisted;
    final isCollection = isCollectionOverride ?? movie.isCollection;
    final selectedMedia =
        mediaItems
            .where((item) => item.mediaId == selectedMediaId)
            .firstOrNull ??
        (mediaItems.isNotEmpty ? mediaItems.first : null);
    return MovieDetailDerived(
      mediaItems: mediaItems,
      isSubscribed: isSubscribed,
      isBlacklisted: isBlacklisted,
      isCollection: isCollection,
      isActionControlsLocked: isMovieActionLocked,
      visibleMediaItems: mediaItems,
      selectedMedia: selectedMedia,
    );
  }

  void selectMedia(MovieMediaItemDto mediaItem) {
    setState(() {
      selectedMediaId = mediaItem.mediaId;
    });
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
    final l10n = AppLocalizations.of(context);
    return <AppImageActionDescriptor>[
      if (ref.read(imageSearchEnabledProvider))
        AppImageActionDescriptor(
          type: AppImageActionType.searchSimilar,
          label: l10n.moviePageActionSimilarImage,
          icon: Icons.image_search_outlined,
          enabled: hasImage,
        ),
      AppImageActionDescriptor(
        type: AppImageActionType.saveToLocal,
        label: l10n.moviePageSaveToLocal,
        icon: Icons.download_outlined,
        enabled: hasImage,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.toggleMark,
        label: currentPoint == null
            ? l10n.moviePageActionAddMark
            : l10n.moviePageActionRemoveMark,
        icon: currentPoint == null
            ? Icons.bookmark_add_outlined
            : Icons.bookmark_remove_outlined,
        enabled:
            mediaItem.mediaId > 0 &&
            (currentPoint != null || point.thumbnailId > 0),
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.play,
        label: l10n.moviePageActionPlay,
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
    final l10n = AppLocalizations.of(context);

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
            fallback: isSubscribed
                ? l10n.moviePageUnsubscribeFailed
                : l10n.moviePageSubscribeFailed,
            l10n: l10n,
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
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
    return result.status == MovieSubscriptionToggleStatus.subscribed ||
        result.status == MovieSubscriptionToggleStatus.unsubscribed;
  }

  Future<bool> toggleMovieFavorite({
    required MovieDetailDto movie,
    required bool isFavorite,
  }) async {
    if (isMovieActionLocked) {
      return false;
    }
    final playlistId = movie.favoritePlaylistId;
    if (playlistId == null) {
      showToast(AppLocalizations.of(context).moviePageFavoriteListNotReady);
      return false;
    }

    setState(() {
      activeMovieAction = MovieDetailActionType.toggleFavorite;
    });

    try {
      final api = ref.read(playlistsApiProvider);
      if (isFavorite) {
        await api.removeMovieFromPlaylist(
          playlistId: playlistId,
          movieNumber: movie.movieNumber,
        );
      } else {
        await api.addMovieToPlaylist(
          playlistId: playlistId,
          movieNumber: movie.movieNumber,
        );
      }
      // 详情页可能在请求期间被关闭；此时不要再用已释放的 ref。
      if (!mounted) {
        return true;
      }
      // 收藏列表可能正被「我的收藏」页监听；只刷新详情会让它在返回后仍显示旧成员。
      ref.invalidate(
        movieSummaryProvider(
          MovieSummaryScope.playlist(playlistId: playlistId),
        ),
      );
      ref.invalidate(playlistDetailProvider(playlistId));
      ref.invalidate(systemPlaylistProvider(PlaylistKind.favorites));
      final refreshed = await reloadPlaylistMembership();
      if (mounted && refreshed) {
        final l10n = AppLocalizations.of(context);
        showToast(
          isFavorite
              ? l10n.moviePageFavoriteRemoved
              : l10n.moviePageFavoriteAdded,
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: isFavorite
                ? l10n.moviePageFavoriteRemoveFailed
                : l10n.moviePageFavoriteAddFailed,
            l10n: l10n,
          ),
        );
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

  Future<bool> toggleMovieBlacklist({required bool isBlacklisted}) async {
    if (isMovieActionLocked) {
      return false;
    }
    final targetBlacklisted = !isBlacklisted;
    if (targetBlacklisted) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.moviePageBlacklistTitle,
        message: l10n.moviePageBlacklistWarning,
        confirmLabel: l10n.moviePageBlacklistConfirm,
        danger: true,
        failureFallback: l10n.moviePageBlacklistFailed,
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
        showToast(AppLocalizations.of(context).moviePageBlacklisted);
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
      showToast(AppLocalizations.of(context).moviePageUnblacklisted);
      return true;
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.moviePageUnblacklistFailed,
            l10n: l10n,
          ),
        );
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
    final action = await showAppActionMenu<AppImageActionType>(
      context: menuContext,
      globalPosition: globalPosition,
      items: buildImageActionMenuItems(
        buildMediaPointActionDescriptors(
          mediaItem,
          point,
          currentPoint,
          hasImage,
        ),
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
      case AppImageActionType.addToCollection:
        break;
      case AppImageActionType.play:
        openPlayerForPoint(mediaItem, point);
        break;
      case AppImageActionType.setCover:
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
    if (action == MovieDetailActionType.toggleFavorite) {
      final movie = ref.read(movieDetailProvider(movieNumber)).movie;
      if (movie == null) {
        return Future<bool>.value(false);
      }
      return toggleMovieFavorite(
        movie: movie,
        isFavorite: movie.playlists.any(
          (playlist) => playlist.kind == PlaylistKind.favorites,
        ),
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

  /// 详情动作菜单选中后的统一分派：本地动作落平台抽象，刷新元数据走共享确认，
  /// 其余远端动作交给 [executeMovieAction]。
  Future<void> handleMovieActionSelection(
    MovieDetailActionType action, {
    required MovieDetailDto movie,
    required MovieMediaItemDto? selectedMedia,
  }) async {
    switch (action) {
      case MovieDetailActionType.castToDevice:
        final castSession = ref.read(castSessionControllerProvider);
        if (castSession != null &&
            castSession.movieNumber == movie.movieNumber) {
          openCastRemotePage(context);
        } else {
          await launchMovieCast(
            context,
            movie: movie,
            selectedMedia: selectedMedia,
          );
        }
      case MovieDetailActionType.refreshMetadata:
        await confirmRefreshMetadata(
          isActorsManuallyManaged: movie.isActorsManuallyManaged,
        );
      case MovieDetailActionType.openMagnetSearch:
        await openInspector(
          movie,
          selectedMedia,
          pane: MovieDetailInspectorPane.magnetSearch,
        );
      case MovieDetailActionType.toggleSubscription:
      case MovieDetailActionType.toggleFavorite:
      case MovieDetailActionType.toggleBlacklist:
      case MovieDetailActionType.recomputeHeat:
        await executeMovieAction(action);
      case MovieDetailActionType.toggleCollectionType:
        await toggleMovieCollectionType(
          isCollection: isCollectionOverride ?? movie.isCollection,
        );
    }
  }

  /// 当前影片是否存在进行中的投屏会话；存在时返回菜单展示文案。
  String? activeCastSessionLabel(MovieDetailDto movie) {
    final session = ref.read(castSessionControllerProvider);
    if (session == null || session.movieNumber != movie.movieNumber) {
      return null;
    }
    return AppLocalizations.of(
      context,
    ).moviePageCastSessionLabel(session.device.name);
  }

  /// 「刷新元数据」覆盖式刷新的共享二次确认（移动底部抽屉 / 桌面居中弹窗）。
  Future<void> confirmRefreshMetadata({
    bool isActorsManuallyManaged = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    await showAppConfirmDialog(
      context,
      title: MovieDetailRefreshConfirmationCopy.title(l10n),
      message: MovieDetailRefreshConfirmationCopy.descriptionFor(
        l10n,
        isActorsManuallyManaged: isActorsManuallyManaged,
      ),
      extraContent: Text(
        MovieDetailRefreshConfirmationCopy.hint(l10n),
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          tone: AppTextTone.muted,
        ),
      ),
      confirmLabel: MovieDetailRefreshConfirmationCopy.confirmLabel(l10n),
      cancelLabel: MovieDetailRefreshConfirmationCopy.cancelLabel(l10n),
      dialogKey: const Key('movie-detail-refresh-metadata-dialog'),
      confirmKey: const Key('movie-detail-refresh-metadata-confirm'),
      cancelKey: const Key('movie-detail-refresh-metadata-cancel'),
      onConfirm: () =>
          executeMovieAction(MovieDetailActionType.refreshMetadata),
    );
  }

  // ==========================================================================
  //  page-specific 抽象（双端呈现差异）
  // ==========================================================================

  Future<void> openInspector(
    MovieDetailDto movie,
    MovieMediaItemDto? selectedMedia, {
    required MovieDetailInspectorPane pane,
  });

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
    required this.visibleMediaItems,
    required this.selectedMedia,
  });

  final List<MovieMediaItemDto> mediaItems;
  final bool isSubscribed;
  final bool isBlacklisted;
  final bool isCollection;
  final bool isActionControlsLocked;
  final List<MovieMediaItemDto> visibleMediaItems;
  final MovieMediaItemDto? selectedMedia;
}
