import 'dart:async';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/video_placeholders.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_glass_search_field.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_wrap.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

class DesktopVideoCollectionsPage extends ConsumerStatefulWidget {
  const DesktopVideoCollectionsPage({super.key});

  @override
  ConsumerState<DesktopVideoCollectionsPage> createState() =>
      _DesktopVideoCollectionsPageState();
}

class _DesktopVideoCollectionsPageState
    extends ConsumerState<DesktopVideoCollectionsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showVideoCollectionDialog(context);
    if (created != null) {
      unawaited(ref.read(videoCollectionsOverviewProvider.notifier).refresh());
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    VideoCollectionDto collection,
  ) async {
    final updated = await showVideoCollectionDialog(
      context,
      existing: collection,
    );
    if (updated != null) {
      unawaited(ref.read(videoCollectionsOverviewProvider.notifier).refresh());
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    VideoCollectionDto collection,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.videoDeleteCollectionTitle,
      message: l10n.videoDeleteCollectionConfirmMessage(collection.name),
      danger: true,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref
          .read(videoCollectionsApiProvider)
          .deleteCollection(collection.id);
      await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
      if (context.mounted) {
        showToast(l10n.videoCollectionDeleted, tone: AppToastTone.success);
      }
    } catch (_) {
      if (context.mounted) {
        showToast(l10n.videoDeleteFailedLater, tone: AppToastTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(videoCollectionsOverviewProvider);
    final notifier = ref.read(videoCollectionsOverviewProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return AppPageRefreshScope(
      onRefresh: notifier.refresh,
      // 页面边距由桌面 shell 的 AppPageInsets.desktopStandard (24px) 统一提供，
      // 此处不再叠加 EdgeInsets.all(spacing.lg)，否则合计 40px 比合集详情等
      // 同类页明显宽（详情页此前已修，这里是漏掉的一处）。
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
                      onTap: () => _create(context, ref),
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
              slivers: [_buildBody(context, ref, async)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
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
      // 懒加载：合集上千时不首帧构建全部卡片与封面图请求。
      child: AppAdaptiveCardWrapSliver<VideoCollectionDto>(
        gridKey: const Key('video-collections-grid'),
        items: collections,
        orientation: AppCardGridOrientation.landscape,
        itemBuilder: (context, collection, _) => CollectionCard.video(
          collection: collection,
          onTap: () => context.pushDesktopVideoCollectionDetail(
            collectionId: collection.id,
          ),
          onEdit: () => _edit(context, ref, collection),
          onDelete: () => _delete(context, ref, collection),
        ),
      ),
    );
  }
}
