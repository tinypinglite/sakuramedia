import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/clip_collection_placeholders.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_overview_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clip_mutation_events_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_search_field.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_wrap.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

/// 移动端切片合集列表页：全部合集网格 + 新建 / 编辑 / 删除（编辑与确认走底部抽屉）。
class MobileClipCollectionsPage extends ConsumerStatefulWidget {
  const MobileClipCollectionsPage({super.key});

  @override
  ConsumerState<MobileClipCollectionsPage> createState() =>
      _MobileClipCollectionsPageState();
}

class _MobileClipCollectionsPageState
    extends ConsumerState<MobileClipCollectionsPage> {
  bool _refreshScheduled = false;
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 详情页（压在本页之上）增删 / 改名后，合集卡的封面、计数、名称可能变化；
  /// 用微任务合并一轮内的多次信号成一次整列表刷新。
  void _onMutation(ClipMutationChange _) {
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    scheduleMicrotask(() {
      _refreshScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(ref.read(clipCollectionsOverviewProvider.notifier).refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ClipMutationChange>>(clipMutationEventsProvider, (
      previous,
      next,
    ) {
      final change = next.value;
      if (change != null) {
        _onMutation(change);
      }
    });

    final spacing = context.appSpacing;
    final colors = context.appColors;
    final async = ref.watch(clipCollectionsOverviewProvider);
    final l10n = AppLocalizations.of(context);

    return ColoredBox(
      key: const Key('mobile-clip-collections-page'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: spacing.sm),
            child: AppSearchField(
              fieldKey: const Key('mobile-clip-collections-search-field'),
              controller: _searchController,
              hintText: l10n.clipCollectionSearchHint,
              onChanged: (value) =>
                  setState(() => _keyword = value.trim().toLowerCase()),
              clearKey: const Key('mobile-clip-collections-search-clear'),
            ),
          ),
          Expanded(child: _buildBody(context, async)),
          Container(
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-clip-collections-create-button'),
                label: l10n.clipCollectionCreate,
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed: _createCollection,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<ClipCollectionDto>> async,
  ) {
    final isLoading = async.isLoading && async.value == null;
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final allCollections = isLoading
        ? clipCollectionPlaceholders()
        : async.value ?? const <ClipCollectionDto>[];
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
        key: const Key('mobile-clip-collections-scroll'),
        onRefresh: ref.read(clipCollectionsOverviewProvider.notifier).refresh,
        slivers: <Widget>[
          if (async.hasError && allCollections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                message: apiErrorMessage(
                  async.error!,
                  fallback: l10n.clipCollectionLoadFailed,
                  l10n: l10n,
                ),
              ),
            )
          else if (allCollections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(message: l10n.clipCollectionEmptyMobile),
            )
          else if (collections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(message: l10n.clipCollectionNoMatch),
            )
          else
            SliverPadding(
              // 横向缩进由 shell 8px body padding 统一提供，此处只补上下留白。
              padding: EdgeInsets.symmetric(vertical: spacing.md),
              // 懒加载：合集上千时不首帧构建全部卡片与封面图请求。
              sliver: AppAdaptiveCardWrapSliver<ClipCollectionDto>(
                gridKey: const Key('mobile-clip-collections-grid'),
                items: collections,
                orientation: AppCardGridOrientation.landscape,
                itemBuilder: (context, collection, _) => CollectionCard.clip(
                  key: Key('mobile-clip-collection-card-${collection.id}'),
                  collection: collection,
                  onTap: () => MobileClipCollectionDetailRouteData(
                    collectionId: collection.id,
                  ).push(context),
                  onEdit: () => _editCollection(collection),
                  onDelete: () => _deleteCollection(collection),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createCollection() async {
    final created = await showCreateClipCollectionDialog(
      context,
      presentation: ClipCollectionEditPresentation.bottomDrawer,
    );
    if (!mounted || created == null) {
      return;
    }
    ref
        .read(clipCollectionsOverviewProvider.notifier)
        .insertCollection(created);
    showToast(
      AppLocalizations.of(context).clipCollectionCreatedToast,
      tone: AppToastTone.success,
    );
  }

  Future<void> _editCollection(ClipCollectionDto collection) async {
    final updated = await showEditClipCollectionDialog(
      context,
      collection: collection,
      presentation: ClipCollectionEditPresentation.bottomDrawer,
    );
    if (!mounted || updated == null) {
      return;
    }
    ref
        .read(clipCollectionsOverviewProvider.notifier)
        .replaceCollection(updated);
    showToast(
      AppLocalizations.of(context).commonSaved,
      tone: AppToastTone.success,
    );
  }

  Future<void> _deleteCollection(ClipCollectionDto collection) async {
    final l10n = AppLocalizations.of(context);
    final name = collection.name.trim().isEmpty
        ? l10n.clipCollectionUnnamed
        : '“${collection.name.trim()}”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.clipCollectionDeleteTitle,
      message: l10n.clipCollectionDeleteMessage(name),
      danger: true,
      confirmLabel: l10n.commonDelete,
      dialogKey: const Key('mobile-clip-collection-delete-drawer'),
      confirmKey: const Key('mobile-clip-collection-delete-confirm-button'),
    );
    if (!mounted || !confirmed) {
      return;
    }
    try {
      await ref
          .read(clipCollectionsApiProvider)
          .deleteCollection(collectionId: collection.id);
      ref
          .read(clipCollectionsOverviewProvider.notifier)
          .removeCollection(collection.id);
      if (mounted) {
        showToast(l10n.clipCollectionDeletedToast, tone: AppToastTone.success);
      }
    } catch (error) {
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.clipCollectionDeleteFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }
}
