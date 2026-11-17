import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';

/// 「加载更多」页脚的订阅快照：只包含决定渲染的两个字段。
typedef PagedLoadMoreFooterSnapshot = ({bool isLoading, String? errorMessage});

/// 中立化 loadMore 状态：把 [PagedListState] 的翻页 loading / 失败清成中性值，
/// 供列表本体的 `select` 使用——翻页状态由独立的 [PagedLoadMoreFooterSliver]
/// 订阅，于是「开始 / 结束加载」只重建页脚。
///
/// 只有 `select` 出的值自带内容相等（[PagedListState] / record）时才生效；
/// 整个 section state 需要该 state 自己实现 `==`，否则仍会重建。
/// 中立化后的快照不再反映真实翻页状态，需要实时值的地方用 `ref.read`。
PagedListState<T> withoutLoadMoreStatus<T>(PagedListState<T> paged) =>
    paged.isLoadingMore || paged.loadMoreErrorMessage != null
    ? paged.copyWith(isLoadingMore: false, loadMoreErrorMessage: null)
    : paged;

/// 页脚间距档位（theme spacing token 名），在 build 时按 context 求值。
enum PagedFooterSpacing {
  none,
  sm,
  md,
  lg,
  xl,
}

double _resolveSpacing(BuildContext context, PagedFooterSpacing spacing) {
  final tokens = context.appSpacing;
  return switch (spacing) {
    PagedFooterSpacing.none => 0,
    PagedFooterSpacing.sm => tokens.sm,
    PagedFooterSpacing.md => tokens.md,
    PagedFooterSpacing.lg => tokens.lg,
    PagedFooterSpacing.xl => tokens.xl,
  };
}

/// 标准 footer 判定：无数据（尚未加载 / 列表为空）→ null（整段隐藏）；
/// 有数据时取 loadMore 的「进行中 / 失败」状态，空闲返回中性快照。
///
/// 与 [SliverPagedAsyncSection] 内置 footer 的展示条件一致：仅在有数据时出现，
/// 「加载中 / 失败」才占用高度。
PagedLoadMoreFooterSnapshot? pagedLoadMoreFooterSnapshot<T>(
  PagedListState<T>? paged,
) {
  if (paged == null || paged.items.isEmpty) {
    return null;
  }
  return (
    isLoading: paged.isLoadingMore,
    errorMessage: paged.loadMoreErrorMessage,
  );
}

/// 分页列表共用的「加载更多」页脚。
///
/// 在 widget 自己的 `select` 里独立订阅 loadMore 的 loading / 失败状态，
/// 只在「加载中 / 失败」时渲染 [AppPagedLoadMoreFooter]，于是翻页状态翻转
/// 只重建页脚，不重建列表本体（列表本体的 `select` 用 [withoutLoadMoreStatus]
/// 把这两个字段清成中性值）：
///
/// - [watchFooter]：在 widget 自己的 build 里执行 `ref.watch(provider.select(...))`。
///   返回 null 表示整段隐藏（无数据 / 页面自定义的隐藏条件）。
/// - [onLoadMore]：重试 / 加载更多回调，拿组件自己的 `ref` 读对应 notifier。
/// - [topSpacing]：可见时与列表的间距，默认 `md`。
/// - [bottomSpacing]：可见元素之后的底部留白（通知 / 任务列表用 `xl`）。
/// - [hiddenSpacing]：隐藏时保留的底部边距（切片、PornBox 等保留原语义）。
/// - [padWhenIdle]：空闲（无 loading 也无失败）时仍保留上下边距，用于通知 /
///   任务列表这类「footer 常驻、内容自隐」的页面。
class PagedLoadMoreFooterSliver extends ConsumerWidget {
  const PagedLoadMoreFooterSliver({
    super.key,
    required this.watchFooter,
    required this.onLoadMore,
    this.topSpacing,
    this.bottomSpacing = PagedFooterSpacing.none,
    this.hiddenSpacing = PagedFooterSpacing.none,
    this.padWhenIdle = false,
  });

  final PagedLoadMoreFooterSnapshot? Function(WidgetRef ref) watchFooter;
  final void Function(WidgetRef ref) onLoadMore;
  final PagedFooterSpacing? topSpacing;
  final PagedFooterSpacing bottomSpacing;
  final PagedFooterSpacing hiddenSpacing;
  final bool padWhenIdle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final footer = watchFooter(ref);
    final active =
        footer != null && (footer.isLoading || footer.errorMessage != null);
    if (!active && !(footer != null && padWhenIdle)) {
      return _hiddenSliver(context);
    }
    return SliverToBoxAdapter(
      child: Column(
        children: [
          SizedBox(
            height: _resolveSpacing(
              context,
              topSpacing ?? PagedFooterSpacing.md,
            ),
          ),
          if (active)
            AppPagedLoadMoreFooter(
              isLoading: footer.isLoading,
              errorMessage: footer.errorMessage,
              onRetry: () => onLoadMore(ref),
            ),
          SizedBox(height: _resolveSpacing(context, bottomSpacing)),
        ],
      ),
    );
  }

  Widget _hiddenSliver(BuildContext context) {
    final spacing = _resolveSpacing(context, hiddenSpacing);
    if (spacing <= 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(child: SizedBox(height: spacing));
  }
}
