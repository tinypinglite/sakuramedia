# data-loading —— 刷新、分页、网格和选择

## 刷新与分页

- `AppPullToRefresh`：`lib/widgets/base/layout/scrolling/app_pull_to_refresh.dart`，移动下拉刷新。
- `AppAdaptiveRefreshScrollView`：根据平台组合刷新和滚动行为。
- `AppPagedLoadMoreScope`：`lib/widgets/base/layout/scrolling/app_paged_load_more_scope.dart`，分页滚动视图的统一触发器。它同时监听滚动尺寸与用户滚动：内容不足一屏、窗口/列数变化或列表追加后自动补页，用户接近底部时按 `triggerOffset` 触发。每个 Scope 只包一个滚动视图；`canLoadMore` 必须实时读取 Provider，`onLoadMore` 必须返回真实请求 Future。页面 ScrollController 只保留给筛选跳回、吸顶定位等用途，不要另加分页 listener。
- `AppNoPullDownScrollView`：`lib/widgets/base/layout/scrolling/app_no_pull_down_scroll_view.dart`，页级竖向滚动容器——顶部继续下拉时零位移、不回弹，并压掉 Android 的拉伸 / 光晕；底部上滑的过卷保留平台默认手感。只处理自身竖向滚动，内部横向列表不受影响（影片详情页用）。
- `AppPagedLoadMoreFooter`：分页底部的加载中、失败重试和已完成状态；加载动画随平台自适应。
- `PagedLoadMoreFooterSliver`：`lib/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart`，分页列表共用的「加载更多」页脚。它自己 `select` loadMore 的 loading / 失败状态，列表本体的 `select` 用同文件的 `withoutLoadMoreStatus` 把这两个字段清成中性值，于是翻页状态翻转只重建页脚。注意中立化只对自带内容相等的值（`PagedListState` / record）生效；整段 section state 需要它自己实现 `==`。
- `AppSelectableTextScrollConfiguration`：包裹含可选文本的滚动区域，把鼠标排除在拖拽滚动之外，避免列表滚动抢走鼠标文本选择；触摸、触控板、滚轮和滚动条不受影响。

这些组件只表达 UI 状态或触发时机；请求、页码、筛选和重试由 feature Provider 提供。自动加载失败后不要自动重试，恢复分页统一走页脚或选择器里的显式重试操作。

## 统一文字和网格

- `AppText`：`lib/widgets/base/typography/app_text.dart`，按应用 token 表达文字层级。
- `AppAdaptiveCardGrid<T>` / `AppAdaptiveCardSliver<T>`：自适应列数、固定比例或 masonry 布局，并可接入骨架、错误、空态和内容 builder。
- `AppAdaptiveCardWrapSliver<T>`：`app_adaptive_card_wrap.dart`，自然高度卡片网格的 Sliver 版——按 `orientation` 取统一列数切列宽，卡片保持自身内容高度不被固定比例拉伸（合集列表用）；按行懒构建，直接放进 `CustomScrollView.slivers`。需要行内等高时传 `stretchRows: true`。
- `StaggeredTilePlacement` / `StaggeredLayoutResult`：`staggered_layout.dart`，只在需要自定义交错布局时使用。

全站卡片网格（影片 / 女优 / 视频 / 切片 / 时刻 / 图搜列表、合集列表与合集详情）统一走同一套列数规格：目标列宽按卡片朝向分三档，竖图取 `AppComponentTokens.cardGridPortraitTargetWidth`（当前 240）、横竖混排取 `cardGridMixedTargetWidth`（当前 320）、横图取 `cardGridLandscapeTargetWidth`（当前 320），列数上限取 `cardGridMaxColumns`（当前 8）。`AppAdaptiveCardGrid` / `AppAdaptiveCardSliver` 的 fixedAspect 布局按 `childAspectRatio`（>= 1 视为横图）自动选档，masonry 与固定高度卡片默认混排档，也可用 `orientation` 显式覆盖；手写 `GridView` / `SliverGrid` 的页面用 `resolveAppCardGridColumnCount(context, width:, spacing:, orientation:)` 声明朝向。调整卡片密度只改 token，一处生效。播放器缩略图面板有自己的目标列宽和用户手动列数，不在这套规格内。

## 多选

- `MultiSelectStateMixin`：多选状态和值变化。
- `SelectionCheckBadge`：卡片选中标记。
- `AppSelectionBottomBar`：移动批量操作条。
- `AppGlassSelectionHeader`：`lib/widgets/base/navigation/app_glass_list_header.dart`，桌面玻璃列表的选择态；沿用常规玻璃控制条的材质、胶囊高度和左右分组，PornBox、切片和时刻列表不再替换成实色批量操作条。

选中项、批量动作和失败反馈由业务页面或 Provider 管理；组件不直接发送业务请求。

`AppPageRefreshScope` 仅在所在页面的 TickerMode 启用时向桌面壳注册刷新回调，隐藏的保活页面不接收顶栏刷新。
