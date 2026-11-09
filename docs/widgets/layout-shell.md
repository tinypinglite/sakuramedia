# layout & shell —— 页面壳层和容器

## 应用壳层

- `AppDesktopShell`：`lib/widgets/shell/desktop/app_desktop_shell.dart`，桌面工作台容器。`AppShellLayout.immersive` 变体用于播放页等全出血场景：内容区去掉圆角与外边距，顶栏隐藏。macOS / Windows 下由 `DesktopAmbientBackdrop` 在侧栏和内容后面提供主题色对角光与环境底；桌面 `DesktopAmbientBackdrop` 与移动 `AppMobileAmbientBackdrop` 共用 `AppAmbientBackdrop`，由 `mobile` 布尔选择光斑位置、尺寸、透明度和测试 Key。玻璃桌面页内容区透明，由卡片和分区承载层级，不再由壳层或页面铺整块全高底色。玻璃侧栏展开时，页面和标准顶栏左内边距收到 `lg`，与侧栏面板自身的外侧 margin 合成 24px gutter；收起时恢复桌面页面边距。非玻璃桌面由壳层提供 `surfaceElevated` 底色，页面不再重复铺根背景。
- `AppSidebar`：`app_sidebar.dart`，桌面侧栏骨架，直接渲染扁平的 `AppNavItem` 列表并按 `sectionLabel` 插入分区标题；`AppSidebarItem` 在 `app_sidebar_item.dart`，`SidebarNavScrollArea` 在 `app_sidebar_nav_scroll_area.dart`。macOS / Windows 展开态是一块从窗口边缘内收 `outerInset`、使用 `panelRadius` 圆角的 `AppSurface` 浮板；红绿灯和收起按钮仍固定在窗口坐标系，自然落在玻璃内。侧栏收起时面板、边距和内容一起归零，导航区用 `Offstage` 隐藏并保留状态（不是卸载）。导航项 hover 显示比选中态更浅的 120ms 背景胶囊，由 `AppInteractiveSurface.onHoverChanged` 驱动，不打开 InkWell 自带 hover 色；展开/收起由 `AppShellSidebarCollapsed` 驱动。
- `AppSidebarAccountCard`：`app_sidebar_account_card.dart`，桌面侧栏和移动概览抽屉共用的底部账户卡，承载产品名、登录状态、固定产品首字母 `S`、明暗/主题色入口、版本行和退出按钮。
- `SidebarAppearanceMenu`：`sidebar_appearance_menu.dart`，账户卡内的明暗模式三态切换图标与主题色菜单；读写 `appearanceProvider`，沿用设置页持久化。
- `AppSidebarToggleButton`：`app_sidebar_toggle_button.dart`，收起/展开按钮。窗口坐标位置由 `sidebarToggleButtonLeft` 计算：macOS 排在自绘红绿灯右侧，其它平台贴左缘。
- `AppMacTrafficLights`：`lib/widgets/shell/window/app_mac_traffic_lights.dart`，macOS 自绘红绿灯（系统按钮由 `window_bootstrap_desktop.dart` 隐藏）。用于与自绘窗口标题栏对齐；非 macOS 平台不渲染。
- `AppTopBar`：`app_top_bar.dart`，桌面页面顶栏布局和操作区；搜索框固定显示在顶栏右侧（不再在侧栏），聚焦时 Esc 清空并失焦，不再提供折叠/展开搜索的图标按钮。搜索/图搜逻辑在 `features/search/presentation/widgets/top_bar_search_actions.dart`，返回按钮在 `widgets/base/navigation/app_back_button.dart`，刷新按钮在 `widgets/shell/desktop/top_bar_refresh_button.dart`。玻璃桌面页使用透明顶栏、同高（32）的 `AppTopBarGlassSearchField`（保留文字图搜 / 图片图搜后缀）；非玻璃桌面继续使用标准 `CatalogSearchField`。高对比度下搜索框回退 solid，玻璃刷新和返回回退普通控件。
- `SidebarVersionFooter`：`sidebar_version_footer.dart`，provider-free 的版本行展示件；`SidebarVersionInfo`（`widgets/domain/updates/sidebar_version_info.dart`）负责读取版本/更新/插件状态并注入数据。有更新时 info 图标带小圆点，点开菜单显示客户端 / 服务端版本、更新提示、发布页和插件更新入口。
- 版本更新检查状态由 `appUpdateCheckProvider`（`lib/app/providers/app_update_check_provider.dart`）统一提供：每小时轮询、单项失败静默保留旧值；桌面侧栏与移动抽屉共用，不要再在组件内各写一份 Timer。
- `AppMobileShell`、`AppMobileSubpageShell`：`lib/widgets/shell/mobile/`，移动一级入口和子页面容器。子页导航栏、返回拦截和标题信箱分别在 `mobile_subpage_app_bar.dart`、`mobile_subpage_back_interceptor.dart`、`mobile_subpage_title.dart`。所有一级分支统一使用 `AppMobileAmbientBackdrop`，页面根背景保持透明。iOS / Android 底栏统一使用 `AppGlassTabBar` 浮动玻璃胶囊，仅高对比度回退为实色 `CupertinoTabBar`。玻璃底栏通过 `Scaffold.extendBody` 让页面内容从 Dock 后方滚过，底栏高度由 body 的 `MediaQuery.padding.bottom` 传给滚动页，末尾留白统一由 `bottomSafeAreaSliver` 补齐；实色兜底栏不开启穿底。`AppMobileSubpageShell(glassChrome: true)` 使用透明页面底、常驻 AppBar 和 44×44 玻璃返回钮；全部内容列表子页启用，非列表的设置、搜索、插件和导入页保持原样。所有移动子页的状态栏颜色都是透明的：玻璃子页露出环境底，普通子页露出页面底色，不再出现独立白条。
- `AppWindowDragArea`：`lib/widgets/shell/window/`，桌面窗口拖拽区。
- Windows 窗口是不透明的（没有系统毛玻璃），窗口底色只在重绘间隙可见；`DesktopAmbientBackdrop` 在 Windows 上作为纯渐变氛围层使用，不承诺原生模糊。
  无边框由 runner 原生实现（`win32_window.cpp` 接管 `WM_NCCALCSIZE`，可见框
  去掉、`WS_THICKFRAME` 保留），resize/阴影走 DWM 原生。

新页面先选择对应平台 shell，再在内容区编排 feature 页面；不要在 feature 页面重新搭一套应用级导航。

## 页面和卡片容器

- `AppContentCard`：承载一组内容或表单的卡片。
- `AppSettingsGroup`、`AppSettingCell`、`AppSettingIconBox`、`AppSettingCellChevron`、`AppSettingCreateCell`、`AppSettingInlineActions`、`AppSettingsRail`：设置页分组、条目、新建行、行尾编辑/删除动作和桌面设置导航。
- `AppNoticeCard` / `AppNoticeStat`：页面顶部说明和统计摘要。
- `AppStatTile`：突出数字统计；`AppInfoBlock`：标签和值的普通信息块。
- `AppBadge`：小型徽标或状态标记。

这些组件位于 `lib/widgets/base/layout/cards/`。尺寸和间距走 theme token，页面只传语义内容和必要布局参数。

## 玻璃材质

- `AppSurface`：`lib/widgets/base/layout/surface/app_surface.dart`。页面和域组件使用的材质无关通用面，接收 child、圆角、padding、宽高和语义角色 `AppSurfaceRole`；不暴露 blur、quality、settings。`AppSurfaceGroup` 用于需要共享背景读取的一组表面。角色只表达用途，具体材质统一由玻璃层映射。
- `AppSurfaceStyle`：外观设置里的 `liquid` / `flat` 二选一，经 `AppSurfaceStyleScope` 向下传递；没有 scope 时默认液态玻璃。
- `AppSurfaceRuntime`：统一处理玻璃初始化、brightness resolver 和全局 wrap；`main.dart`、`app.dart`、测试和预览 helper 只通过它接入。
- 正常路径只通过 `AppGlassStyle.settingsFor/qualityFor` 取材质：iOS 27 regular 基底 + 角色化 tint/厚度/模糊/边缘光/内阴影；不再让各业务组件直接吃包默认材质。`surface/control/input/mediaOverlay` 用 standard，`popover/toolbarControl/toolbarInput/bar/overlay` 用 premium；大面和滚动内容不堆 premium。
- 浅色模式使用 `surfaceElevated` 白色 tint + `whitenStrength` 做明亮乳白玻璃，浅色 `bodyShade` 为 0；深色模式保留深色 tint/bodyShade 和深玻璃观感。`mediaOverlay` 在两种模式下都保持深色烟熏，只配 onMedia 白字。
- 液态玻璃角色：`surface` 用于侧栏、登录主卡和页面大面板；`popover` 用于筛选/排序弹层、锚定菜单、右键菜单、弹窗、抽屉和播放器菜单；`control` 用于玻璃图标钮、列表头按钮组和返回钮；`toolbarControl` 用于顶栏刷新/返回（静止无底，hover/focus/press 才浮出胶囊）；`input` 用于表单输入、页面搜索和非玻璃顶栏搜索；`toolbarInput` 用于顶栏搜索；`bar` 用于移动 TabBar、底部多选条和标签操作条；`overlay` 用于 Toast 和播放恢复提示；`mediaOverlay` 用于封面上的白字信息条，是唯一允许 clear + 深色压暗的 role。
- `mediaOverlay` 只能配 `onMedia` 白字；其它自适应玻璃不允许把白字压在浅色 tint 上。品牌色只用于选中胶囊、prominent 按钮和 active 图标，不进入整块玻璃 tint。
- 真正的玻璃实现只允许在 `lib/widgets/base/layout/glass/` 内：材质配置、fallback、内部按钮/输入/弹层/TabBar 后端都在这里。`features`、`widgets/domain`、`widgets/shell` 和 app 启动层不得 import 这个目录或直接依赖 `liquid_glass_widgets`。
- `AppGlassIconButton`、`AppTextField`、`AppGlassPopover`、`AppGlassToast`、`AppGlassListHeader`、`AppGlassTabBar` 是基础语义组件；它们的公开 API 不出现包类型，内部通过玻璃层后端绘制。`AppSegmentedControl` 固定使用平面分段后端，不随全局液态玻璃设置切换。
- 扁平风格是纯 Flutter 实现：不实例化 `liquid_glass_widgets` 组件，不使用 `BackdropFilter`、shader、玻璃阴影；表面使用近实色半透明底、1px 边框和极轻顶部高光，适合低性能设备。高对比度下改为不透明底 + 强边框。macOS 原生 `NSVisualEffectView` 是窗口 chrome，不属于 Flutter surface，由外观设置里的独立「透明毛玻璃」开关控制；关闭后窗口改为不透明，与液态玻璃/扁平风格的选择无关。
- 只有左侧圆角的移动播放器抽屉在 `AppSurface` 内部走加宽玻璃层裁切路径：可见宽度和内容布局不变，右侧保持直角。
- fallback 配方只在高对比、无 shader 或无法映射圆角时使用：光源固定在顶部中央，1px sweep 描边从顶部主光向两侧对称衰减，底部保留一圈微反射；内侧顶部叠 specular wash，底部压暗边模拟玻璃厚度；背景先模糊再提高饱和度，让玻璃聚色而不是发灰。正常路径的玻璃参数由玻璃层管理，业务页面只选尺寸 / 圆角 / 内边距，不要自己拼渐变和描边。
- 玻璃只用于可点击的次级控件和必要浮层；普通内容/状态标签（番号、上次看到、评分文字、设置页徽章）保持普通文本或标准材质，不套玻璃。内容卡和正文也不透明，主操作仍用实色品牌色。
- 背景模糊统一由 `AppSurface` 或基础语义组件管理；播放器菜单/抽屉继续走 `AppSurface`，分段控件固定使用无模糊的平面轨道。业务页面不要再拼半透明色 + `BackdropFilter` + 边框。封面上的 4K/8K、热度、排名角标使用 `AppMediaBadge` 的无模糊烟熏渐变，不参与背景滤镜。
- 页面级搜索使用 `AppGlassSearchField`，顶栏搜索使用 `AppTopBarGlassSearchField`，两者共享 `app_glass_search_field_chrome.dart` 的文本输入玻璃后端和字体配置，但保留各自的尺寸、焦点和前后缀语义；其它文本/搜索输入统一走 `AppTextField` 的液态玻璃基座。合集网格的多卡信息条统一走玻璃层表面。桌面视频合集详情的合集名、排序、成员数和「播放全部 / 选择」收在同一条 `AppGlassListHeader` 里；移动端把封面 Hero、播放按钮和排序栏放进同一个 `CustomScrollView`，成员网格滚动时整块头部随之上移。其它页面的主操作仍默认实色品牌色。


## 固定列表控制栏与吸顶

- `AppFixedHeaderLayout`：`lib/widgets/base/layout/scrolling/app_fixed_header_layout.dart`。`header` 自然占高，`child` 在剩余空间内滚动，适用于影片、女优、排行、搜索和管理列表。结果加载层放在 `child` 内，不覆盖固定控制栏。筛选类固定头通过 `headerBottomSpacing` 保留与滚动区的持久留白；不要把这段间距放进滚动内容的首个 sliver，否则列表滚动后内容会贴住控制栏。
- 列表 Header 是筛选失败反馈的唯一 owner：`AppGlassListHeader` / `AppMobileListHeader` 内部已经渲染 `AppFilterUpdateBar`，页面不要再外挂同一条 bar。没有 Header 的列表用 `AppInlineErrorBanner`。吸顶列表在筛选/排序变化后统一调用 `AppPinnedListHeader.scrollToStart`，不要用 `jumpTo(0)` 把前置资料区一起滚掉。
- `AppPinnedSliverSection` / `AppPinnedListHeader`：同目录 `app_pinned_list_header.dart`。吸顶列表统一用 `AppPinnedSliverSection.before / header / after` 三段式，裁剪实现收在组件内部：前置和结果绘制到控制栏边界外时直接停止，页面不再手写裁剪组合。控制条本身固定透明，没有 color / blur 参数，不额外铺页面底色；这样环境背景和玻璃材质保持连续，内容也不会从按钮或分组间隙透出。筛选 / 控制头通过 `headerBottomSpacing` 保留与结果的持久留白；间距不得放进 `after` 或滚动内容首项，否则吸顶后会贴边。女优详情、PornBox 桌面与移动一级页、移动视频合集详情都使用它；移动 PornBox 仍把筛选 / 排序收在「全部视频」标题行，但整行吸顶，并为右上角固定的新建玻璃钮保留横向空间。
- 吸顶页面切筛选时，使用控制栏的稳定 `GlobalKey` 和原滚动控制器调用 `AppPinnedListHeader.scrollToStart`。已经滚过介绍区时回到结果起点，尚未滚过时保留位置。
- `AppFilterResultLoadingOverlay` 在吸顶页面传相同的 `protectedHeaderKey` 和 `scrollController`，按实际头部位置裁剪结果遮罩，兼容头部动态高度。
- `AppAdaptiveRefreshScrollView` / `AppPullToRefresh` 在下拉期间发送 `AppPullRefreshNotification`，外层结果加载层据此暂停筛选加载标记。桌面页刷新和正常筛选不受影响，页面无需再维护一份图标互斥状态。

## 移动子页 AppBar

`AppMobileSubpageShell(autoHideAppBar: true)` 让子页的 AppBar 随滚动收起：滚离顶部隐藏，向上滚不恢复，回到顶部才恢复。普通子页的 AppBar 高度动画到 0，内容区同步上移；immersive 子页的返回栏本来就悬浮在内容上，收起时只淡出，正文保持全幅铺底不位移。页面主滚动和 `TabBarView` / `PageView` 里的纵向列表都会驱动；更深的嵌套滚动不驱动。普通子页顶部 `SafeArea` 保持不变，内容不会进入状态栏区域。移动路由层对所有子页默认开启；个别需要常驻 AppBar 的子页可在路由数据里覆盖 `autoHideAppBar => false`。直接使用 shell 时该参数默认 false。

页面保留自己的滚动控制器、缓存键、Provider 和分页回调；不通过嵌套纵向列表或全量 `shrinkWrap` 网格实现固定栏。移动合集详情使用单个 `CustomScrollView` 承载封面、控制栏和成员瀑布流；封面与「播放全部」随内容滚走并在控制条下缘被裁切，排序控制条透明吸顶，底部批量操作条单独固定。

## 桌面一级页面保留

`DesktopBranchCache`（`lib/routes/desktop_branch_cache.dart`）配合桌面一级导航的 StatefulShellRoute，按最近访问顺序最多保留 8 个分支；未访问页面不挂载，详情不加入缓存。隐藏分支停用 TickerMode 和焦点，离开桌面 shell 时一起释放。

## TabBarView 页面保留

`AppKeepAlive` 位于 `lib/widgets/base/layout/keep_alive_page.dart`。它只保留已访问的 `PageView` / `TabBarView` 子页 Widget 生命周期，用于输入、滚动和局部交互在切换标签后恢复；不要用它把页面 Provider 提升为全局常驻状态。
