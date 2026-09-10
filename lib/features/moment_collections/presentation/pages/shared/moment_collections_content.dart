import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_overview_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_cover_card.dart';

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
    final body = _buildBody(context, ref, async);
    if (isMobile) {
      return ColoredBox(
        key: const Key('mobile-moment-collections-page'),
        color: context.appColors.surfaceCard,
        child: Column(
          children: [
            Expanded(child: body),
            Padding(
              padding: EdgeInsets.all(context.appSpacing.md),
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
    return ColoredBox(
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
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<MomentCollectionDto>> async,
  ) {
    final collections = async.value ?? const <MomentCollectionDto>[];
    if (async.isLoading && async.value == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (async.hasError && collections.isEmpty) {
      return AppEmptyState(
        message: apiErrorMessage(async.error!, fallback: '合集暂时无法加载，请稍后重试'),
        retryKey: const Key('moment-collections-retry-button'),
        onRetry: () =>
            ref.read(momentCollectionsOverviewProvider.notifier).refresh(),
      );
    }
    if (collections.isEmpty) {
      return const AppEmptyState(message: '还没有时刻合集，创建一个开始整理吧');
    }
    final grid = SliverGrid(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isMobile ? 200 : 240,
        mainAxisSpacing: context.appSpacing.md,
        crossAxisSpacing: context.appSpacing.md,
        childAspectRatio: 1.2,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final collection = collections[index];
        return CollectionCoverCard(
          tapKey: Key('moment-collection-card-${collection.id}'),
          menuKey: Key('moment-collection-more-${collection.id}'),
          title: collection.name,
          count: collection.pointCount,
          coverUrl: collection.coverImage?.bestAvailableUrl,
          placeholderIcon: Icons.bookmarks_outlined,
          onTap: () => onOpenDetail(collection.id),
          onEdit: () => _edit(context, ref, collection: collection),
          onDelete: () => _delete(context, ref, collection),
        );
      }, childCount: collections.length),
    );
    return AppAdaptiveRefreshScrollView(
      key: const Key('moment-collections-scroll'),
      onRefresh: ref.read(momentCollectionsOverviewProvider.notifier).refresh,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(bottom: context.appSpacing.lg),
          sliver: grid,
        ),
      ],
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
      presentation: isMobile
          ? MomentCollectionEditPresentation.bottomDrawer
          : MomentCollectionEditPresentation.dialog,
    );
    if (result == null) return;
    final notifier = ref.read(momentCollectionsOverviewProvider.notifier);
    if (collection == null) {
      notifier.insertCollection(result);
      showToast('已创建时刻合集');
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
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除时刻合集',
      message: '确认删除“${collection.name}”？合集中的时刻不会被删除。',
      danger: true,
      confirmLabel: '删除',
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(momentCollectionsApiProvider)
          .deleteCollection(collectionId: collection.id);
      ref
          .read(momentCollectionsOverviewProvider.notifier)
          .removeCollection(collection.id);
      showToast('已删除时刻合集');
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '删除失败，请重试'));
    }
  }
}
