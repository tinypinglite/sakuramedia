# data-loading —— 刷新、分页、网格和选择

## 刷新与分页

- `AppPullToRefresh`：`lib/widgets/base/layout/scrolling/app_pull_to_refresh.dart`，移动下拉刷新。
- `AppAdaptiveRefreshScrollView`：根据平台组合刷新和滚动行为。
- `AppPagedLoadMoreFooter`：分页底部的加载中、失败重试和已完成状态；加载动画随平台自适应。
- `AppFilterTotalHeader`：筛选结果总数信息。
- `AppSelectableTextScrollConfiguration`：包裹含可选文本的滚动区域，把鼠标排除在拖拽滚动之外，避免列表滚动抢走鼠标文本选择；触摸、触控板、滚轮和滚动条不受影响。

这些组件只表达 UI 状态；请求、页码、筛选和重试由 feature Provider 提供。

## 统一文字和网格

- `AppText`：`lib/widgets/base/typography/app_text.dart`，按应用 token 表达文字层级。
- `AppAdaptiveCardGrid<T>` / `AppAdaptiveCardSliver<T>`：自适应列数、固定比例或 masonry 布局，并可接入骨架、错误、空态和内容 builder。
- `StaggeredTilePlacement` / `StaggeredLayoutResult`：`staggered_layout.dart`，只在需要自定义交错布局时使用。

全站卡片网格（影片 / 女优 / 视频 / 切片 / 时刻 / 图搜列表、合集列表与合集详情）统一走同一套列数规格：目标列宽和列数上限取 `AppComponentTokens.cardGridTargetWidth`（当前 220）与 `cardGridMaxColumns`（当前 8）。`AppAdaptiveCardGrid` / `AppAdaptiveCardSliver` 默认读取该 token，手写 `GridView` / `SliverGrid` 的页面用 `resolveAppCardGridColumnCount(context, width:, spacing:)`；调整卡片密度只改 token，一处生效。播放器缩略图面板有自己的目标列宽和用户手动列数，不在这套规格内。

## 多选

- `MultiSelectStateMixin`：多选状态和值变化。
- `SelectionCheckBadge`：卡片选中标记。
- `AppSelectionToolbar`：桌面批量操作条。
- `AppSelectionBottomBar`：移动批量操作条。

选中项、批量动作和失败反馈由业务页面或 Provider 管理；组件不直接发送业务请求。

`AppPageRefreshScope` 仅在所在页面的 TickerMode 启用时向桌面壳注册刷新回调，隐藏的保活页面不接收顶栏刷新。
