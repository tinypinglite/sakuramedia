# layout & shell —— 页面壳层和容器

## 应用壳层

- `AppDesktopShell`：`lib/widgets/shell/desktop/app_desktop_shell.dart`，桌面工作台容器。`AppShellLayout.immersive` 变体用于播放页等全出血场景：内容区去掉圆角与外边距，顶栏隐藏。
- `AppSidebar`、`AppSidebarGroup`、`AppSidebarItem`：`app_sidebar.dart`，桌面导航分组和条目。侧栏收起时宽度归零并 `Offstage` 卸载内容（不是留一条窄栏），展开/悬停态由 `AppShellSidebarCollapsed` 驱动。
- `SidebarAppearanceMenu`：`sidebar_appearance_menu.dart`，侧栏底部的明暗模式三态切换图标与主题色小浮窗（浮层由 `AppAnchoredPopover` 承载）；读写 `appearanceProvider`，沿用设置页持久化，选色后自动收起。
- `AppSidebarToggleButton`：`app_sidebar_toggle_button.dart`，收起/展开按钮。窗口坐标位置由 `sidebarToggleButtonLeft` 计算：macOS 排在自绘红绿灯右侧，其它平台贴左缘。
- `AppMacTrafficLights`：`lib/widgets/shell/window/app_mac_traffic_lights.dart`，macOS 自绘红绿灯（系统按钮由 `window_bootstrap_desktop.dart` 隐藏）。用于与自绘窗口标题栏对齐；非 macOS 平台不渲染。
- `AppTopBar`：`app_top_bar.dart`，桌面页面顶栏和操作区；搜索入口在顶栏右侧（不再在侧栏），默认展开，点击图标可折叠为图标按钮，聚焦时 Esc 收起。
- `SidebarVersionFooter`：`desktop/sidebar_version_footer.dart`，桌面侧栏底部版本行；有更新时 info 图标带小圆点，点开为上方版本浮层（客户端 / 服务端 / 发布页 / 插件更新，浮层由 `AppAnchoredPopover` 承载）。
- `AppVersionInfoCard`：`app_version_info_card.dart`，移动端抽屉里的版本卡片（完整信息内联展示）。
- `AppVersionRow`、`AppVersionUpdateNotice`：`app_version_info_parts.dart`，上述两处的共用行与更新提示块。
- 版本更新检查状态由 `appUpdateCheckProvider`（`lib/app/providers/app_update_check_provider.dart`）统一提供：每小时轮询、单项失败静默保留旧值；桌面页脚与移动卡片共用，不要再在组件内各写一份 Timer。
- `AppMobileShell`、`AppMobileSubpageShell`：`lib/widgets/shell/mobile/`，移动一级入口和子页面容器。
- `AppWindowDragArea`：`lib/widgets/shell/window/`，桌面窗口拖拽区。
- Windows 窗口是不透明的（没有系统毛玻璃），窗口底色只在重绘间隙可见；
  无边框由 runner 原生实现（`win32_window.cpp` 接管 `WM_NCCALCSIZE`，可见框
  去掉、`WS_THICKFRAME` 保留），resize/阴影走 DWM 原生。

新页面先选择对应平台 shell，再在内容区编排 feature 页面；不要在 feature 页面重新搭一套应用级导航。

## 页面和卡片容器

- `AppPageFrame`：页面最大宽度、边距和滚动内容容器。
- `AppContentCard`：承载一组内容或表单的卡片。
- `AppSettingsGroup`、`AppSettingCell`、`AppSettingIconBox`、`AppSettingCellChevron`、`AppSettingsRail`：设置页分组、条目和桌面设置导航。
- `AppNoticeCard` / `AppNoticeStat`：页面顶部说明和统计摘要。
- `AppStatTile`：突出数字统计；`AppInfoBlock`：标签和值的普通信息块。
- `AppBadge`：小型徽标或状态标记。

这些组件位于 `lib/widgets/base/layout/cards/`。尺寸和间距走 theme token，页面只传语义内容和必要布局参数。

## 玻璃材质

- `AppGlassSurface`：`lib/widgets/base/layout/glass/app_glass_surface.dart`。统一玻璃表面，分四档 tone：`chrome`（浮在媒体内容上的窗口级控件，带浮层阴影）、`control`（页面内可点击次级控件，主题自适应、无阴影）、`overlay`（播放器菜单/抽屉，模糊更强、染色更实）、`track`（分段控件等控件内部的凹槽）。
- 配方：光源固定在顶部中央，1px sweep 描边从顶部主光向两侧对称衰减，底部保留一圈微反射；内侧顶部叠 specular wash，底部压暗边模拟玻璃厚度；背景先模糊再提高饱和度，让玻璃聚色而不是发灰。业务页面只选 tone / 尺寸 / 圆角 / 内边距，不要自己拼渐变和描边。
- 玻璃只用于 chrome / overlay / track 和可点击的次级控件；普通内容/状态标签（番号、上次看到、评分文字、设置页徽章）保持普通文本或标准材质，不套玻璃。内容卡和正文也不透明，主操作仍用实色品牌色。
- 背景模糊只在 `AppGlassSurface` 内部使用；播放器菜单/抽屉和分段控件 track 都已收口，业务页面不要再拼半透明色 + `BackdropFilter` + 边框。封面上的 4K/8K、热度、排名角标使用 `AppMediaBadge` 的无模糊烟熏渐变，不参与背景滤镜。


## 固定列表控制栏与吸顶

- `AppFixedHeaderLayout`：`lib/widgets/base/layout/scrolling/app_fixed_header_layout.dart`。`header` 自然占高，`child` 在剩余空间内滚动，适用于影片、女优、排行、搜索和管理列表。结果加载层放在 `child` 内，不覆盖固定控制栏。
- `AppPinnedListHeader`：同目录 `app_pinned_list_header.dart`。用于资料/合集预览之后的控制栏，保持一个主滚动容器。必须传页面对应的主题背景色，避免卡片从栏内透出；正常/多选内容在同一个头中替换。
- 吸顶页面切筛选时，使用控制栏的稳定 `GlobalKey` 和原滚动控制器调用 `AppPinnedListHeader.scrollToStart`。已经滚过介绍区时回到结果起点，尚未滚过时保留位置。
- `AppFilterResultLoadingOverlay` 在吸顶页面传相同的 `protectedHeaderKey` 和 `scrollController`，按实际头部位置裁剪结果遮罩，兼容头部动态高度。
- `AppAdaptiveRefreshScrollView` / `AppPullToRefresh` 在下拉期间发送 `AppPullRefreshNotification`，外层结果加载层据此暂停筛选加载标记。桌面页刷新和正常筛选不受影响，页面无需再维护一份图标互斥状态。

## 移动子页 AppBar

`AppMobileSubpageShell(autoHideAppBar: true)` 让子页的 AppBar 随滚动收起：滚离顶部隐藏，向上滚不恢复，回到顶部才恢复。普通子页的 AppBar 高度动画到 0，内容区同步上移；immersive 子页的返回栏本来就悬浮在内容上，收起时只淡出，正文保持全幅铺底不位移。页面主滚动和 `TabBarView` / `PageView` 里的纵向列表都会驱动；更深的嵌套滚动不驱动。普通子页顶部 `SafeArea` 保持不变，内容不会进入状态栏区域。移动路由层对所有子页默认开启；个别需要常驻 AppBar 的子页可在路由数据里覆盖 `autoHideAppBar => false`。直接使用 shell 时该参数默认 false。

页面保留自己的滚动控制器、缓存键、Provider 和分页回调；不通过嵌套纵向列表或全量 `shrinkWrap` 网格实现固定栏。已有固定的合集详情布局可直接沿用。

## 桌面一级页面保留

`DesktopBranchCache` 配合桌面一级导航的 StatefulShellRoute，按最近访问顺序最多保留 8 个分支；未访问页面不挂载，详情不加入缓存。隐藏分支停用 TickerMode 和焦点，离开桌面 shell 时一起释放。

## TabBarView 页面保留

`AppKeepAlive` 位于 `lib/widgets/base/layout/keep_alive_page.dart`。它只保留已访问的 `PageView` / `TabBarView` 子页 Widget 生命周期，用于输入、滚动和局部交互在切换标签后恢复；不要用它把页面 Provider 提升为全局常驻状态。
