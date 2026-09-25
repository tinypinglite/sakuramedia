import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/moment_collection_placeholders.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_overview_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

/// 时刻合集列表内容：桌面网格页 / 移动子页两套壳共用同一份取数与卡片逻辑。
class MomentCollectionsContent extends ConsumerWidget {
  const MomentCollectionsContent({
    super.key,
    required this.isMobile,
    required this.onOpenDetail,
  });

  final bool isMobile;
  final ValueChanged<int> onOpenDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(momentCollectionMutationEventsProvider, (_, next) {
      if (next.value != null) {
        unawaited(
          ref.read(momentCollectionsOverviewProvider.notifier).refresh(),
        );
      }
    });
    final async = ref.watch(momentCollectionsOverviewProvider);
    if (isMobile) {
      return ColoredBox(
        key: const Key('mobile-moment-collections-page'),
        color: context.appColors.surfaceCard,
        child: Column(
          children: [
            Expanded(child: _buildMobileBody(context, ref, async)),
            Container(
              padding: EdgeInsets.all(context.appSpacing.md),
              decoration: BoxDecoration(
                color: context.appColors.surfaceCard,
                border: Border(
                  top: BorderSide(color: context.appColors.divider),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: AppButton(
                  key: const Key('mobile-moment-collections-create-button'),
                  label: '新建合集',
                  variant: AppButtonVariant.primary,
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _edit(context, ref),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return AppPageRefreshScope(
      onRefresh: ref.read(momentCollectionsOverviewProvider.notifier).refresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '时刻合集',
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
                  label: '新建合集',
                  size: AppTextButtonSize.small,
                  onPressed: () => _edit(context, ref),
                ),
              ],
            ),
            SizedBox(height: context.appSpacing.lg),
            Expanded(child: _buildDesktopBody(context, ref, async)),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<MomentCollectionDto>> async,
  ) {
    final spacing = context.appSpacing;
    final isLoading = async.isLoading && async.value == null;
    if (!isLoading && async.hasError && async.value == null) {
      return AppEmptyState(
        message: apiErrorMessage(
          async.error!,
          fallback: '合集暂时无法加载，请稍后重试',
        ),
      );
    }
    final collections = isLoading
        ? momentCollectionPlaceholders(count: 8)
        : async.value ?? const <MomentCollectionDto>[];
    if (collections.isEmpty) {
      return const AppEmptyState(message: '还没有合集，点右上角「新建合集」开始吧');
    }
    return AppSkeletonizer(
      enabled: isLoading,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GridView.builder(
            key: const Key('moment-collections-grid'),
            padding: EdgeInsets.only(bottom: spacing.lg),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: resolveAppCardGridColumnCount(
                context,
                width: constraints.maxWidth,
                spacing: spacing.md,
              ),
              mainAxisSpacing: spacing.md,
              crossAxisSpacing: spacing.md,
              childAspectRatio: 1.2,
            ),
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              return CollectionCard.moment(
                collection: collection,
                onTap: () => onOpenDetail(collection.id),
                onEdit: () => _edit(context, ref, collection: collection),
                onDelete: () => _delete(context, ref, collection),
              );
            },
          );
        },
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
    final collections = isLoading
        ? momentCollectionPlaceholders()
        : async.value ?? const <MomentCollectionDto>[];
    return AppSkeletonizer(
      enabled: isLoading,
      child: AppAdaptiveRefreshScrollView(
        key: const Key('moment-collections-scroll'),
        onRefresh: ref.read(momentCollectionsOverviewProvider.notifier).refresh,
        slivers: <Widget>[
          if (async.hasError && collections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                message: apiErrorMessage(
                  async.error!,
                  fallback: '合集暂时无法加载，请稍后重试',
                ),
              ),
            )
          else if (collections.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(message: '还没有合集，点下方「新建合集」开始吧'),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(vertical: spacing.md),
              sliver: AppAdaptiveCardSliver<MomentCollectionDto>(
                gridKey: const Key('mobile-moment-collections-grid'),
                items: collections,
                childAspectRatio: 1.25,
                itemBuilder: (context, collection, index) {
                  return CollectionCard.moment(
                    collection: collection,
                    onTap: () => onOpenDetail(collection.id),
                    onEdit: () => _edit(context, ref, collection: collection),
                    onDelete: () => _delete(context, ref, collection),
                  );
                },
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
    final result = await showMomentCollectionEditor(
      context,
      collection: collection,
    );
    if (result == null) return;
    final notifier = ref.read(momentCollectionsOverviewProvider.notifier);
    if (collection == null) {
      notifier.insertCollection(result);
      showToast('已创建合集');
    } else {
      notifier.replaceCollection(result);
      showToast('已保存');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MomentCollectionDto collection,
  ) async {
    final name =
        collection.name.trim().isEmpty ? '该合集' : '“${collection.name.trim()}”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除合集',
      message: '确认删除$name？只会删除合集本身，合集内的时刻不会被删除。',
      danger: true,
      confirmLabel: '删除',
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
      showToast('已删除合集');
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '删除失败，请重试'));
    }
  }
}
