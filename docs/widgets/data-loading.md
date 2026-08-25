# data-loading —— 刷新、分页、网格和选择

## 刷新与分页

- `AppPullToRefresh`：`lib/widgets/base/layout/scrolling/app_pull_to_refresh.dart`，移动下拉刷新。
- `AppAdaptiveRefreshScrollView`：根据平台组合刷新和滚动行为。
- `AppPagedLoadMoreFooter`：分页底部的加载中、失败重试和已完成状态。
- `AppFilterTotalHeader`：筛选结果总数信息。

这些组件只表达 UI 状态；请求、页码、筛选和重试由 feature Provider 提供。

## 统一文字和网格

- `AppText`：`lib/widgets/base/typography/app_text.dart`，按应用 token 表达文字层级。
- `AppAdaptiveCardGrid<T>` / `AppAdaptiveCardSliver<T>`：自适应列数、固定比例或 masonry 布局，并可接入骨架、错误、空态和内容 builder。
- `StaggeredTilePlacement` / `StaggeredLayoutResult`：`staggered_layout.dart`，只在需要自定义交错布局时使用。

普通影片、女优、视频等封面网格优先使用 `AppAdaptiveCardGrid` 及其业务薄壳。缩略图网格、图搜结果等有不同视觉/交互语义的网格保留各自实现。

## 多选

- `MultiSelectStateMixin`：多选状态和值变化。
- `SelectionCheckBadge`：卡片选中标记。
- `AppSelectionToolbar`：桌面批量操作条。
- `AppSelectionBottomBar`：移动批量操作条。

选中项、批量动作和失败反馈由业务页面或 Provider 管理；组件不直接发送业务请求。
