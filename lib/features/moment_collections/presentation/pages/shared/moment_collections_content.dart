import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/moment_collection_placeholders.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_overview_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_search_field.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_wrap.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

/// 时刻合集列表内容：桌面网格页 / 移动子页两套壳共用同一份取数与卡片逻辑。
class MomentCollectionsContent extends ConsumerStatefulWidget {
  const MomentCollectionsContent({
    super.key,
    required this.isMobile,
    required this.onOpenDetail,
  });

  final bool isMobile;
  final ValueChanged<int> onOpenDetail;

  @override
  ConsumerState<MomentCollectionsContent> createState() =>
      _MomentCollectionsContentState();
}

class _MomentCollectionsContentState
    extends ConsumerState<MomentCollectionsContent> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(momentCollectionMutationEventsProvider, (_, next) {
      if (next.value != null) {
        unawaited(
          ref.read(momentCollectionsOverviewProvider.notifier).refresh(),
        );
      }
    });
    final async = ref.watch(momentCollectionsOverviewProvider);
    if (widget.isMobile) {
      return Column(
        key: const Key('mobile-moment-collections-page'),
        children: [
          Padding(
            padding: EdgeInsets.only(top: context.appSpacing.sm),
            child: AppSearchField(
              fieldKey: const Key('mobile-moment-collections-search-field'),
              controller: _searchController,
              hintText: l10n.momentCollectionSearchHint,
              onChanged: (value) =>
                  setState(() => _keyword = value.trim().toLowerCase()),
              clearKey: const Key('mobile-moment-collections-search-clear'),
            ),
          ),
          Expanded(child: _buildMobileBody(context, ref, async)),
          Container(
            padding: EdgeInsets.all(context.appSpacing.md),
            decoration: BoxDecoration(
              color: context.appColors.surfaceCard,
              border: Border(top: BorderSide(color: context.appColors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-moment-collections-create-button'),
                label: l10n.momentCollectionCreateTitle,
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _edit(context, ref),
              ),
            ),
          ),
        ],
      );
    }
    return AppPageRefreshScope(
      onRefresh: ref.read(momentCollectionsOverviewProvider.notifier).refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.momentCollectionSectionTitle,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              const Spacer(),
              AppTextButton(
                key: const Key('moment-collections-create-button'),
                label: l10n.momentCollectionCreateTitle,
                size: AppTextButtonSize.small,
                onPressed: () => _edit(context, ref),
              ),
            ],
          ),
          SizedBox(height: context.appSpacing.sm),
          AppSearchField(
            fieldKey: const Key('moment-collections-search-field'),
            controller: _searchController,
            hintText: l10n.momentCollectionSearchHint,
            onChanged: (value) =>
                setState(() => _keyword = value.trim().toLowerCase()),
            clearKey: const Key('moment-collections-search-clear'),
          ),
          SizedBox(height: context.appSpacing.lg),
          Expanded(child: _buildDesktopBody(context, ref, async)),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<MomentCollectionDto>> async,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final isLoading = async.isLoading && async.value == null;
    if (!isLoading && async.hasError && async.value == null) {
      return AppEmptyState(
        message: apiErrorMessage(
          async.error!,
          fallback: l10n.momentErrorCollectionLoadFailed,
          l10n: l10n,
        ),
      );
    }
    final allCollections = isLoading
        ? momentCollectionPlaceholders(count: 8)
        : async.value ?? const <MomentCollectionDto>[];
    if (allCollections.isEmpty) {
      return AppEmptyState(message: l10n.momentCollectionEmptyDesktop);
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
      return AppEmptyState(message: l10n.momentCollectionNoMatch);
    }
    return AppSkeletonizer(
      enabled: isLoading,
      // 懒加载：合集上千时不首帧构建全部卡片与封面图请求。
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(bottom: spacing.lg),
            sliver: AppAdaptiveCardWrapSliver<MomentCollectionDto>(
              gridKey: const Key('moment-collections-grid'),
              items: collections,
              orientation: AppCardGridOrientation.landscape,
              itemBuilder: (context, collection, _) => CollectionCard.moment(
                collection: collection,
                onTap: () => widget.onOpenDetail(collection.id),
                onEdit: () => _edit(context, ref, collection: collection),
                onDelete: () => _delete(context, ref, collection),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<MomentCollectionDto>> async,
  ) {
    final isLoading = async.isLoading && async.value == null;
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final allCollections = isLoading
        ? momentCollectionPlaceholders()
        : async.value ?? const <MomentCollectionDto>[];
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
        key: const Key('moment-collections-scroll'),
        onRefresh: ref.read(momentCollectionsOverviewProvider.notifier).refresh,
        slivers: <Widget>[
          if (async.hasError && allCollections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                message: apiErrorMessage(
                  async.error!,
                  fallback: l10n.momentErrorCollectionLoadFailed,
                  l10n: l10n,
                ),
              ),
            )
          else if (allCollections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(message: l10n.momentCollectionEmptyMobile),
            )
          else if (collections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(message: l10n.momentCollectionNoMatch),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(vertical: spacing.md),
              // 懒加载：合集上千时不首帧构建全部卡片与封面图请求。
              sliver: AppAdaptiveCardWrapSliver<MomentCollectionDto>(
                gridKey: const Key('mobile-moment-collections-grid'),
                items: collections,
                orientation: AppCardGridOrientation.landscape,
                itemBuilder: (context, collection, _) => CollectionCard.moment(
                  collection: collection,
                  onTap: () => widget.onOpenDetail(collection.id),
                  onEdit: () => _edit(context, ref, collection: collection),
                  onDelete: () => _delete(context, ref, collection),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    MomentCollectionDto? collection,
  }) async {
    final l10n = AppLocalizations.of(context);
    final result = await showMomentCollectionEditor(
      context,
      collection: collection,
    );
    if (result == null) return;
    final notifier = ref.read(momentCollectionsOverviewProvider.notifier);
    if (collection == null) {
      notifier.insertCollection(result);
      showToast(l10n.momentCollectionCreatedToast, tone: AppToastTone.success);
    } else {
      notifier.replaceCollection(result);
      showToast(l10n.commonSaved, tone: AppToastTone.success);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MomentCollectionDto collection,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = collection.name.trim().isEmpty
        ? l10n.momentCollectionUnnamed
        : '“${collection.name.trim()}”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.momentCollectionDeleteTitle,
      message: l10n.momentCollectionDeleteMessage(name),
      danger: true,
      confirmLabel: l10n.commonDelete,
      confirmKey: const Key('moment-collection-delete-confirm-button'),
    );
    if (!confirmed) return;
    try {
      await ref
          .read(momentCollectionsApiProvider)
          .deleteCollection(collectionId: collection.id);
      ref
          .read(momentCollectionsOverviewProvider.notifier)
          .removeCollection(collection.id);
      showToast(l10n.momentCollectionDeletedToast, tone: AppToastTone.success);
    } catch (error) {
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.momentErrorDeleteFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }
}
