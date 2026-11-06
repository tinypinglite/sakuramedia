import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/actions/video_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_actions_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_actions_sheet.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_filter_drawer.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_scope.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/video_display_title.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/add_to_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/pick_video_collection_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

/// PornBox 首页双端共享的状态与动作。
///
/// 页面只负责自己的布局；分页缓存、刷新、筛选、单条/批量动作和跨页 mutation
/// 都收敛在这里。
mixin VideoOverviewActionsMixin<W extends ConsumerStatefulWidget>
    on ConsumerState<W>, MultiSelectStateMixin<W, int> {
  late final ScrollController scrollController;
  final GlobalKey listHeaderKey = GlobalKey();
  RiverpodPageHandle? _pageCacheHandle;
  bool _railRefreshScheduled = false;

  VideoSummaryScope get overviewScope;
  bool get isMobile;
  String get overviewCacheKey;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: overviewCacheKey,
          resolveLinks: () {
            final link = ref
                .read(videoSummaryProvider(overviewScope).notifier)
                .cacheLink;
            return link == null ? const [] : [link];
          },
        );
  }

  @override
  void dispose() {
    _pageCacheHandle?.release();
    scrollController.dispose();
    super.dispose();
  }

  List<VideoItemListItemDto> get loadedVideos =>
      ref.read(videoSummaryProvider(overviewScope)).value?.paged.items ??
      const <VideoItemListItemDto>[];

  @override
  List<int> get selectionOrderedIds =>
      loadedVideos.map((video) => video.id).toList(growable: false);

  VideoFilterState get currentFilter =>
      ref.read(videoSummaryProvider(overviewScope)).value?.filter ??
      VideoFilterState.initial;

  bool get canAutoLoadMore =>
      ref
          .read(videoSummaryProvider(overviewScope))
          .value
          ?.paged
          .canAutoLoadMore ??
      false;

  List<VideoItemListItemDto> selectedVideos() => loadedVideos
      .where((video) => isSelected(video.id))
      .toList(growable: false);

  Future<void> loadMore() =>
      ref.read(videoSummaryProvider(overviewScope).notifier).loadMore();

  void listenForMutations() {
    ref.listen(videoMutationEventsProvider, (_, next) {
      if (next.value != null) {
        _onMutation();
      }
    });
  }

  void _onMutation() {
    if (_railRefreshScheduled) {
      return;
    }
    _railRefreshScheduled = true;
    scheduleMicrotask(() {
      _railRefreshScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(ref.read(videoCollectionsOverviewProvider.notifier).refresh());
    });
  }

  Future<void> refreshOverview() async {
    await Future.wait<void>([
      ref.read(videoSummaryProvider(overviewScope).notifier).refresh(),
      ref.read(videoCollectionsOverviewProvider.notifier).refresh(),
    ]);
  }

  void applyFilter(VideoFilterState next) {
    if (next.matches(currentFilter)) {
      return;
    }
    if (scrollController.hasClients) {
      AppPinnedListHeader.scrollToStart(listHeaderKey, scrollController);
    }
    unawaited(
      ref.read(videoSummaryProvider(overviewScope).notifier).applyFilter(next),
    );
  }

  void retryFilter() {
    unawaited(
      ref.read(videoSummaryProvider(overviewScope).notifier).retryFilter(),
    );
  }

  void openActions(VideoItemListItemDto video) {
    if (isMobile) {
      showMobileVideoActionsSheet(
        context,
        video: video,
        onPlay: () => playVideo(video),
        onThumbnails: () => MobileVideoThumbnailRouteData(
          videoId: video.id,
        ).push<void>(context),
        onAddToCollection: () => addToCollection(video),
        onDelete: () => deleteVideo(video),
        collections: video.collections,
        onCollectionTap: (ref) => MobileVideoCollectionDetailRouteData(
          collectionId: ref.id,
        ).push(context),
      );
      return;
    }
    showDesktopVideoActionsDialog(
      context,
      video: video,
      onPlay: () => unawaited(playVideo(video)),
      onThumbnails: () => context.pushDesktopVideoThumbnails(videoId: video.id),
      onAddToCollection: () => addToCollection(video),
      onDelete: () => deleteVideo(video),
      collections: video.collections,
      onCollectionTap: (ref) =>
          context.pushDesktopVideoCollectionDetail(collectionId: ref.id),
    );
  }

  Future<void> playVideo(VideoItemListItemDto video) async {
    if (await tryLaunchExternalVideoPlayback(
      context,
      videoId: video.id,
      title: video.displayTitle(AppLocalizations.of(context)),
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (isMobile) {
      await MobileVideoPlayerRouteData(videoId: video.id).push<void>(context);
      return;
    }
    context.pushDesktopVideoPlayer(videoId: video.id);
  }

  Future<void> addToCollection(VideoItemListItemDto video) async {
    await showAddToVideoCollectionDialog(
      context,
      videoItemId: video.id,
      collectedRefs: video.collections,
      presentation: isMobile
          ? AddToVideoCollectionPresentation.bottomDrawer
          : AddToVideoCollectionPresentation.dialog,
    );
    if (!mounted) {
      return;
    }
    ref
        .read(videoMutationEventsProvider.notifier)
        .reportCollectionMembershipChanged(videoId: video.id);
  }

  Future<void> deleteVideo(VideoItemListItemDto video) async {
    final l10n = AppLocalizations.of(context);
    final title = video.preferredTitle.trim();
    final label = title.isEmpty ? l10n.videoGenericVideo : '“$title”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.videoDeleteTitle,
      message: l10n.videoDeleteConfirmMessage(label),
      danger: true,
      confirmLabel: l10n.commonDelete,
      dialogKey: isMobile ? const Key('mobile-video-delete-drawer') : null,
      confirmKey: Key(
        isMobile
            ? 'mobile-video-delete-confirm-button'
            : 'video-delete-confirm-button',
      ),
      onConfirm: () => ref.read(videosApiProvider).deleteVideo(video.id),
      failureFallback: l10n.videoDeleteFailed,
    );
    if (!mounted || !confirmed) {
      return;
    }
    ref.read(videoMutationEventsProvider.notifier).reportDeleted(video.id);
    showToast(l10n.videoDeletedToast, tone: AppToastTone.success);
  }

  Future<void> batchAddToCollection() async {
    final selected = selectedVideos();
    if (selected.isEmpty) {
      return;
    }
    final target = await showPickVideoCollectionDialog(
      context,
      presentation: isMobile
          ? PickVideoCollectionPresentation.bottomDrawer
          : PickVideoCollectionPresentation.dialog,
    );
    if (!mounted || target == null) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.videoCollectionAdd,
      targetCollectionId: target.id,
      ids: selected.map((video) => video.id).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> batchDelete() async {
    final selected = selectedVideos();
    if (selected.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.videoDeleteTitle,
      message: l10n.videoBatchDeleteConfirmMessage(selected.length),
      danger: true,
      confirmLabel: l10n.commonDelete,
      dialogKey: isMobile
          ? const Key('mobile-videos-batch-delete-drawer')
          : null,
      confirmKey: Key(
        isMobile
            ? 'mobile-videos-batch-delete-confirm-button'
            : 'videos-batch-delete-confirm-button',
      ),
    );
    if (!mounted || !confirmed) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.videoDelete,
      ids: selected.map((video) => video.id).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> createCollection() async {
    final created = await showVideoCollectionDialog(
      context,
      presentation: isMobile
          ? VideoCollectionEditPresentation.bottomDrawer
          : VideoCollectionEditPresentation.dialog,
    );
    if (!mounted || created == null) {
      return;
    }
    await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
    if (isMobile && mounted) {
      showToast(
        AppLocalizations.of(context).videoCollectionCreated,
        tone: AppToastTone.success,
      );
    }
  }

  Future<void> viewAllCollections() async {
    if (isMobile) {
      await const MobileVideoCollectionsRouteData().push<void>(context);
    } else {
      await context.pushDesktopVideoCollections();
    }
    if (!mounted) {
      return;
    }
    await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
  }

  Future<void> openFilterDrawer() async {
    await showMobileVideoFilterDrawer(
      context,
      current: currentFilter,
      onChanged: applyFilter,
    );
  }

  Future<void> openCardMenu(
    BuildContext cardContext,
    VideoItemListItemDto video,
    Offset globalPosition,
  ) async {
    final selected = await showAppActionMenu<bool>(
      context: cardContext,
      globalPosition: globalPosition,
      drawerKey: const Key('mobile-pornbox-card-menu'),
      items: <AppMenuItem<bool>>[
        AppMenuItem(
          key: const Key('mobile-pornbox-card-menu-select-item'),
          value: true,
          label: AppLocalizations.of(cardContext).videoSelect,
          icon: Icons.check_circle_outline,
        ),
      ],
    );
    if (selected != true || !mounted) {
      return;
    }
    enterSelection(initial: video.id);
  }
}
