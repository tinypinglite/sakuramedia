import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/video_placeholders.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/forms/app_glass_search_field.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_wrap.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

/// 视频合集列表共享内容：搜索、新建/编辑/删除、mutation 刷新和合集网格。
class VideoCollectionsContent extends ConsumerStatefulWidget {
  const VideoCollectionsContent({super.key, required this.mobile});

  final bool mobile;

  @override
  ConsumerState<VideoCollectionsContent> createState() =>
      _VideoCollectionsContentState();
}

class _VideoCollectionsContentState
    extends ConsumerState<VideoCollectionsContent> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  bool _refreshScheduled = false;

  bool get _mobile => widget.mobile;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onMutation(VideoMutationChange _) {
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    scheduleMicrotask(() {
      _refreshScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(ref.read(videoCollectionsOverviewProvider.notifier).refresh());
    });
  }

  Future<void> _create() async {
    final created = await showVideoCollectionDialog(
      context,
      presentation: _mobile
          ? VideoCollectionEditPresentation.bottomDrawer
          : VideoCollectionEditPresentation.dialog,
    );
    if (!mounted || created == null) {
      return;
    }
    await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
    if (_mobile && mounted) {
      showToast(
        AppLocalizations.of(context).videoCollectionCreated,
        tone: AppToastTone.success,
      );
    }
  }

  Future<void> _edit(VideoCollectionDto collection) async {
    final updated = await showVideoCollectionDialog(
      context,
      existing: collection,
      presentation: _mobile
          ? VideoCollectionEditPresentation.bottomDrawer
          : VideoCollectionEditPresentation.dialog,
    );
    if (!mounted || updated == null) {
      return;
    }
    await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
    if (_mobile && mounted) {
      showToast(
        AppLocalizations.of(context).commonSaved,
        tone: AppToastTone.success,
      );
    }
  }

  Future<void> _delete(VideoCollectionDto collection) async {
    final l10n = AppLocalizations.of(context);
    final name = collection.name.trim();
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.videoDeleteCollectionTitle,
      message: _mobile
          ? l10n.videoDeleteCollectionConfirmMessageNamed(
              name.isEmpty ? l10n.videoGenericCollection : '“$name”',
            )
          : l10n.videoDeleteCollectionConfirmMessage(collection.name),
      danger: true,
      confirmLabel: l10n.commonDelete,
      dialogKey: _mobile
          ? const Key('mobile-video-collection-delete-drawer')
          : null,
      confirmKey: _mobile
          ? const Key('mobile-video-collection-delete-confirm-button')
          : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    try {
      await ref
          .read(videoCollectionsApiProvider)
          .deleteCollection(collection.id);
      await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
      if (mounted) {
        showToast(l10n.videoCollectionDeleted, tone: AppToastTone.success);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        _mobile
            ? apiErrorMessage(
                error,
                fallback: l10n.videoDeleteFailed,
                l10n: l10n,
              )
            : l10n.videoDeleteFailedLater,
        tone: AppToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<VideoMutationChange>>(videoMutationEventsProvider, (
      previous,
      next,
    ) {
      final change = next.value;
      if (change != null) {
        _onMutation(change);
      }
    });

    final async = ref.watch(videoCollectionsOverviewProvider);
    final notifier = ref.read(videoCollectionsOverviewProvider.notifier);
    final l10n = AppLocalizations.of(context);

    if (_mobile) {
      final spacing = context.appSpacing;
      return ColoredBox(
        key: const Key('mobile-video-collections-page'),
        color: Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: spacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: AppGlassSearchField(
                      fieldKey: const Key(
                        'mobile-video-collections-search-field',
                      ),
                      controller: _searchController,
                      hintText: l10n.videoSearchCollections,
                      onChanged: (value) =>
                          setState(() => _keyword = value.trim().toLowerCase()),
                      clearKey: const Key(
                        'mobile-video-collections-search-clear',
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  AppGlassIconButton(
                    key: const Key('mobile-video-collections-create-button'),
                    tooltip: l10n.videoNewCollection,
                    icon: Icons.add_rounded,
                    onPressed: _create,
                  ),
                ],
              ),
            ),
            Expanded(child: _buildMobileBody(context, async)),
          ],
        ),
      );
    }

    return AppPageRefreshScope(
      onRefresh: notifier.refresh,
      child: Column(
        key: const Key('video-collections-page'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassBackdropGroup(
            child: Row(
              children: [
                Expanded(
                  child: AppGlassSearchField(
                    fieldKey: const Key('video-collections-search-field'),
                    controller: _searchController,
                    hintText: l10n.videoSearchCollections,
                    onChanged: (value) =>
                        setState(() => _keyword = value.trim().toLowerCase()),
                    clearKey: const Key('video-collections-search-clear'),
                  ),
                ),
                SizedBox(width: context.appSpacing.md),
                AppGlassHeaderGroup(
                  children: <Widget>[
                    AppGlassHeaderButton(
                      key: const Key('video-collections-create-button'),
                      icon: Icons.add_rounded,
                      label: l10n.videoNewCollection,
                      onTap: _create,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: context.appSpacing.lg),
          Expanded(
            child: CustomScrollView(
              key: const Key('video-collections-scroll'),
              slivers: [_buildDesktopBody(context, async)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(
    BuildContext context,
    AsyncValue<List<VideoCollectionDto>> async,
  ) {
    final l10n = AppLocalizations.of(context);
    final isLoading = async.isLoading && async.value == null;
    if (!isLoading && async.hasError && async.value == null) {
      return SliverToBoxAdapter(
        child: AppEmptyState(
          message: apiErrorMessage(
            async.error!,
            fallback: l10n.videoCollectionsLoadFailed,
            l10n: l10n,
          ),
        ),
      );
    }
    final allCollections = isLoading
        ? videoCollectionPlaceholders(count: 4)
        : async.value ?? const <VideoCollectionDto>[];
    if (allCollections.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(message: l10n.videoCollectionsEmpty),
      );
    }
    final collections = isLoading || _keyword.isEmpty
        ? allCollections
        : allCollections
              .where(
                (collection) =>
                    collection.name.toLowerCase().contains(_keyword),
              )
              .toList(growable: false);
    if (collections.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(message: l10n.videoCollectionsNoMatch),
      );
    }
    return AppSkeletonizer.sliver(
      enabled: isLoading,
      child: AppAdaptiveCardWrapSliver<VideoCollectionDto>(
        gridKey: const Key('video-collections-grid'),
        items: collections,
        orientation: AppCardGridOrientation.landscape,
        itemBuilder: (context, collection, _) => CollectionCard.video(
          collection: collection,
          onTap: () => context.pushDesktopVideoCollectionDetail(
            collectionId: collection.id,
          ),
          onEdit: () => _edit(collection),
          onDelete: () => _delete(collection),
        ),
      ),
    );
  }

  Widget _buildMobileBody(
    BuildContext context,
    AsyncValue<List<VideoCollectionDto>> async,
  ) {
    final isLoading = async.isLoading && async.value == null;
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final allCollections = isLoading
        ? videoCollectionPlaceholders()
        : async.value ?? const <VideoCollectionDto>[];
    final collections = isLoading || _keyword.isEmpty
        ? allCollections
        : allCollections
              .where(
                (collection) =>
                    collection.name.toLowerCase().contains(_keyword),
              )
              .toList(growable: false);
    return AppSkeletonizer(
      enabled: isLoading,
      child: AppAdaptiveRefreshScrollView(
        key: const Key('mobile-video-collections-scroll'),
        onRefresh: ref.read(videoCollectionsOverviewProvider.notifier).refresh,
        slivers: <Widget>[
          if (async.hasError && allCollections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                message: apiErrorMessage(
                  async.error!,
                  fallback: l10n.videoCollectionsLoadFailed,
                  l10n: l10n,
                ),
              ),
            )
          else if (allCollections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(message: l10n.videoCollectionsEmptyMobile),
            )
          else if (collections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(message: l10n.videoCollectionsNoMatch),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(vertical: spacing.md),
              sliver: AppAdaptiveCardWrapSliver<VideoCollectionDto>(
                gridKey: const Key('mobile-video-collections-grid'),
                items: collections,
                orientation: AppCardGridOrientation.landscape,
                itemBuilder: (context, collection, _) => CollectionCard.video(
                  key: Key('mobile-video-collection-card-${collection.id}'),
                  collection: collection,
                  coverBackdrop: true,
                  onTap: () => MobileVideoCollectionDetailRouteData(
                    collectionId: collection.id,
                  ).push(context),
                  onEdit: () => _edit(collection),
                  onDelete: () => _delete(collection),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
