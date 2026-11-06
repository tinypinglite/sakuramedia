import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';

/// 分页 `AsyncNotifier` 的 Sliver「四态骨架」：
///
/// 1. `asyncState.isLoading && !hasValue` → 首次加载，[skeletonBuilder]
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
    required this.skeletonBuilder,
    this.footerTopSpacing,
    this.emptyBuilder,
    this.showLoadMoreFooter = true,
  });

  final AsyncValue<S> asyncState;
  final PagedListState<T> Function(S state) pagedOf;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double itemSpacing;
  final String initialErrorMessage;
  final String emptyMessage;
  final VoidCallback onReload;
  final VoidCallback onLoadMore;
  final Key? initialRetryKey;

  /// 首次加载骨架：传「占位数据 + 真实卡片」并用 `AppSkeletonizer` 灰化，
  /// 保证与数据到位后的列表同形。
  final WidgetBuilder skeletonBuilder;

  final double? footerTopSpacing;

  /// 自定义空态；不传走 [AppEmptyState] + [emptyMessage]。
  ///
  /// 用于空态本身要带引导动作的场景——例如订阅管理页停在「缺资源」分段签且一条
  /// 都没有时，"没有卡住的订阅"是**好消息**，该顺手给一个「查看全部订阅」的去处，
  /// 而不是甩一行灰字。[emptyMessage] 仍需提供，作为无 builder 时的兜底文案。
  final WidgetBuilder? emptyBuilder;

  /// 是否渲染内置「加载更多」footer。
  ///
  /// 默认 true；传 false 时列表本体照常输出，但 loadMore 的 loading / 失败提示
  /// 不在这里渲染——调用方应自行追加 footer，并把 [asyncState] 中 loadMore 相关
  /// 字段清成中立值（如 `copyWith(isLoadingMore: false, loadMoreErrorMessage: null)`），
  /// 让「开始/结束加载」不再重建整个列表 sliver。
  final bool showLoadMoreFooter;

  @override
  Widget build(BuildContext context) {
    if (asyncState.isLoading && !asyncState.hasValue) {
      return SliverToBoxAdapter(child: skeletonBuilder(context));
    }
    if (asyncState.hasError && !asyncState.hasValue) {
      return SliverToBoxAdapter(
        child: AppErrorState(
          key: const Key('paged-async-error'),
          title: appL10n(context).baseActionFailed,
          message: initialErrorMessage,
          onRetry: onReload,
          retryKey: initialRetryKey,
        ),
      );
    }

    final paged = pagedOf(asyncState.requireValue);
    if (paged.items.isEmpty) {
      // 筛选失败且没有可保留的旧结果时，筛选头里的 AppFilterUpdateBar 已经
      // 提供失败说明和重试。这里不再叠加普通“暂无数据”空态，避免误导。
      if (paged.filterUpdate.hasFailed) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      final builder = emptyBuilder;
      return SliverToBoxAdapter(
        child: builder != null
            ? builder(context)
            : AppEmptyState(
                key: const Key('paged-async-empty'),
                message: emptyMessage,
              ),
      );
    }

    final spacing = context.appSpacing;
    final items = paged.items;
    final showFooter =
        showLoadMoreFooter &&
        (paged.isLoadingMore || paged.loadMoreErrorMessage != null);
    final delegate = SliverChildBuilderDelegate(
      (context, index) => Padding(
        padding: EdgeInsets.only(bottom: itemSpacing),
        child: itemBuilder(context, items[index], index),
      ),
      childCount: items.length,
      // 调用方没有行申请 keep-alive；AutomaticKeepAlive 只增加每行的元素开销。
      addAutomaticKeepAlives: false,
    );
    final itemSliver = SliverList(delegate: delegate);

    if (!showFooter) {
      return itemSliver;
    }

    // footer 高度不固定，单独放进 SliverMainAxisGroup，不与列表共用同一 sliver。
    return SliverMainAxisGroup(
      slivers: [
        itemSliver,
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: footerTopSpacing ?? spacing.md),
            child: AppPagedLoadMoreFooter(
              key: const Key('paged-async-load-more-footer'),
              isLoading: paged.isLoadingMore,
              errorMessage: paged.loadMoreErrorMessage,
              onRetry: onLoadMore,
              retryKey: const Key('paged-async-load-more-retry'),
            ),
          ),
        ),
      ],
    );
  }
}
