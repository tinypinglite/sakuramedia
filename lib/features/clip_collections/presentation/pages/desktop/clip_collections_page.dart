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
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_search_field.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_wrap.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

/// 切片合集列表页：全部合集网格 + 新建 / 编辑 / 删除。
class DesktopClipCollectionsPage extends ConsumerStatefulWidget {
  const DesktopClipCollectionsPage({super.key});

  @override
  ConsumerState<DesktopClipCollectionsPage> createState() =>
      _DesktopClipCollectionsPageState();
}

class _DesktopClipCollectionsPageState
    extends ConsumerState<DesktopClipCollectionsPage> {
  bool _refreshScheduled = false;
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 详情页（压在本页之上）增删 / 拖序 / 改名后，合集卡的封面、计数、名称可能变化；
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

    final async = ref.watch(clipCollectionsOverviewProvider);
    final notifier = ref.read(clipCollectionsOverviewProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return AppPageRefreshScope(
      onRefresh: notifier.refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.clipCollectionPageTitle,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              const Spacer(),
              AppTextButton(
                key: const Key('clip-collections-create-button'),
                label: l10n.clipCollectionCreate,
                size: AppTextButtonSize.small,
                onPressed: _createCollection,
              ),
            ],
          ),
          SizedBox(height: context.appSpacing.sm),
          AppSearchField(
            fieldKey: const Key('clip-collections-search-field'),
            controller: _searchController,
            hintText: l10n.clipCollectionSearchHint,
            onChanged: (value) =>
                setState(() => _keyword = value.trim().toLowerCase()),
            clearKey: const Key('clip-collections-search-clear'),
          ),
          SizedBox(height: context.appSpacing.lg),
          Expanded(child: _buildBody(context, async)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<ClipCollectionDto>> async,
  ) {
    final isLoading = async.isLoading && async.value == null;
    final l10n = AppLocalizations.of(context);
    if (!isLoading && async.hasError && async.value == null) {
      return AppEmptyState(
        message: apiErrorMessage(
          async.error!,
          fallback: l10n.clipCollectionLoadFailed,
          l10n: l10n,
        ),
      );
    }
    final allCollections = isLoading
        ? clipCollectionPlaceholders(count: 8)
        : async.value ?? const <ClipCollectionDto>[];
    if (allCollections.isEmpty) {
      return AppEmptyState(message: l10n.clipCollectionEmptyDesktop);
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
      return AppEmptyState(message: l10n.clipCollectionNoMatch);
    }

    final spacing = context.appSpacing;
    return AppSkeletonizer(
      enabled: isLoading,
      // 懒加载：合集上千时不首帧构建全部卡片与封面图请求。
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(bottom: spacing.lg),
            sliver: AppAdaptiveCardWrapSliver<ClipCollectionDto>(
              gridKey: const Key('clip-collections-grid'),
              items: collections,
              orientation: AppCardGridOrientation.landscape,
              itemBuilder: (context, collection, _) => CollectionCard.clip(
                key: Key('clip-collection-card-${collection.id}'),
                collection: collection,
                onTap: () => context.pushDesktopClipCollectionDetail(
                  collectionId: collection.id,
                ),
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
    final created = await showCreateClipCollectionDialog(context);
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
      confirmKey: const Key('clip-collection-delete-confirm-button'),
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
