# data-loading —— 刷新 / 分页 / 多选 / 交错布局 / 文字

列表页数据流路径上的公用原子件。**每一个都是"你写列表 / 网格必然要接的胶水"**,别自己拧一套。

## AppPullToRefresh
- **路径**: `lib/widgets/app_pull_to_refresh.dart`
- **用途**: 通用下拉刷新(桌面/移动都能用的 `RefreshIndicator` 薄壳,已按 token 调色)。
- **required**: `onRefresh: Future<void> Function()` · `child`(通常是 `ListView` / `CustomScrollView`)
- **可选**: `notificationPredicate`(默认 Flutter 默认)
- **何时用**: 需要下拉刷新的滚动容器。
- **何时不用**: 需要"下拉刷新 + 内嵌 sliver"更精细组合时 → `AppAdaptiveRefreshScrollView`。

## AppAdaptiveRefreshScrollView
- **路径**: `lib/widgets/app_adaptive_refresh_scroll_view.dart`
- **用途**: `CustomScrollView + AppPullToRefresh` 的组合封装,直接吃 slivers。
- **required**: `onRefresh` · `slivers: List<Widget>`
- **可选**: `controller` · `physics` · `cacheExtent`
- **何时用**: 页面本身是"多个 sliver 拼起来的"(SliverAppBar + SliverPersistentHeader + SliverList 之类),仍要下拉刷新。

## AppPagedLoadMoreFooter
- **路径**: `lib/widgets/app_paged_load_more_footer.dart`
- **用途**: 分页列表尾部"加载中 / 加载失败 + 重试"两态脚。
- **required**: `isLoading` · `errorMessage` · `onRetry`
- **何时用**: 所有 `PagedLoadController` 驱动的列表尾巴。
- **约束(重要)**: 分页失败**保留原列表并提供重试**,不整页红字。见 `lib/widgets/CLAUDE.md` "状态反馈一致"。

## AppFilterTotalHeader
- **路径**: `lib/widgets/app_filter_total_header.dart`
- **用途**: 列表顶部"筛选栏 + 总数条"通用行(左 leading + 右总数,可插 trailing)。
- **required**: `leading` · `totalText`
- **可选**: `totalKey` · `trailing`
- **何时用**: 筛选驱动列表的顶部 summary,比如 `MovieFilterToolbar` 下方 "共 xxx 部" 这条。

## AppText
- **路径**: `lib/widgets/app_text.dart`
- **用途**: 走 token 的统一文字组件。**能用它就用它**,别 `Text(..., style: TextStyle(fontSize: ..., color: ...))`。
- **required**: `data`(位置参数) · `size: AppTextSize`
- **可选**: `weight: AppTextWeight`(默认 regular) · `tone: AppTextTone`(默认 primary) · `maxLines` · `overflow` · `textAlign` · `softWrap`
- **何时不用**: 需要复杂 rich text 组合 → `resolveAppTextStyle(...)` 拿 `TextStyle` 自己拼 `RichText`。**任何情况下都别裸 fontSize / Color**,否则 `theme_source_guard_test` 直接红。

## MultiSelectStateMixin
- **路径**: `lib/widgets/selection/multi_select_state_mixin.dart`
- **用途**: 多选状态机 mixin(`Set<int> selectedIds`、`toggle` / `clear` / `enterSelectionMode` / `isSelected` 等)。
- **何时用**: 任何"点长按进入多选、勾选、批量操作"网格。**别自己维护一份 selectedIds**。
- **配合**: 卡片对外暴露 `selectionMode` + `isSelected` + `onSelectedChanged`;顶部批量条件用 `ClipSelectionStatusBar` 之类的域内件(见 [domain-widgets.md](./domain-widgets.md))。

## SelectionCheckBadge
- **路径**: `lib/widgets/selection/selection_check_badge.dart`
- **用途**: 选中态右上角勾选标记(圆底 + 对勾)。
- **required**: `isSelected`
- **何时用**: 多选模式下,卡片右上角覆盖。已经在 `ClipGridCard` / `ClipCoverCard` / `CollectionMemberCard` 等用了——新增可选卡片直接复用,**别再自己画一个**。

## StaggeredLayout(相关辅助)
- **路径**: `lib/widgets/layout/staggered_layout.dart`
- **用途**: 交错网格的**排布计算器**(`StaggeredTilePlacement` / `StaggeredLayoutResult`)。给业务侧一个"按 tile 元数据算出瀑布位置"的工具。
- **何时用**: 已经有裸 GridView 满足不了(如某些图集混合宽/高 tile),需要瀑布布局时。**不是 widget** 而是**布局工具类**。
- **何时不用**: 普通等宽卡片网格 → 直接用 `MovieSummaryGrid` / `ActorSummaryGrid` / `MomentGrid` 那种域内网格,它们已经用 `LayoutBuilder` 算列了(见 `lib/widgets/CLAUDE.md` "网格四态容器")。

---

## 相关约定

- **网格四态**:骨架 → 错误 → 空态 → 内容,顺序固定。骨架 / 错误 / 空态用 [feedback.md](./feedback.md) 里的原子件。
- **列宽自适应**:`LayoutBuilder` + `((w + spacing) / (target + spacing)).floor()` 计算列数并钳位;target 一般用 token(如 `movieCardTargetWidth`),不要传裸值 220 / 280 / 300。
- 想抽新的"选择系"胶水前,看看 `MultiSelectStateMixin` 能不能扩,别在业务侧写第二份多选状态机。
