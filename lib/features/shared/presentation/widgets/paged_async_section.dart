import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';

/// 分页 `AsyncNotifier` 的通用「四态骨架」：
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
/// 使用范式：
///
/// ```dart
/// PagedAsyncSection<MediaBrowseState, MediaListItemDto>(
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
class PagedAsyncSection<S, T> extends StatelessWidget {
  const PagedAsyncSection({
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
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final AsyncValue<S> asyncState;
  final PagedListState<T> Function(S state) pagedOf;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// 每条 item 之间的间距（附着在 item 底部 padding 上）。
  final double itemSpacing;

  final String initialErrorMessage;
  final String emptyMessage;

  final VoidCallback onReload;
  final VoidCallback onLoadMore;

  /// 首屏错误重试按钮的稳定 Key（供测试锚定）。
  final Key? initialRetryKey;

  final int skeletonLineCount;

  /// footer 与最后一条 item 之间的额外间距；不传走 `spacing.md`。
  final double? footerTopSpacing;

  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    if (asyncState.isLoading && !asyncState.hasValue) {
      return AppSectionSkeleton(lineCount: skeletonLineCount);
    }
    if (asyncState.hasError && !asyncState.hasValue) {
      return AppEmptyState(
        message: initialErrorMessage,
        onRetry: onReload,
        retryKey: initialRetryKey,
      );
    }
    final paged = pagedOf(asyncState.requireValue);
    if (paged.items.isEmpty) {
      return AppEmptyState(message: emptyMessage);
    }

    final spacing = context.appSpacing;
    final items = paged.items;
    final showFooter =
        paged.isLoadingMore || paged.loadMoreErrorMessage != null;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: itemSpacing),
            child: itemBuilder(context, items[i], i),
          ),
        if (showFooter) ...[
          SizedBox(height: footerTopSpacing ?? spacing.md),
          AppPagedLoadMoreFooter(
            isLoading: paged.isLoadingMore,
            errorMessage: paged.loadMoreErrorMessage,
            onRetry: onLoadMore,
          ),
        ],
      ],
    );
  }
}
