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

## AppAdaptiveCardGrid&lt;T&gt;
- **路径**: `lib/widgets/app_adaptive_card_grid.dart`
- **用途**: **四态卡片网格的唯一入口**——按 `((width+spacing)/(target+spacing)).floor()` 算列 + 「骨架 → 错误 → 空 → 内容」四态壳一次封死。消除 movies / actors / rankings / videos 四份网格的 copy-paste,新网格**别再手写 `LayoutBuilder + GridView.builder`**。
- **required**: `items: List<T>` · `isLoading` · `itemBuilder: (context, item, index) => Widget` · `skeletonBuilder: (context, index) => Widget`(骨架卡各域视觉不同,由 caller 提供,含 Key)
- **可选**: `gridKey`(测试锚点,通常传 `Key('xxx-summary-grid')`) · `errorMessage` · `emptyMessage` · `placeholderCount`(默认 8) · `targetColumnWidth`(默认 `movieCardTargetWidth` token) · `minColumns` / `maxColumns`(默认 2 / 6) · `childAspectRatio`(fixedAspect 用,默认 `movieCardAspectRatio` token)
- **layout 分支**:
  - `AppAdaptiveCardGridLayout.fixedAspect`(默认):走 `GridView.builder` + 固定 `childAspectRatio`,所有 tile 等宽等高——movies / actors / rankings 的标准形态。
  - `AppAdaptiveCardGridLayout.masonry`:走 `MasonryGridView.count` + 逐 tile `tileAspect(index)`,横竖封面混排不留底色——videos 的形态,`tileAspect` **必填**。
- **何时用**: 所有"卡片自适应网格"——影片 / 女优 / 榜单 / 短视频等。
- **何时不用**: 缩略图专用网格(`MovieMediaThumbnailGrid`)、图搜结果(裸值 220,历史例外) → 各自组件。
- **旧网格现状**: `MovieSummaryGrid` / `ActorSummaryGrid` / `RankedMovieSummaryGrid` / `VideoSummaryGrid` 都已改成 `AppAdaptiveCardGrid<T>` 的薄壳(保留骨架私类 + 业务回调透传)。改列宽 / 四态观感 / 列钳位一律来这里改一处。

## StaggeredLayout(相关辅助)
- **路径**: `lib/widgets/layout/staggered_layout.dart`
- **用途**: 交错网格的**排布计算器**(`StaggeredTilePlacement` / `StaggeredLayoutResult`)。给业务侧一个"按 tile 元数据算出瀑布位置"的工具。
- **何时用**: 已经有裸 GridView 满足不了(如某些图集混合宽/高 tile),需要瀑布布局时。**不是 widget** 而是**布局工具类**。
- **何时不用**: 普通等宽卡片网格 → 直接用 `AppAdaptiveCardGrid<T>`(见上)或它的域内薄壳。

---

## 相关约定

- **网格四态**:骨架 → 错误 → 空态 → 内容,顺序固定,**已封装在 `AppAdaptiveCardGrid<T>` 内**。错误 / 空态自动走 `AppEmptyState`,骨架卡由 caller 传 `skeletonBuilder`。别再手写 `if (isLoading) ... if (errorMessage != null) ...` 四态判断。
- **列宽自适应**:`AppAdaptiveCardGrid<T>` 内部已封,公式 `((w + spacing) / (target + spacing)).floor()` + 钳位到 `[minColumns, maxColumns]`;target 默认 `movieCardTargetWidth` token,可通过 `targetColumnWidth` 覆盖(如 moment 传 280),**不要传裸值**。
- 想抽新的"选择系"胶水前,看看 `MultiSelectStateMixin` 能不能扩,别在业务侧写第二份多选状态机。
