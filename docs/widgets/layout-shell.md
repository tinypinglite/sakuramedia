# layout & shell —— 页面壳层和容器

## 应用壳层

- `AppDesktopShell`：`lib/widgets/shell/desktop/app_desktop_shell.dart`，桌面工作台容器。`AppShellLayout.immersive` 变体用于播放页等全出血场景：内容区去掉圆角与外边距，顶栏隐藏。macOS / Windows 下由 `DesktopAmbientBackdrop` 在侧栏和内容后面提供主题色对角光与环境底；桌面和移动环境底共享 `AppAmbientGlow` 光斑实现，各自保留位置、尺寸和测试 Key。玻璃桌面页内容区透明，由卡片和分区承载层级，不再由壳层或页面铺整块全高底色。玻璃侧栏展开时，页面和标准顶栏左内边距收到 `lg`，与侧栏面板自身的外侧 margin 合成 24px gutter；收起时恢复桌面页面边距。非玻璃桌面由壳层提供 `surfaceElevated` 底色，页面不再重复铺根背景。
- `AppSidebar`、`AppSidebarGroup`、`AppSidebarItem`：`app_sidebar.dart`，桌面导航分组和条目。macOS / Windows 展开态是一块从窗口边缘内收 `outerInset`、使用 `panelRadius` 圆角的 `AppGlassSurface.sidebar` 浮板；红绿灯和收起按钮仍固定在窗口坐标系，自然落在玻璃内。侧栏收起时面板、边距和内容一起归零并 `Offstage` 卸载（不是留一条窄栏），展开/悬停态由 `AppShellSidebarCollapsed` 驱动。
- `AppSidebarAccountCard`：`app_sidebar_account_card.dart`，桌面侧栏和移动概览抽屉共用的底部账户卡，承载产品名、登录状态、固定产品首字母 `S`、明暗/主题色入口、版本行和退出按钮。
- `SidebarAppearanceMenu`：`sidebar_appearance_menu.dart`，账户卡内的明暗模式三态切换图标与主题色菜单；读写 `appearanceProvider`，沿用设置页持久化。
- `AppSidebarToggleButton`：`app_sidebar_toggle_button.dart`，收起/展开按钮。窗口坐标位置由 `sidebarToggleButtonLeft` 计算：macOS 排在自绘红绿灯右侧，其它平台贴左缘。
- `AppMacTrafficLights`：`lib/widgets/shell/window/app_mac_traffic_lights.dart`，macOS 自绘红绿灯（系统按钮由 `window_bootstrap_desktop.dart` 隐藏）。用于与自绘窗口标题栏对齐；非 macOS 平台不渲染。
- `AppTopBar`：`app_top_bar.dart`，桌面页面顶栏和操作区；搜索框固定显示在顶栏右侧（不再在侧栏），聚焦时 Esc 清空并失焦，不再提供折叠/展开搜索的图标按钮。玻璃桌面页使用透明顶栏、同高（32）的 `AppTopBarGlassSearchField`（保留文字图搜 / 图片图搜后缀），刷新和返回使用同尺寸的 `AppGlassIconButton`；非玻璃桌面继续使用标准 `CatalogSearchField` 和普通图标按钮。高对比度下搜索框回退 solid，玻璃刷新和返回回退普通控件。
- `SidebarVersionFooter`：`sidebar_version_footer.dart`，桌面侧栏与移动抽屉账户卡共用的版本行。有更新时 info 图标带小圆点，点开菜单显示客户端 / 服务端版本、更新提示、发布页和插件更新入口。
- 版本更新检查状态由 `appUpdateCheckProvider`（`lib/app/providers/app_update_check_provider.dart`）统一提供：每小时轮询、单项失败静默保留旧值；桌面侧栏与移动抽屉共用，不要再在组件内各写一份 Timer。
- `AppMobileShell`、`AppMobileSubpageShell`：`lib/widgets/shell/mobile/`，移动一级入口和子页面容器。所有一级分支统一使用 `AppMobileAmbientBackdrop`，页面根背景保持透明。iOS / Android 底栏统一使用 `GlassTabBar.bottom` 浮动玻璃胶囊，仅高对比度回退为实色 `CupertinoTabBar`。玻璃底栏通过 `Scaffold.extendBody` 让页面内容从 Dock 后方滚过，底栏高度由 body 的 `MediaQuery.padding.bottom` 传给滚动页，末尾留白统一由 `bottomSafeAreaSliver` 补齐；实色兜底栏不开启穿底。`AppMobileSubpageShell(glassChrome: true)` 使用透明页面底、常驻 AppBar 和 44×44 玻璃返回钮；全部内容列表子页启用，非列表的设置、搜索、插件和导入页保持原样。所有移动子页的状态栏颜色都是透明的：玻璃子页露出环境底，普通子页露出页面底色，不再出现独立白条。
- `AppWindowDragArea`：`lib/widgets/shell/window/`，桌面窗口拖拽区。
- Windows 窗口是不透明的（没有系统毛玻璃），窗口底色只在重绘间隙可见；`DesktopAmbientBackdrop` 在 Windows 上作为纯渐变氛围层使用，不承诺原生模糊。
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

- `AppGlassSurface`：`lib/widgets/base/layout/glass/app_glass_surface.dart`。统一自定义玻璃表面，分五档 tone：`sidebar`（桌面侧栏整块浮板，标准质量、主题 tint、浅色模式带轻量浮层阴影，模糊和边光比 `track` 明显）、`chrome`（浮在媒体内容上的窗口级控件，带浮层阴影）、`control`（页面内可点击次级控件，主题自适应、无阴影）、`overlay`（播放器菜单/抽屉，模糊更强、染色更实）、`track`（自定义凹槽表面）。正常路径由 `liquid_glass_widgets` 的 shader 玻璃实现；`blur: false`、高对比模式和无法映射的圆角继续使用本地光感 fallback。
- `liquid_glass_widgets` 的语义控件（如 `GlassSegmentedControl`）直接在调用点或共享控件内部使用，不再包进 `AppGlassSurface`。`AppGlassSurface` 只承载没有对应语义组件的自定义表面；`chrome` / `control` / `overlay` 请求 premium 质量，`sidebar` / `track` 使用 standard；Skia/macOS、Windows 或 shader 不可用时由 package 自动降级。
- 只有左侧圆角的移动播放器抽屉在 `AppGlassSurface` 内部走加宽玻璃层裁切路径：可见宽度和内容布局不变，右侧保持直角。
- fallback 配方：光源固定在顶部中央，1px sweep 描边从顶部主光向两侧对称衰减，底部保留一圈微反射；内侧顶部叠 specular wash，底部压暗边模拟玻璃厚度；背景先模糊再提高饱和度，让玻璃聚色而不是发灰。正常路径的玻璃参数由 `liquid_glass_widgets` 管理，业务页面只选 tone / 尺寸 / 圆角 / 内边距，不要自己拼渐变和描边。
- 玻璃只用于 chrome / overlay / track 和可点击的次级控件；普通内容/状态标签（番号、上次看到、评分文字、设置页徽章）保持普通文本或标准材质，不套玻璃。内容卡和正文也不透明，主操作仍用实色品牌色。
- 背景模糊统一由 `AppGlassSurface` 或库的语义控件管理；播放器菜单/抽屉继续走 `AppGlassSurface`，分段控件由 `GlassSegmentedControl` 自行管理。业务页面不要再拼半透明色 + `BackdropFilter` + 边框。封面上的 4K/8K、热度、排名角标使用 `AppMediaBadge` 的无模糊烟熏渐变，不参与背景滤镜。
- 页面级搜索使用 `AppGlassSearchField`，顶栏搜索使用 `AppTopBarGlassSearchField`，两者共享 `app_glass_search_field_chrome.dart` 的 `GlassTextField.search` 玻璃/字体配置，但保留各自的尺寸、焦点和前后缀语义；其它文本/搜索输入统一走 `AppTextField` 的液态玻璃基座。合集网格的多卡信息条用库的 `GlassContainer`、`GlassQuality.minimal`，避免每张卡各建一条标准/高级玻璃纹理。桌面视频合集详情的合集名、排序、成员数和「播放全部 / 选择」收在同一条 `AppGlassListHeader` 里；移动端把封面 Hero、播放按钮和排序栏放进同一个 `CustomScrollView`，成员网格滚动时整块头部随之上移。其它页面的主操作仍默认实色品牌色。


## 固定列表控制栏与吸顶

- `AppFixedHeaderLayout`：`lib/widgets/base/layout/scrolling/app_fixed_header_layout.dart`。`header` 自然占高，`child` 在剩余空间内滚动，适用于影片、女优、排行、搜索和管理列表。结果加载层放在 `child` 内，不覆盖固定控制栏。筛选类固定头通过 `headerBottomSpacing` 保留与滚动区的持久留白；不要把这段间距放进滚动内容的首个 sliver，否则列表滚动后内容会贴住控制栏。
- `AppPinnedSliverSection` / `AppPinnedListHeader`：同目录 `app_pinned_list_header.dart`。吸顶列表统一用 `AppPinnedSliverSection.before / header / after` 三段式，裁剪实现收在组件内部：前置和结果绘制到控制栏边界外时直接停止，页面不再手写裁剪组合。控制条本身固定透明，没有 color / blur 参数，不额外铺页面底色；这样环境背景和玻璃材质保持连续，内容也不会从按钮或分组间隙透出。筛选 / 控制头通过 `headerBottomSpacing` 保留与结果的持久留白；间距不得放进 `after` 或滚动内容首项，否则吸顶后会贴边。女优详情、PornBox 桌面与移动一级页、移动视频合集详情都使用它；移动 PornBox 仍把筛选 / 排序收在「全部视频」标题行，但整行吸顶，并为右上角固定的新建玻璃钮保留横向空间。
- 吸顶页面切筛选时，使用控制栏的稳定 `GlobalKey` 和原滚动控制器调用 `AppPinnedListHeader.scrollToStart`。已经滚过介绍区时回到结果起点，尚未滚过时保留位置。
- `AppFilterResultLoadingOverlay` 在吸顶页面传相同的 `protectedHeaderKey` 和 `scrollController`，按实际头部位置裁剪结果遮罩，兼容头部动态高度。
- `AppAdaptiveRefreshScrollView` / `AppPullToRefresh` 在下拉期间发送 `AppPullRefreshNotification`，外层结果加载层据此暂停筛选加载标记。桌面页刷新和正常筛选不受影响，页面无需再维护一份图标互斥状态。

## 移动子页 AppBar

`AppMobileSubpageShell(autoHideAppBar: true)` 让子页的 AppBar 随滚动收起：滚离顶部隐藏，向上滚不恢复，回到顶部才恢复。普通子页的 AppBar 高度动画到 0，内容区同步上移；immersive 子页的返回栏本来就悬浮在内容上，收起时只淡出，正文保持全幅铺底不位移。页面主滚动和 `TabBarView` / `PageView` 里的纵向列表都会驱动；更深的嵌套滚动不驱动。普通子页顶部 `SafeArea` 保持不变，内容不会进入状态栏区域。移动路由层对所有子页默认开启；个别需要常驻 AppBar 的子页可在路由数据里覆盖 `autoHideAppBar => false`。直接使用 shell 时该参数默认 false。

页面保留自己的滚动控制器、缓存键、Provider 和分页回调；不通过嵌套纵向列表或全量 `shrinkWrap` 网格实现固定栏。移动合集详情使用单个 `CustomScrollView` 承载封面、控制栏和成员瀑布流；封面与「播放全部」随内容滚走并在控制条下缘被裁切，排序控制条透明吸顶，底部批量操作条单独固定。

## 桌面一级页面保留

`DesktopBranchCache` 配合桌面一级导航的 StatefulShellRoute，按最近访问顺序最多保留 8 个分支；未访问页面不挂载，详情不加入缓存。隐藏分支停用 TickerMode 和焦点，离开桌面 shell 时一起释放。

## TabBarView 页面保留

`AppKeepAlive` 位于 `lib/widgets/base/layout/keep_alive_page.dart`。它只保留已访问的 `PageView` / `TabBarView` 子页 Widget 生命周期，用于输入、滚动和局部交互在切换标签后恢复；不要用它把页面 Provider 提升为全局常驻状态。
