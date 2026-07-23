import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';

/// 分页 `AsyncNotifier` 的 Sliver「四态骨架」：
///
/// 1. `asyncState.isLoading && !hasValue` → [AppSectionSkeleton]（首次加载）
/// 2. `asyncState.hasError && !hasValue`  → [AppEmptyState]（首次失败 + 重试）
/// 3. `paged.items.isEmpty`               → [AppEmptyState]（空态）
/// 4. 有数据                              → 逐条 [itemBuilder] + 底部
///    [AppPagedLoadMoreFooter]（loadMore 中 / 失败 才渲染）
///
/// 与 `PagedAsyncNotifierMixin` 对偶——`pagedOf` 从 S 中取出 [PagedListState<T>]，
/// [onReload] / [onLoadMore] 通常直接绑 `ref.read(...notifier).reload()` /
/// `.loadMore()`。
///
/// 必须直接放进 [CustomScrollView.slivers]，确保累计分页条目由 viewport 惰性构建。
/// 使用范式：
///
/// ```dart
/// SliverPagedAsyncSection<MediaBrowseState, MediaListItemDto>(
///   asyncState: ref.watch(mediaBrowseProvider),
///   pagedOf: (s) => s.paged,
///   itemBuilder: (context, item, _) => _MediaRow(item: item, ...),
///   itemSpacing: spacing.sm,
///   initialErrorMessage: '媒体列表加载失败，请稍后重试',
///   emptyMessage: '当前筛选下没有媒体记录',
///   onReload: () => unawaited(ref.read(mediaBrowseProvider.notifier).reload()),
///   onLoadMore: () => unawaited(ref.read(mediaBrowseProvider.notifier).loadMore()),
///   initialRetryKey: const Key('media-management-initial-retry-button'),
/// );
/// ```
///
/// 只构建视口附近的条目，避免把分页接口已经加载的
/// 所有 item 一次性挂进 Widget / RenderObject 树。调用方应把本组件直接放进
/// [CustomScrollView.slivers]，筛选头、页签等非列表内容使用
/// [SliverToBoxAdapter] 组合。
class SliverPagedAsyncSection<S, T> extends StatelessWidget {
  const SliverPagedAsyncSection({
    super.key,
    required this.asyncState,
    required this.pagedOf,
    required this.itemBuilder,
    required this.itemSpacing,
    required this.initialErrorMessage,
    required this.emptyMessage,
    required this.onReload,
    required this.onLoadMore,
    this.initialRetryKey,
    this.skeletonLineCount = 6,
    this.footerTopSpacing,
    this.fixedItemExtent,
  }) : assert(fixedItemExtent == null || fixedItemExtent > 0);

  final AsyncValue<S> asyncState;
  final PagedListState<T> Function(S state) pagedOf;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double itemSpacing;
  final String initialErrorMessage;
  final String emptyMessage;
  final VoidCallback onReload;
  final VoidCallback onLoadMore;
  final Key? initialRetryKey;
  final int skeletonLineCount;
  final double? footerTopSpacing;

  /// 单个列表内容的固定高度（不含 [itemSpacing]）。
  ///
  /// 传值后使用 [SliverFixedExtentList]，滚动条大跨度跳转时可以直接通过索引计算
  /// scroll offset，不必为已经离开视口的行做 dead-reckoning 测量。
  final double? fixedItemExtent;

  @override
  Widget build(BuildContext context) {
    if (asyncState.isLoading && !asyncState.hasValue) {
      return SliverToBoxAdapter(
        child: AppSectionSkeleton(lineCount: skeletonLineCount),
      );
    }
    if (asyncState.hasError && !asyncState.hasValue) {
      return SliverToBoxAdapter(
        child: AppEmptyState(
          message: initialErrorMessage,
          onRetry: onReload,
          retryKey: initialRetryKey,
        ),
      );
    }

    final paged = pagedOf(asyncState.requireValue);
    if (paged.items.isEmpty) {
      return SliverToBoxAdapter(child: AppEmptyState(message: emptyMessage));
    }

    final spacing = context.appSpacing;
    final items = paged.items;
    final showFooter =
        paged.isLoadingMore || paged.loadMoreErrorMessage != null;
    final delegate = SliverChildBuilderDelegate(
      (context, index) => Padding(
        padding: EdgeInsets.only(bottom: itemSpacing),
        child: itemBuilder(context, items[index], index),
      ),
      childCount: items.length,
    );
    final itemSliver =
        fixedItemExtent == null
            ? SliverList(delegate: delegate)
            : SliverFixedExtentList(
              itemExtent: fixedItemExtent! + itemSpacing,
              delegate: delegate,
            );

    if (!showFooter) {
      return itemSliver;
    }

    // footer 高度并不固定，必须与固定尺寸 item sliver 分开，避免破坏滚动范围估算。
    return SliverMainAxisGroup(
      slivers: [
        itemSliver,
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: footerTopSpacing ?? spacing.md),
            child: AppPagedLoadMoreFooter(
              isLoading: paged.isLoadingMore,
              errorMessage: paged.loadMoreErrorMessage,
              onRetry: onLoadMore,
            ),
          ),
        ),
      ],
    );
  }
}
