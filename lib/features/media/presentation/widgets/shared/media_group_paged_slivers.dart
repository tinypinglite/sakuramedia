import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';

/// 媒体分组列表共用的 sliver 壳：描述、分页四态、骨架、加载更多页脚和底部留白。
List<Widget> mediaGroupPagedSlivers<T>({
  required BuildContext context,
  required AsyncValue<PagedListState<T>> asyncState,
  required List<T> skeletonItems,
  required Widget Function(BuildContext context, T item, int index) itemBuilder,
  required String initialErrorMessage,
  required String emptyMessage,
  required Key initialRetryKey,
  required VoidCallback onReload,
  required VoidCallback onLoadMore,
  required PagedLoadMoreFooterSnapshot? Function(WidgetRef ref) watchFooter,
  required void Function(WidgetRef ref) footerLoadMore,
  String? description,
  Key? descriptionKey,
}) {
  final spacing = context.appSpacing;
  return [
    if (description != null)
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(bottom: spacing.md),
          child: Text(
            description,
            key: descriptionKey,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ),
      ),
    SliverPagedAsyncSection<PagedListState<T>, T>(
      asyncState: asyncState,
      pagedOf: (state) => state,
      itemSpacing: spacing.lg,
      initialErrorMessage: initialErrorMessage,
      emptyMessage: emptyMessage,
      skeletonBuilder: (context) => AppSkeletonizer(
        enabled: true,
        child: Column(
          children: [
            for (var index = 0; index < skeletonItems.length; index++) ...[
              if (index > 0) SizedBox(height: spacing.lg),
              itemBuilder(context, skeletonItems[index], index),
            ],
          ],
        ),
      ),
      initialRetryKey: initialRetryKey,
      onReload: onReload,
      onLoadMore: onLoadMore,
      itemBuilder: itemBuilder,
      showLoadMoreFooter: false,
    ),
    PagedLoadMoreFooterSliver(
      watchFooter: watchFooter,
      onLoadMore: footerLoadMore,
    ),
    SliverToBoxAdapter(child: SizedBox(height: spacing.xxl)),
    ...bottomSafeAreaSliver(context),
  ];
}
