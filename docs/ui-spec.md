# SakuraMedia UI 实现基线

## 1. 文档目的

本文档描述的是当前 `sakuramedia` 代码库里已经存在的 UI 实现基线，而不是未来产品全景规范。

如果文档与代码冲突，以以下实现为准：

- `lib/theme.dart`
- `lib/theme/*.dart`
- `lib/widgets/app_shell/*`
- `lib/widgets/*`
- `lib/features/**/presentation/*`

后续更新 UI 时，应优先修改代码与 token，再同步更新本文档。

## 2. 当前产品形态

当前仓库是一个桌面优先的 Flutter 管理台，核心体验围绕桌面端工作台展开。

当前状态：

- 桌面端：已实现登录、工作台壳层、概览、女优上新、影片、女优、时刻、播放列表、排行榜、热评、活动中心、搜索、详情、配置管理
- 移动端：已接入底部四导航（概览/影片/女优/榜单）与首页顶部 Tab（我的/关注/发现/时刻/热评）；首页左上角已接入抽屉菜单入口（数据源 / 媒体库 / 下载器 / 索引器 / LLM 配置 / 播放列表 / 修改用户名 / 修改密码 / 退出登录）；“我的”已实现搜索栏、最近添加和播放列表，且已接入影片详情页、播放列表详情页与搜索子页；`/mobile/library/movies`、`/mobile/library/movies/:movieNumber`、`/mobile/library/actors`、`/mobile/library/actors/:actorId`、`/mobile/rankings`、`/mobile/settings/data-sources`、`/mobile/settings/media-libraries`、`/mobile/settings/downloaders`、`/mobile/settings/indexers`、`/mobile/settings/llm`、`/mobile/settings/playlists`、`/mobile/settings/username` 与 `/mobile/settings/password` 为真实页面，其余 `/mobile/settings/*` 仍以移动端专属占位子页为主
- Web 端：复用桌面端路由与壳层（`/desktop/*`），页面能力与桌面端保持一致，活动中心同样复用桌面实现

因此，本规范默认以桌面端为主进行描述。移动端当前已接入影片列表/详情、女优列表/详情、排行榜与播放器主链路；Web 端复用桌面实现，但桌面窗口拖拽、窗口初始化等系统级能力在浏览器端降级为无效果。

活动中心首版当前边界：

- 已实现独立桌面/Web 页面 `/desktop/system/activity`
- 已实现通知中心与任务中心的 REST 首屏加载，以及在线事件流增量刷新
- 通知列表与任务历史当前均为滚动触底自动加载更多；加载更多失败时保留当前内容并在底部提供重试入口
- 通知仅按分类筛选与展示，当前分类包括信息、警告、错误、提醒；通知不再存在独立等级维度
- 通知当前采用“进入视口后自动已读”的交互，不再提供单独的“标记已读”按钮，前端也不再展示未读数、读状态筛选或已读/未读视觉差异
- 任务分页仅作用于“任务历史”区块；顶部“活动任务”区块继续使用一次性加载加实时更新
- 尚未实现顶栏 badge、概览卡片、下载导入联动、任务详情弹层

## 3. 视觉总基调

- 整体是浅色、克制、偏管理后台的工作台风格
- 桌面端页面主背景为浅灰，内容区以白色卡面承载；移动端页面主背景统一为纯白
- 品牌强调色为棕红色系，主要用于主操作、选中态和少量重点信息
- 非 macOS 平台下，侧边栏使用独立的浅灰底色，和内容区形成明显分层
- macOS 桌面端侧边栏使用原生 vibrancy 毛玻璃作为底层材质，并叠加轻半透明 tint
- 图片卡片与详情头图允许使用更强的遮罩与深色渐变

当前视觉上不是纯 Material 默认风格，但仍以 Material 基础能力为底座实现。

## 4.6 影片详情页剧情图交互

当前影片详情页剧情图实现包括：

- 页面剧情图条带支持点击缩略图打开预览：桌面端使用 `Dialog`，移动端使用底部抽屉
- 页面剧情图条带支持长按或右键打开图片动作菜单
- 预览主图支持长按或右键打开图片动作菜单，仅图片本体区域可触发（不包含留白黑底）
- 预览内容底部缩略图条带支持点击切换当前预览图
- 预览内容底部缩略图条带同样支持长按或右键打开图片动作菜单
- 移动端预览抽屉与详情检查面板统一复用共享底部抽屉组件（`showAppBottomDrawer` / `AppBottomDrawerSurface`）
- 移动端剧情图预览与单图预览当前都支持轻点主图进入全屏图片 overlay；剧情图全屏态支持左右滑动切换图片，并支持长按当前图打开进入全屏前相同的图片动作菜单
- 全屏态支持继续缩放与拖拽，支持轻点关闭或下滑退出全屏

当前剧情图图片动作菜单只包含：

- `相似图片`
- `保存到本地`

## 4. 主题与 token

### 4.1 主主题入口

统一主题入口位于 `lib/theme.dart`。

当前主题导出包括：

- `sakuraThemeData`：兼容旧调用，固定指向桌面 / Web 主题
- `sakuraDesktopThemeData`：显式桌面 / Web 主题
- `sakuraMobileThemeData`：显式移动主题

应用启动时会按 `AppPlatform` 自动选 theme：

- `desktop` / `web` 使用 `sakuraDesktopThemeData`
- `mobile` 使用 `sakuraMobileThemeData`

公共 token 通过 `ThemeExtension` 暴露，当前包括：

- `AppColors`
- `AppSpacing`
- `AppRadius`
- `AppShadows`
- `AppComponentTokens`
- `AppFormTokens`
- `AppNavigationTokens`
- `AppOverlayTokens`
- `AppLayoutTokens`
- `AppSidebarTokens`
- `AppTextScale`
- `AppTextWeights`
- `AppTextPalette`
- `AppPageInsets`

业务页面和共享组件应通过 `context.appColors`、`context.appSpacing` 等扩展读取，不直接散落裸值。

当前仓库已经增加源码守卫测试，非 `lib/theme/**` 文件禁止新增以下视觉字面量：

- `Color(...)`
- `fontSize: <number>`
- 带数字字面量的 `EdgeInsets.*(...)`
- `BorderRadius.circular(<number>)` / `Radius.circular(<number>)`

### 4.2 颜色基线

当前代码中的关键颜色如下：

- `primary`: `#6B2D2A`
- `surfacePage`: `#F5F5F5`
- `surfaceCard`: `#FFFFFF`
- `surfaceElevated`: `#FFFFFF`
- `surfaceMuted`: `#F1F1F1`
- `noticeSurface`: `#F3F3F3`
- `desktopSidebarGlassTint`: `#4CEFEFEF`
- `desktopSidebarGlassHover`: `#80FFFFFF`
- `desktopSidebarGlassActive`: `#99FFFFFF`
- `sidebarBackground`: `#D7D9D9`
- `sidebarHoverBackground`: `#C3C5C5`
- `sidebarActiveBackground`: `#C3C5C5`
- `borderSubtle`: `#E5E5E5`
- `borderStrong`: `#D6D6D6`
- `divider`: `#E8E8E8`
- `selectionSurface`: `#EAF3FF`
- `infoSurface`: `#EFF6FF`
- `warningSurface`: `#FFF4E5`
- `errorSurface`: `#FFF1EF`
- `errorAccentForeground`: `#F04438`
- `successSurface`: `#ECFDF3`
- `subscriptionHeartIcon`: `#D44B5C`
- `movieCardSubscribedBadgeBackground`: `#F97316`
- `movieCardPlayableBadgeBackground`: `#1677FF`
- `movieDetailPlayableBadgeBackground`: `#1677FF`
- `mediaOverlaySoft`: `#14000000`
- `mediaOverlayStrong`: `#85000000`
- `mediaMaskOverlay`: `#E6000000`

电影详情页还有一组专用语义色，例如：

- `movieDetailSelectedPlotBorder`
- `movieDetailInvalidMediaBackground`
- `movieDetailReleaseDateIcon`
- `movieDetailScoreIcon`
- `movieDetailHeatIcon`

新增详情页视觉语义时，优先扩展 `AppColors`，不要直接在页面里硬编码。

### 4.3 Typography 体系

当前仓库的文本规则已收敛为“固定六档字号 + 固定字重 token + 统一文本色 tone”：

- `AppTextScale` 是字号真源
- `AppTextWeights` 是字重真源
- `AppTextPalette` 是文本前景色真源
- `AppText` / `resolveAppTextStyle` 是业务文本入口，负责组合字号、字重和 tone
- `TextTheme` 仍保留，但仅作为由 `AppTextScale` + `AppTextWeights` 派生出的兼容层
- `sakuraThemeData` 仍可直接用于桌面 / Web 测试与非平台上下文

当前固定字号档位只有：

- `s20`
- `s18`
- `s16`
- `s14`
- `s12`
- `s10`

字号固定规则如下：

- `s20`: 20 / 600
- `s18`: 18 / 600
- `s16`: 16 / 默认字重
- `s14`: 14 / 默认字重
- `s12`: 12 / 默认字重
- `s10`: 10 / 默认字重

字重 token 固定为：

- `regular`: `w400`
- `medium`: `w500`
- `semibold`: `w600`

当前颜色 tone 固定为：

- `primary`
- `secondary`
- `tertiary`
- `muted`
- `accent`
- `onMedia`
- `info`
- `warning`
- `error`
- `success`

它们直接映射到 `AppTextPalette`：

- `primary`: `#1F1A18`
- `secondary`: `#342D2A`
- `tertiary`: `#4D4440`
- `muted`: `#6B625E`
- `accent`: `#6B2D2A`
- `onMedia`: `#FFFFFF`
- `info`: `#175CD3`
- `warning`: `#B54708`
- `error`: `#B42318`
- `success`: `#027A48`

对应底层 `TextTheme` 当前统一由 `AppTextScale` + `AppTextWeights` 派生，兼容映射如下：

- `displaySmall` / `headlineSmall` / `titleLarge` -> `s20` + `semibold`
- `titleMedium` -> `s18` + `semibold`
- `titleSmall` -> `s16` + `regular`
- `bodyLarge` / `bodyMedium` -> `s14` + `regular`
- `bodySmall` -> `s12` + `regular`
- `labelLarge` -> `s14` + `regular`
- `labelMedium` -> `s12` + `regular`
- `labelSmall` -> `s10` + `regular`

共享组件接入原则：

- 普通文本优先走 `AppText`
- 表单、按钮、Tab、详情页主内容等需要 `TextStyle` 的场景统一走 `resolveAppTextStyle`
- 业务页面不再使用语义兼容层或 `context.appTypography.*`
- 静态文本色优先用 `tone`，只有动态 alpha 或运行时状态色才允许在 resolver 结果上再做 `copyWith`
- 只有 Flutter / Material 或第三方组件兼容场景才通过 `TextTheme` 间接消费这些字体 token

### 4.4 间距、圆角、阴影

间距：

- `xs`: 4
- `sm`: 8
- `md`: 12
- `lg`: 16
- `xl`: 24
- `xxl`: 32
- `xxxl`: 40

圆角：

- `xs`: 4
- `sm`: 8
- `md`: 12
- `lg`: 16
- `pill`: 999

阴影：

- `card`: 轻卡片阴影
- `panel`: 侧栏与面板阴影

页面内的留白优先使用：

- `AppPageInsets.desktopStandard = 24`
- `AppPageInsets.compactStandard = 8`

表单与导航补充 token：

- `AppFormTokens.labelGap = 8`
- `AppFormTokens.compactFieldHeight = 36`（移动端为 `40`）
- `AppFormTokens.menuItemHeight = 40`（移动端为 `44`）
- `AppNavigationTokens.desktopTabHeight = 40`
- `AppNavigationTokens.compactTabHeight = 32`
- `AppNavigationTokens.mobileTopTabHeight = 48`（移动端主题为 `52`；移动端顶部 Tab 复用 `compact` 的指示器/分隔线/文本色规则，但保留更高的触达高度与居中对齐）

### 4.5 结构尺寸 token

当前几个关键尺寸：

- 桌面顶栏高度：`56`
- 侧边栏展开宽度：`220`
- 侧边栏折叠宽度：`72`
- 侧边栏项高度：`44`
- 统计卡最小宽度：`150`
- 统计卡最大宽度：`190`
- 列表卡目标宽度：`160`
- 列表卡宽高比：`0.7`
- 详情页 hero 高度：当前可视高度的 `30%`
- 详情页窄封面宽度：`180`
- 剧照缩略图：`132 x 88`
- 演员头像尺寸：`58`
- 播放列表横幅高度：`100`
- 播放列表相关弹窗宽度：`520`
- 更多信息弹窗宽度：`960`
- 更多信息弹窗最小高度：`560`
- 详情页底部信息栏最小高度：`42`
- 移动端通用底部抽屉默认高度比例：`0.9`
- 移动端底部导航高度：桌面兼容值 `52`，移动主题值 `56`
- 移动端顶部 Tab 外层容器高度：桌面兼容值 `48`，移动主题值 `52`
- 移动端子页返回按钮区域宽度：桌面兼容值 `40`，移动主题值 `44`
- 移动端首页最近添加卡片宽度：桌面兼容值 `142`，移动主题值 `148`
- 移动端关注影片卡高度：桌面兼容值 `150`，移动主题值 `158`
- 移动端关注影片窄封面宽度：桌面兼容值 `96`，移动主题值 `100`
- 移动端关注影片剧照缩略图宽度：桌面兼容值 `86`，移动主题值 `90`
- 通用小弹窗宽度：`420`
- 通用中弹窗宽度：`520`
- 索引器/活动页筛选宽度档位：`160 / 180 / 200 / 220`
- 通用浮层菜单宽度档位：`144 / 188`

与字体感知强相关的尺寸也已平台化联动：

- `AppComponentTokens.buttonHeightMd / Sm / Xs`
- `AppComponentTokens.buttonHorizontalPaddingMd / Sm / Xs`
- `AppComponentTokens.buttonGapMd / Sm / Xs`
- `AppComponentTokens.movieDetailBottomBarMinHeight`
- `AppComponentTokens.playlistBannerHeight`
- `AppComponentTokens.mobileBottomNavHeight`
- `AppComponentTokens.mobileTopTabHeight`
- `AppFormTokens.compactFieldHeight / miniFieldHeight / menuItemHeight`
- `AppNavigationTokens.compactTabHeight / mobileTopTabHeight / desktopTabLabelTrailingPadding`

规则是：

- 桌面 / Web 保持更高信息密度
- 移动端在上调正文、Tab、按钮、输入框字号时，同步上调高度和 padding，避免“字变大但壳不变”

新增会影响复用和视觉稳定性的尺寸时，应优先进入 `AppComponentTokens`、`AppFormTokens`、`AppNavigationTokens`、`AppOverlayTokens` 或 `AppLayoutTokens`，不要以页面名新增私有常量。

### 4.6 Icon Size 基线

当前 icon size 统一使用 `AppComponentTokens` 的全局尺寸层级：

- `iconSizeXs = 16`
- `iconSizeSm = 18`
- `iconSizeMd = 20`
- `iconSizeLg = 22`
- `iconSizeXl = 24`
- `iconSize2xl = 32`
- `iconSize3xl = 36`
- `iconSize4xl = 44`

规则：

- 图标尺寸优先复用这套全局 scale，不再新增 feature-specific 的 icon size token
- 结构尺寸和 icon size 分开管理，例如 `movieCardStatusBadgeSize` 仍然保留为结构 token
- 页面、共享组件和主题扩展里都不应再散落 `size: 18`、`size: 20` 这类裸值

### 4.7 Icon Button 基线

当前共享 icon button 统一使用 `AppIconButton`。

视觉基线来自桌面搜索框右侧原有的小尺寸 icon button：

- 圆角矩形容器
- 默认透明背景、透明边框
- 选中态使用白色卡面背景和实线边框
- 默认图标色为弱化文本色，选中态提升到主文本色
- 通过 `compact` / `regular` 两档结构尺寸控制点击区域，不引入第二套视觉皮肤

当前以下场景都已经收敛到这套共享组件：

- 侧边栏和顶栏的 icon action
- 搜索框内的搜索 / 图片搜索 / 在线切换按钮
- 以图搜图页顶部 toolbar
- 输入框 suffix 中的可见性切换按钮
- 各类弹窗和预览中的关闭 / 辅助操作按钮

桌面端弹窗当前统一复用 `AppDesktopDialog` 基座，右上角关闭按钮由基座提供，业务弹窗不再重复内嵌桌面关闭入口。

弹窗与抽屉基座留白规则：

- 桌面端 `AppDesktopDialog` 统一提供内容内边距 `24`（`spacing.xl`）
- 移动端 `showAppBottomDrawer` / `AppBottomDrawerSurface` 统一提供内容内边距 `16`（`spacing.lg`）
- 移动端底部抽屉统一使用自绘 slim handle（`28x3`，上/下间距各 `6`），不再使用 Flutter 默认 `showDragHandle`
- 共享底部抽屉默认保持顶部安全区；预览/详情型移动端抽屉可显式关闭顶部安全区，仅保留底部安全区，避免抽屉顶部出现额外大片留白

## 5. 桌面端工作台结构

### 5.1 窗口基线

桌面端启动逻辑在 `lib/app/bootstrap.dart`：

- 默认窗口尺寸：`1280 x 800`
- 最小窗口尺寸：`1280 x 800`
- macOS 使用隐藏式 title bar
- macOS 窗口背景为透明，左侧侧边栏区域通过原生 `NSVisualEffectView.sidebar` 提供 vibrancy 材质

因此当前桌面布局默认建立在较宽工作台上，不需要先为窄桌面做压缩式设计。
Web 端复用同一套壳层和页面结构，但浏览器环境下不启用窗口初始化与拖拽行为。

### 5.2 壳层结构

桌面端统一使用：

- 左侧 `AppSidebar`
- 顶部 `AppTopBar`
- 右侧内容区

标准页面内容区默认应用 `24` 的页边距。只有特殊页面才应使用全屏布局。

### 5.3 侧边栏规则

当前侧边栏具备以下能力：

- 展开 / 折叠切换
- 顶部保留 toggle 按钮
- 内置搜索入口
- 中部展示一级导航
- 底部展示“系统版本”轻量信息块，作为壳层可信状态信息；展开态显示客户端 / 服务端版本，折叠态仅保留信息图标与 tooltip
- 底部固定退出登录按钮

视觉上：

- macOS 桌面端：侧边栏面板本体使用半透明 tint，hover / active 项使用更亮的半透明覆盖色
- 非 macOS 桌面端：继续使用当前浅灰实底和实色 hover / active 背景

桌面端当前一级导航有十个：

- 概览
- 女优上新
- 影片
- 女优
- 时刻
- 播放列表
- 排行榜
- 热评
- 活动中心
- 配置管理

不要假设当前桌面端已经支持多级折叠导航；现实现阶段是稳定的一层入口。

### 5.4 顶栏规则

顶栏只负责：

- 展示当前页面标题
- 承载返回按钮
- 作为桌面窗口拖拽区域

当前没有全局操作区、用户菜单区和复杂工具栏。

### 5.5 路由分层与返回规则

当前路由交互按“主导航 / 子流程”分层：

- 主导航页面（`/desktop/overview`、`/desktop/library/follow`、`/desktop/library/movies`、`/desktop/library/actors`、`/desktop/library/moments`、`/desktop/library/playlists`、`/desktop/library/rankings`、`/desktop/library/hot-reviews`、`/desktop/system/configuration`）统一使用 `go`
- 子流程页面（详情页、系列影片页、播放器页、桌面搜索页、以图搜图页）统一使用 `push`
- 路由身份以 URL 为准；页面来源不再通过 `extra.fallbackPath` 传递，`extra` 只保留给非 URL 的临时载荷场景
- 移动端主导航由 `StatefulShellRoute.indexedStack` 承载四个分支（概览 / 影片 / 女优 / 榜单），分支内列表状态与滚动位置按分支保留
- 移动端子流程页（搜索、以图搜图、播放列表详情、影片详情、系列影片、女优详情、播放器）统一挂在根导航器之上，显示为全屏子页面并隐藏底部导航

当前返回规则统一为：

- 优先 `pop` 返回上一级子流程历史
- 无可 `pop` 历史时，回退到该路由的 canonical 入口
- 影片详情与系列影片默认回影片列表；女优详情默认回女优列表；播放列表详情默认回概览；搜索和以图搜图默认回概览；播放器默认回对应影片详情
- 因此，从列表/搜索/以图搜图结果页继续进入详情时，返回只依赖真实历史栈，不再依赖手工来源字符串

弹层不参与页面路由分层：`Dialog` / `BottomSheet` 继续走 `showDialog`、`showAppBottomDrawer` 与 `Navigator.pop`，不做 URL 路由化。

## 6. 页面模式

### 6.1 登录页

登录页是独立页面，不使用桌面壳层。

当前模式：

- 页面背景使用浅灰到主色容器的柔和渐变
- 中间是最大宽度 `460` 的半透明白色卡片
- 表单项使用 `AppTextField`
- 登录按钮使用主题主色

登录页是当前唯一明显带背景渐变和居中认证卡片的页面。

### 6.2 概览页

概览页结构固定为：

- 系统信息统计条
- 最近添加影片区块

统计信息使用 `OverviewStatsStrip`，当前包含系统汇总指标与 JoyTag 状态指标（健康、推理设备、待索引数量）；影片使用 `MovieSummaryGrid`。JoyTag 指标在 image-search 接口请求中显示平台自适应 loading 图标，请求失败后降级到“不可用 / 未知 / 不可用”。这是当前首页主模式，不要额外拼出第二套首页布局语言。

桌面端/Web 端“所有订阅女优最新影片”能力当前作为独立一级入口“女优上新”（`/desktop/library/follow`），不在桌面概览页复刻移动端顶部 Tab 的“关注”结构。

移动端概览当前规则：

- 移动端壳层 `AppMobileShell` 统一为页面内容应用 `AppPageInsets.compactStandard`
- 移动端壳层 `AppMobileShell` 统一处理页面安全区（`top + bottom`），页面本身不再重复包裹 `SafeArea`
- 移动端壳层 `AppMobileShell` 统一显式设置状态栏/底部系统栏样式，保证与子路由 `AppBar` 的沉浸观感一致
- 移动端首页额外在左上角提供菜单按钮，打开左侧抽屉；当前抽屉只在 `/mobile/overview` 提供，不扩展到影片 / 女优 / 榜单一级页
- 移动端子页壳层 `AppMobileSubpageShell` 同样统一处理 `top + bottom` 安全区
- 移动端壳层与子页壳层默认背景统一使用 `surfaceCard`（纯白）
- 顶部使用 `AppTabBarVariant.mobileTop`，Tab 维持 `我的 / 关注 / 发现 / 时刻 / 热评`，视觉规格复用 `compact`，仅 `tabAlignment` 为居中
- 首页抽屉当前菜单结构：
  - 顶部概览菜单：`概览`
  - 常规菜单：`数据源`、`媒体库`、`下载器`、`索引器`、`LLM 配置`、`播放列表`、`修改密码`
  - 版本与服务卡片：展示客户端 / 服务端版本，服务端未返回时显示 `--`，不作为可点击菜单入口
  - 底部固定操作：`退出登录`
- 抽屉菜单视觉使用接近 iOS 设置页的分组列表结构：顶部为菜单分组卡片，底部为独立操作分组；每行包含前置图标和标题，同组项之间使用轻分割线，不展示右侧 chevron
- 点击首页抽屉中的任一菜单项后，会以入栈方式进入对应移动端子页：`/mobile/system/overview`、`/mobile/settings/data-sources`、`/mobile/settings/media-libraries`、`/mobile/settings/downloaders`、`/mobile/settings/indexers`、`/mobile/settings/llm`、`/mobile/settings/playlists`、`/mobile/settings/password`
- `/mobile/system/overview` 已实现为真实移动端系统概览页：顶部为“系统概览”说明卡，中部按“媒体资产 / 服务健康”分组展示 PC 概览同源系统信息；媒体资产包含影片总数、可播放影片、女优总数、媒体文件、资源库、媒体总量；服务健康包含 JoyTag 健康、推理设备、待索引、数据源授权、授权中心、外部数据源；授权中心与外部数据源保留显性“检测”按钮；该页不包含“最近添加”，移动端最近添加仍只属于首页“我的”Tab
- `/mobile/settings/data-sources` 已实现为真实数据源配置页：顶部为授权概览卡，展示授权状态、授权有效期与授权中心连接状态；中部为激活授权表单卡，激活码默认隐藏且支持显示/隐藏；刷新状态、测试连接、同步授权作为显性次级按钮展示，底部固定主 CTA 为“激活授权”；诊断信息默认收起，展开后展示实例 ID、错误码、后端说明与授权中心测试详情；激活码仅用于本次请求，前端不做持久化
- `/mobile/settings/media-libraries` 已实现为真实媒体库配置页：白底子页内先展示说明卡，再展示媒体库卡片列表；页面底部固定全宽“新增媒体库”按钮；支持下拉刷新；卡片点击默认进入编辑抽屉，更多菜单提供“编辑媒体库 / 删除媒体库”；新增与编辑统一使用底部抽屉表单，删除使用确认抽屉
- `/mobile/settings/downloaders` 已实现为真实下载器页：顶部使用概览卡和双 Tab（下载器 / 接入说明），列表卡片点击后打开详情抽屉，新增 / 编辑 / 删除统一使用底部抽屉
- `/mobile/settings/indexers` 已实现为真实索引器页：页面顺序为 Jackett 概览卡、API Key 配置卡、索引器卡片列表；API Key 单独保存；新增 / 编辑通过底部抽屉即时提交；删除使用确认抽屉；如果索引器绑定的下载器已失效，会在卡片和详情抽屉中明确提示“绑定下载器已失效，请重新选择”
- `/mobile/settings/indexers` 不提供整页草稿保存；索引器新增 / 编辑 / 删除都会直接调用 `/indexer-settings` 保存当前完整配置，并以服务端回包覆盖本地状态
- `/mobile/settings/indexers` 在没有下载器配置时，会禁用底部“新增索引器”按钮，并在页面内显式提示先去下载器页创建下载器
- `/mobile/settings/llm` 已实现为真实 LLM 配置页：顶部为概览卡，说明当前入口名称保持通用 LLM 配置，但当前接入的是影片信息翻译共享配置，接口路径仍为旧命名 `/movie-desc-translation-settings`；中部使用单卡片表单维护启用状态、Base URL、API Key、模型、请求超时与连接超时；当前 Base URL 示例统一写为 `https://ollama.com`，模型占位统一写为 `gemma4:31b-cloud`；底部固定双按钮分别执行“测试配置”和“保存配置”
- `/mobile/settings/llm` 允许直接用当前草稿调用 `/movie-desc-translation-settings/test` 做连通性与返回结构测试，不要求先保存；测试成功或失败后会在页内概览卡更新最近一次测试状态，并同时使用 toast 给出反馈
- `/mobile/settings/password` 已实现为真实修改密码页；`/mobile/settings/playlists` 已实现为真实播放列表管理页：顶部为说明 + 统计卡，中部为自定义播放列表管理卡片列表，底部固定“新建播放列表”按钮；新建、编辑、删除均走底部抽屉即时提交，不复用桌面配置页
- 移动端媒体库 / 下载器 / 索引器 / LLM / 修改密码页顶部说明卡统一使用 `AppColors.noticeSurface` 浅灰底色和 `borderSubtle` 边框，不再复用 `primaryContainer` 的粉色容器底
- 移动端修改密码页使用白底子页布局：顶部为安全提示块，中部为当前密码 / 新密码 / 确认新密码三项表单，底部为吸底全宽主按钮“确认修改”
- 移动端修改密码页提交逻辑与桌面端账号安全保持一致：调用 `/account/password` 修改成功后，会立即用新密码走一次登录校验；校验成功则清空当前登录态并返回 `/login`，校验失败则提示“密码已修改，但新密码登录校验失败，请重新登录确认”
- 移动端修改密码页的轻量反馈统一使用 toast，不额外引入页内错误面板
- 点击首页抽屉中的“退出登录”后，会清空当前登录态并返回 `/login`
- “我的”Tab 当前内容：
  - 顶部搜索栏（复用 `CatalogSearchField`）
  - 最近添加（横向 `MovieSummaryCard` 列表）
  - 播放列表（纵向 `PlaylistBannerCard` 列表）
  - 播放列表支持长按拖拽排序，顺序保存在本地并按 `baseUrl`（站点）隔离；后端新增列表会在本地排序末尾追加
  - 长按进入可拖拽状态时会触发一次触感反馈（best effort，不支持震动时静默降级）
- “关注”Tab 当前内容：
  - 数据源：`GET /movies/subscribed-actors/latest`（分页）
  - 列表样式：专属关注卡片（非通用 `MovieSummaryCard`）
    - 上半区为“左侧细封面 + 4px 间距 + 右侧横向剧照条”
    - 左上角保留订阅切换 icon，支持直接订阅/取消订阅
    - 下半区展示摘要与元信息（番号 / 发行日期 / 可播放）
  - 剧照与摘要按可见卡片懒加载影片详情并做本地缓存；失败时降级为无剧照基础态
  - 点击卡片会入栈到 `/mobile/library/movies/:movieNumber`，返回优先依赖真实历史栈
- 点击“我的”Tab 内播放列表卡片后，会以入栈方式进入移动端播放列表详情页 `/mobile/overview/playlists/:playlistId`
- 移动端子路由（当前包括 `/mobile/search`、`/mobile/search/:query`、`/mobile/search/image`、`/mobile/settings/media-libraries`、`/mobile/settings/downloaders`、`/mobile/settings/indexers`、`/mobile/settings/llm`、`/mobile/settings/playlists`、`/mobile/settings/password`、`/mobile/overview/playlists/:playlistId`、`/mobile/library/movies/:movieNumber`、`/mobile/library/actors/:actorId`）统一使用标准顶栏（`AppBar`）并隐藏底部导航
- 移动端子路由返回规则统一为：优先 `pop` 返回上一级；无历史栈时按路由类型回到默认入口，系统返回手势与顶部返回按钮保持一致
- 移动端播放列表详情页当前结构：
  - 标准顶栏（返回 + 标题“播放列表详情”）
  - 播放列表横幅
  - 影片数量
  - 影片网格与分页加载反馈（复用桌面端详情页的数据加载与卡片网格模式）
- “发现”当前仍为占位内容
- “时刻”Tab 已接入全局时刻列表：顶部排序（`最新 / 最早`）使用共享文字按钮 + 总数 + 缩略图网格 + 底部分页反馈
- 移动端“时刻”卡片点击后打开底部抽屉预览，复用共享预览组件；动作包含：相似图片、保存到本地、删除标记、播放、影片详情
- 移动端“时刻”预览中的“相似图片”会跳转 `/mobile/search/image`；选中的源图通过临时 draft store 关联到路由 query 中的 `draftId`
- “热评”Tab 复用热评列表页能力（周期切换、分页、空态/错误态）；周期切换按钮与桌面端统一使用共享文字按钮；点击热评卡片会入栈跳转到移动端影片详情
- “热评”Tab 网格为响应式列数：窄屏单列、宽屏双列（不复用桌面端最小双列规则）
- “我的”Tab 内搜索提交会以入栈方式进入移动端搜索路由 `/mobile/search(/:query)`，连续不同关键词提交会形成可逐条返回的搜索历史
- “我的”Tab 的图片搜索入口会先拉起系统相册；选择成功后以入栈方式进入 `/mobile/search/image` 并写入 `draftId`，取消选择则留在当前页
- `/mobile/search/image` 页内“选择图片 / 更换图片”同样走系统相册选择
- “我的”Tab 最近添加、移动端搜索结果、移动端播放列表详情中的影片卡片均已改为入栈跳转移动端影片详情，并按真实历史栈回退
- 移动端影片详情页已接入详情主体与检查面板（评论 + 磁力搜索 + 缩略图 + MissAV 缩略图）；演员点击会入栈进入移动端女优详情页
- 移动端影片详情底部状态条为贴底全宽样式（无左右留白）；剧情图预览走底部抽屉
- 移动端影片详情已接入独立播放器页（`/mobile/library/movies/:movieNumber/player`），播放器是根级全屏子流程页，并复用现有播放器主体与缩略图面板
- 进入移动端播放器后会锁定横屏；退出播放器时按进入前方向类别恢复（进入前竖屏恢复竖屏，进入前横屏恢复横屏）
- 移动端播放器进入后启用沉浸模式并隐藏系统状态栏（电量/时间等）；退出播放器时恢复常规系统栏显示
- 移动端播放器沿用 `media_kit` 控件体系与默认手势行为；顶部保留集成式返回入口，底部右侧提供“倍速 / 字幕 / 全屏”入口。点击“倍速”或“字幕”后，会在播放器区域内部从右侧滑出对应抽屉菜单（不锚定整页，不使用 hover 浮层，不额外叠加自定义整屏手势层）
- 移动端以图搜图结果预览已接入：相似图片、保存到本地（系统相册）、影片详情；当结果含 `media_id` 时展示“播放”并跳转播放器，缺失 `media_id` 时不展示“播放”

### 6.3 影片页 / 女优页

这两个页面共享同一种“筛选 + 统计 + 卡片网格 + 分页加载”模式：

- 顶部筛选条
- 右侧总数
- 下方网格卡片
- 滚动触底加载更多
- 失败时保留内容并显示底部重试条

`MovieFilterToolbar` 当前由 1 个筛选按钮和 2 个快捷按钮组成，女优详情页会在筛选浮层内追加发行年份区块：

- 默认状态下左侧触发按钮显示 `全部`，并作为当前主态高亮
- `最新订阅`：状态筛选固定为 `已订阅`，合集类型固定为 `单体`，排序方式固定为 `订阅时间`
- `最新入库`：状态筛选固定为 `可播放`，合集类型固定为 `单体`，排序方式固定为 `最近入库`
- 快捷按钮与筛选浮层共用同一套 `status`、`collection_type`、`sort` 参数，点击后立即生效
- 女优详情页年份选项来自 `GET /actors/{actor_id}/years`，chip 显示为 `年份(数量)`，例如 `2026(18)`；选择年份后影片列表请求追加 `year`
- 顶部三颗按钮按单一主态处理：默认态高亮 `全部`；命中预设时只高亮对应预设；进入非预设自定义筛选时高亮左侧触发按钮
- 顶部触发器、快捷按钮与浮层内筛选项统一使用共享文字按钮；只有“重置”等操作型按钮保留 `AppButton`

当前网格列数依据容器宽度自动计算，范围是 `2` 到 `6` 列，目标卡宽为 `160`。

通用 `MovieSummaryCard` 当前已接入影片上下文菜单：

- 桌面端支持右键，移动端支持长按
- 当前覆盖：桌面影片列表、桌面女优上新、桌面女优详情影片列表、移动端影片列表、移动端女优详情影片列表
- 当前菜单项包含 `标记为合集/单体` 与 `将"{prefix}"加入合集特征`
- 打开菜单时会先请求 `GET /movies/{movie_number}/collection-status`，根据返回状态动态展示 `标记为合集` 或 `标记为单体`
- `标记为合集/单体` 会调用 `PATCH /movies/collection-type` 更新当前影片
- 点击后会从当前番号中提取数字前完整前缀，例如 `OFJE-888 -> OFJE-`、`FC2-PPV-1234567 -> FC2-PPV-`
- 菜单动作会先读取 `collection-number-features`，若特征不存在则追加保存，并立即触发合集重算
- 移动端首页“关注”Tab 仍使用专属 `MobileFollowMovieCard`，当前未接入该菜单

移动端影片/女优路由当前实现：

- `/mobile/library/movies`：`MovieFilterToolbar` + 总数（`X 部`）+ `MovieSummaryGrid` + 底部分页反馈（加载中 / 失败重试）
- 列表筛选即时生效，筛选参数沿用 `status`、`collection_type`、`sort`
- 移动端影片筛选入口保持桌面式 Overlay 浮层交互（不改为底部抽屉）
- 点击影片卡片会入栈到 `/mobile/library/movies/:movieNumber`
- `/mobile/library/actors`：`ActorFilterToolbar` + 总数（`X 位`）+ `ActorSummaryGrid` + 底部分页反馈（加载中 / 失败重试）
- 列表筛选即时生效，筛选参数沿用 `subscription_status`、`gender`、`sort`；默认展示已订阅女优并按 `subscribed_at:desc` 排序，筛选按钮同步展示当前订阅状态与排序条件
- 点击女优卡片会入栈到 `/mobile/library/actors/:actorId`
- `/mobile/library/actors/:actorId`：头部摘要（头像/名称/订阅/影片总数）+ `MovieFilterToolbar` + `MovieSummaryGrid` + 底部分页反馈（加载中 / 失败重试）
- 详情页影片筛选沿用 `status`、`collection_type`、`sort`，并支持按单个 `year` 过滤；请求固定携带 `actor_id`
- 详情页点击影片卡片会入栈到 `/mobile/library/movies/:movieNumber`
- 移动端影片 / 女优 / 榜单 / 时刻等可滚动列表页，以及移动端影片 / 女优 / 播放列表详情和首页 Tab，当前统一接入下拉刷新；刷新走控制器静默 `refresh()`，不会先清空内容或回退到骨架屏

### 6.4 搜索页

搜索页当前是桌面端内嵌内容页，不是弹层。

结构：

- 顶部搜索输入
- 侧边栏搜索框在桌面端额外提供图片搜索入口
- 搜索页顶部搜索框右侧展示外部数据源切换图标；当前该开关只影响影片搜索，选中后影片走在线搜索
- 在线搜索过程中，在搜索框和 `AppTabBar` 之间显示内联状态卡，承载 SSE 阶段信息与最终统计
- 下方 `AppTabBar`
- 内容区在“影片结果”和“女优结果”之间切换

搜索为空、失败、无结果时都使用统一空态承载。
影片搜索当前同时支持本地搜索与在线搜索两种路径；当查询被识别为女优搜索时，统一走在线搜索。
在线搜索最终结果仍在原有影片/女优结果区呈现，不单独弹出浮层。

### 6.5 桌面端以图搜图页

以图搜图页当前是桌面端独立内容页，路由为 `/desktop/search/image`。

结构：

- 顶部查询图卡片
- 查询图左侧缩略图 + 右侧 icon toolbar
- 可展开的大图预览区
- 可展开的高级筛选区
- 下方命中结果网格

顶部卡片当前固定提供三个操作：

- 更换图片：icon button，再次打开文件选择，选图后立即重新搜索
- 展示大图：icon button，在当前页内展开 / 收起大图预览
- 高级筛选：icon button，在当前页内展开 / 收起筛选面板

所有顶部 icon button 都保留 tooltip，不展示文字标签。

高级筛选当前支持：

- 当查询来源于影片详情页剧情图时，额外展示“当前影片范围”分组：
  - 全部
  - 仅当前影片
  - 排除当前影片
- 已订阅女优范围不过滤 / 仅包含所选 / 排除所选
- 通过标准 `Dialog` 选择已订阅女优
- 点击面板底部“搜索”后应用筛选，不做即时搜索

结果区当前仅实现命中缩略图网格，不包含旧项目里的完整预览画廊。
每个结果卡只展示结果图片和相似度角标，不再展示影片番号和命中时间。
点击结果卡后会打开结果预览层，而不是直接跳转影片详情页：

- 桌面端：居中 `Dialog`
- 移动端：底部抽屉（Bottom Drawer）

桌面端结果卡额外支持右键菜单；长按触发约束也已预埋，供后续移动端页面复用。

结果预览弹窗当前结构：

- 顶部结果大图
- 中部摘要栏：相似度、番号、命中时间
- 影片信息区：封面 + 演员横向列表
  - 演员按影片详情返回顺序展示
  - 当演员数量超出可用宽度时，演员区支持横向滚动
  - 无演员信息时退回展示影片标题
- 底部动作条（复用统一动作按钮组件）：
  - 相似图片：读取当前结果图并重新进入现有以图搜图页
  - 保存到本地：桌面端通过系统保存面板写入本地；移动端直接写入系统相册
  - 添加标记 / 删除标记：对当前 `media_id + thumbnail_id` 操作媒体书签
  - 播放：当 `media_id` 可用时进入独立播放器页，并从命中时间点开始播放
  - 影片详情：进入现有影片详情页

移动端“保存到本地”依赖相册权限，拒绝授权时会提示失败原因。

翻页当前通过滚动触底自动加载更多。
当首屏未填满视口时会自动补齐分页；自动补齐最多请求 5 页，且连续 2 次未产生可见新增结果后会静默停止自动补齐。
加载更多失败时保留当前结果，并在底部显示失败提示与重试入口。

### 6.6 时刻页

时刻页当前是桌面端独立内容页，路由为 `/desktop/library/moments`。

结构：

- 顶部左侧排序切换：`最新` / `最早`
- 顶部右侧总数
- 下方时刻缩略图网格
- 点击卡片后打开与以图搜图共用的结果预览弹窗
- 时刻卡片图片直接来自 `/media-points.items[].image`，不再额外请求 `/media/{media_id}/thumbnails`

当前不再区分旧项目里的 `JAV / 非JAV` 分段。

时刻卡片当前规则：

- 主体是缩略图大卡
- 底部固定半透明信息条
- 左下显示影片番号
- 右下显示命中时间点

时刻预览弹窗与以图搜图结果预览共享同一套结构，只是不展示相似度摘要；动作仍保留：

- 相似图片
- 保存到本地
- 删除标记
- 播放
- 影片详情

预览类弹窗统一复用共享的弹窗基座；时刻预览弹窗与以图搜图结果预览继续共享同一业务弹窗实现。
顶部主图默认按原图比例完整显示，不强制铺满；当图片比例与预览区不一致时允许留白，留白区域使用黑色背景承载图片。

删除标记后会关闭弹窗，并刷新当前时刻列表。

### 6.7 影片详情页

当前影片详情页已经形成比较明确的模块顺序：

- Hero 头图
- 剧照缩略图
- 番号与播放列表/合集入口
- 互动数（想看人数、看过人数、评分、评论数、热度、评分人数）
- 系列 · xxx（当详情返回 `series_id` 时可点击进入同系列影片页）
- 厂商 · xxx
- 导演 · xxx
- 描述文案（按 `desc_zh` → `summary` → `desc` 优先级展示，无值时隐藏）
- 标签
- 标签与媒体源统一使用紧凑 pill 样式，文字、圆角、内边距与换行间距保持一致
- 演员
- 媒体源
- 标签为静态 pill 展示；媒体源为可切换 pill，但尺寸规则一致
- 当前选中媒体源会在 pill 区块下方补充一行技术摘要，按 `视频编码 · 码率 · 帧率` 顺序展示；仅显示有值字段，不展示路径、进度、存储方式和容器信息
- 当前选中媒体源在技术摘要后紧跟一个危险态删除图标；桌面端点击后使用确认弹窗，移动端点击后使用底部确认抽屉
- 删除媒体会调用 `DELETE /media/{media_id}`，并在成功后刷新当前影片详情；前端按后端真实行为处理为“媒体条目直接消失”，不展示 `valid=false` 失效态
- 当前选中媒体源的技术摘要下方会先展示“时刻”小标题和横向时刻缩略图；无标记点时保留现有空态面板
- “相似影片”为独立区块，位于“媒体源”之后；当影片没有媒体源时，该区块仍然展示，并读取 `GET /movies/{movie_number}/similar?limit=15`，最多展示 15 个影片卡片，使用横向滚动
- 底部固定信息条

详情页允许比列表页使用更强的图片表现和更明显的内容分区，但仍保持浅色页面基底。
系列、厂商、导演当前采用单行内联文本展示（`字段名 · 值`），三者作为同一个信息组顺序堆叠，组内使用小于区块间距的统一行间距；当 `series_name`、`maker_name`、`director_name` 为空时，对应行直接隐藏，不显示占位文案。系列行仅在 `series_id` 与 `series_name` 同时可用时展示为可点击状态，并以轻量 chevron 强化可进入感；只有系列名没有系列 ID 时保持纯文本。
演员区块当前按 `gender` 分组展示：`gender == 1`（女优）优先，其余性别值随后展示；各分组内保持后端返回顺序不变。
详情信息区在保持现有模块顺序的前提下使用统一的纵向节奏：番号组、系列/厂商/导演信息组、标签、演员、媒体源、相似影片采用同一套区块间距 token；区块标题与内容之间使用独立的较小标题间距 token。
详情正文中的互动数行当前承载想看人数、看过人数、评分、评论数、热度、评分人数；其中热度使用火焰图标加数字的紧凑表达。
详情页 Hero 高度统一按当前可视区高度的 `30%` 计算；加载态与加载完成态使用同一规则，避免首屏跳变。
底部固定信息条当前承载发行日期、时长、评分、评分人数、评论数、想看人数，并保持固定在详情页底部，不跟随正文滚动。桌面端保持卡片样式，移动端为贴底全宽样式（无左右留白）。
点击底部固定信息条后，桌面端打开标准 `Dialog` 详情面板；移动端打开约 `90%` 高度的底部抽屉。两端共用同一套面板内容：`评论`、`磁力搜索`、`缩略图` 和 `Missav缩略图` 四个 Tab，默认打开 `评论`。评论 Tab 支持 `最热 / 最新` 排序切换，列表滚动到底部会自动触发下一页加载，分页失败时保留已有内容并提供重试入口；`磁力搜索` 需要手动触发搜索，按当前影片番号请求候选资源，并支持直接提交到索引器已绑定的下载器；`缩略图` 复用播放器的缩略图网格并支持大图预览，同时新增紧凑型时间间隔筛选（`10 / 20 / 30 / 60`，图标 + 数字按钮，无额外文字标签）；`Missav缩略图` 需要用户手动点击“开始获取”后才会发起 MissAV SSE 拉取，成功后展示只读帧图网格，点击仅切换当前高亮项、不弹出预览，不提供播放和标记动作，头部同样提供独立的紧凑型时间间隔筛选。移动端该详情抽屉关闭顶部安全区，仅保留底部安全区，内容从 handle 下方直接开始布局。
剧情图预览同样为双端差异化展示：桌面端 `Dialog`，移动端底部抽屉；两种展示形态复用同一套预览内容组件。移动端剧情图预览抽屉同样关闭顶部安全区，仅保留底部安全区。移动端剧情图、缩略图和单图抽屉主图都支持轻点进入全屏图片 overlay；剧情图全屏态支持左右滑动切图，并支持长按当前图打开进入全屏前相同的图片动作菜单；单图全屏态仅展示当前图片，不提供图片动作菜单。
详情面板内的缩略图默认列数会依据当前面板宽度自动计算，范围为 `2` 到 `5`；顶部不再重复显示“缩略图”或“MissAV 缩略图”标题文字，只保留紧凑工具条。普通缩略图工具条包含时间间隔筛选和 `2 / 3 / 4 / 5` 列切换；MissAV 工具条包含时间间隔筛选，以及按状态显示的“开始获取 / 重新获取 / 列切换”。时间间隔筛选默认选中 `10`，并按“首帧 + 步长”规则抽样当前网格。
详情面板内的缩略图网格保留左键大图预览，同时支持右键/长按菜单；菜单动作包含相似图片、保存到本地、添加/删除标记、播放。移动端“相似图片”会跳转到 `/mobile/search/image`，并回退到当前影片详情页。
番号右侧当前提供“标记合集/单体”与“加入播放列表”两个入口。合集入口会先读取 `GET /movies/{movie_number}/collection-status` 再决定按钮语义，点击后调用 `PATCH /movies/collection-type` 切换当前影片状态；播放列表入口保持原行为，桌面端打开播放列表选择弹窗，移动端打开底部抽屉。两端都只展示可手动维护的自定义播放列表，勾选与取消勾选都会实时请求后端，不额外提供统一保存按钮。
播放列表选择面板头部提供 `+` 入口，可在当前层内直接新建播放列表；创建成功后会立即把当前影片加入新列表。移动端的新建流程同样使用底部抽屉，不再弹出 `Dialog`。

当前详情页的播放入口应复用 Hero 头图中心的播放图标，不额外在“媒体源”区块下方新增独立主按钮。
媒体源区块当前只负责展示和切换媒体源，不承担单独主播放入口职责。

### 6.7.1 系列影片页

当前系列影片页由影片详情页的系列行进入，桌面端路由为 `/desktop/library/movies/series/:seriesId`，移动端路由为 `/mobile/library/movies/series/:seriesId`。

页面结构：

- 顶部紧凑标题卡：展示“系列影片”、系列名和影片总数
- 下方影片卡片网格，复用影片列表卡片、订阅按钮和卡片动作菜单
- 分页加载更多失败时保留已有列表，并在底部显示重试入口

首版不提供筛选或排序控件，即使后端 `POST /movies/by-series` 支持 `sort`；页面只按 `series_id` 请求同系列影片，路由中的 `seriesName` query 仅用于标题展示。标题优先使用路由传入的系列名，其次使用第一页影片返回的 `series_name`，最后兜底为 `系列 #id`。移动端支持下拉刷新，刷新失败使用 toast 提示。

### 6.8 播放列表页

当前桌面端播放列表页路由为 `/desktop/library/playlists`，模式为：

- 顶部标题 + `新建播放列表` 按钮
- 下方纵向播放列表横幅

播放列表横幅当前规则：

- 使用全宽横向卡片
- 背景优先使用该播放列表首部影片封面单图拉伸
- 背景图上叠加高斯模糊和深色遮罩
- 名称使用居中的大号白字
- 空列表或无封面时退回渐变占位底图
- 拖拽手柄使用 `unfold_more` 风格 icon，并在鼠标悬停到对应播放列表项时显示

本页当前支持浏览、创建和拖拽排序；排序结果本地持久化并按 `baseUrl`（站点）隔离。
播放列表的重命名和删除当前集中在配置管理页的“播放列表”Tab 完成。

### 6.9 播放列表详情页

当前播放列表详情页路由为 `/desktop/library/playlists/:playlistId`，模式为：

- 顶部播放列表横幅
- 横幅下方展示影片数量与描述
- 下方复用现有影片卡片网格

详情页中的影片网格继续沿用影片库和女优详情页的卡片样式、订阅按钮和分页加载反馈，不单独发明新的影片摘要样式。

### 6.10 桌面端播放器页

当前播放器页是桌面端独立沉浸页，不走 `AppDesktopShell` 的侧边栏和顶栏。

结构：

- 页面背景为深色沉浸式基底
- 中间内容使用左右双栏分割布局
- 左侧为视频播放区，使用深色媒体面板承载
- 左上角悬浮返回按钮
- 右上角信息按钮（`info` icon），入口跟随播放器顶部控件栏显示/隐藏
- 播放器底部右侧提供字幕按钮与全屏按钮
- 右侧为缩略图导航面板
- 缩略图导航面板顶部提供 `2 / 3 / 4 / 5` 列切换和锁定按钮
- 缩略图区域使用固定 `16:9` 比例卡片和纵向滚动网格
- 点击缩略图会跳转到对应的播放时间点

当前约束：

- 返回操作只通过左上角悬浮返回按钮承载，不在播放区域中心叠加大面积返回热区
- 信息按钮点击后在播放器区域内打开右侧信息抽屉（桌面端与移动端统一形态）；点击遮罩可关闭，抽屉内部点击不关闭
- 播放信息面板以约 `1s` 的频率实时刷新，展示核心技术字段：解码模式（硬解/软解）、视频/音频码率、视频帧率、音频采样率、编解码器、动态范围摘要（基于 `videoParams` 的 `primaries/gamma/light/sig-peak`）
- 右侧缩略图只展示当前选中媒体的缩略图，不在播放器页内切换媒体源
- 右侧缩略图默认列数依据当前面板宽度自动计算，范围为 `2` 到 `5`；本次播放器会话里一旦用户手动切换列数，后续优先保持手动值
- 缩略图锁定跟随默认开启；锁定时当前播放位置对应缩略图会自动滚动到视窗中部附近，并禁止用户手动滚动缩略图网格
- 解锁后保留当前滚动位置，用户可以手动浏览缩略图；播放器仍会更新高亮，但不会主动重置网格滚动位置
- 播放器缩略图网格按可视区懒构建；锁定态遇到远距离定位时优先直接跳到目标附近，避免沿途加载中间大量缩略图
- 用户拖动播放器缩略图滚动条或快速滚动时，缩略图卡片先展示占位；滚动停下后只恢复最终可视区域附近的图片加载
- 缩略图加载中展示骨架网格；失败时提供重试；空数据时展示空态
- 当前支持缩略图联动，并为缩略图提供桌面端右键菜单与移动端长按菜单；菜单动作包含相似图片、保存到本地、添加/删除标记、播放
- 字幕切换通过播放器底部右侧按钮完成，数据源来自 `GET /movies/{movie_number}/subtitles`；默认关闭字幕，仅支持外挂字幕，不在播放器页内切换媒体源；当前对后端 `.srt` 字幕先下载 UTF-8 文本，再注入 `media_kit`，字幕菜单勾选态以播放器应用成功为准
- 播放过程中会按固定间隔上报播放进度，并在退出播放器页时补报最后位置
- 播放控制条颜色仍需服从现有主题主色与 token

### 6.11 女优详情页

当前女优详情页是“头部摘要 + 关联影片列表”的模式：

- 头像
- 名称
- 订阅 icon（位于影片总数左侧，支持订阅/取消订阅）
- 影片总数
- 影片筛选条
- 影片卡片网格

不要单独发明与影片页完全不同的关联影片呈现方式。

### 6.12 配置管理页

配置页是当前最完整的表单管理页面，模式为：

- 顶部 `AppTabBar`
- 下方分 tab 内容
- 列表卡片 + 右下角主操作按钮
- 新建 / 编辑使用对话框
- 删除前使用确认弹窗

表单项统一复用 `AppTextField` 与 `AppSelectField`。

当前已实现的配置内容包括：

- 数据源 Tab：数据源 Provider 授权状态展示、状态刷新与激活码激活
- 媒体库 Tab：媒体库管理
- 合集特征 Tab：合集番号特征配置
- LLM 配置 Tab：影片信息翻译共享配置
- 账号安全 Tab：账号资料与密码修改
- 下载器 Tab：下载器列表与表单配置，表单包含客户端保存路径与本地访问路径
- 索引器 Tab：Jackett API Key 配置、索引器条目管理，以及每个索引器与下载器的绑定关系
- 播放列表 Tab：自定义播放列表管理（新建、编辑名称/描述、删除）

当前入口包括：

- 桌面端一级导航中的“配置管理”（`/desktop/system/configuration`）
- 移动端概览页抽屉中的“数据源 / 媒体库 / 下载器 / 索引器 / LLM 配置 / 播放列表 / 修改用户名 / 修改密码”子页（`/mobile/settings/data-sources`、`/mobile/settings/media-libraries`、`/mobile/settings/downloaders`、`/mobile/settings/indexers`、`/mobile/settings/llm`、`/mobile/settings/playlists`、`/mobile/settings/username`、`/mobile/settings/password`）

桌面端配置页顶部 Tab 已拆分为数据源、媒体库、合集特征、LLM 配置、账号安全、下载器、索引器、播放列表，默认进入数据源 Tab。账号安全页包含账号资料卡与密码修改卡：账号资料卡读取 `/account` 展示当前用户名、创建时间和上次登录时间，并通过 `PATCH /account` 修改用户名，保存成功后保持当前登录态；密码修改为内联表单，提交成功后会立即退出当前登录态并返回登录页。移动端修改用户名页使用说明卡、当前账号摘要、用户名表单和底部固定保存按钮，保存成功后同样保持当前登录态；移动端修改密码页保持独立子页。媒体库当前以列表卡片方式展示，新增 / 编辑通过对话框完成，删除前使用确认弹窗。合集番号特征使用多行文本维护（每行一个特征），保存前可选择“保存并立即重算合集”或“仅保存特征配置”；选择立即重算时，保存成功后会展示最近一次 `sync_stats` 统计。桌面端 `LLM 配置` Tab 字段包括启用状态、Base URL、API Key、模型、请求超时与连接超时；该 Tab 允许直接测试当前草稿，并在页内展示最近一次测试状态，但不会把测试状态持久化。当前接入的是影片信息翻译共享配置，接口路径仍沿用 `/movie-desc-translation-settings`，Base URL 示例当前统一写为 `https://ollama.com`，模型占位当前统一写为 `gemma4:31b-cloud`。数据源 Tab 读取 `/metadata-provider-license/status` 展示授权状态、授权有效期和授权中心连接状态，不在主界面展示本地租约过期时间或续租建议；诊断信息默认收起，展开后可查看实例 ID、错误码和授权中心测试详情。该 Tab 通过 `/metadata-provider-license/activate` 提交一次性激活码，通过 `/metadata-provider-license/renew` 执行客户可见的“同步授权”，并通过 `/metadata-provider-license/connectivity-test` 手动测试授权中心连接；激活码只在请求时使用，前端不做持久化。桌面端概览页的系统信息区同步展示“数据源授权”状态和“授权中心”连通性，授权中心支持手动测试连接，不提供激活入口。移动端数据源页接入同一组数据源授权接口，使用授权概览卡、激活表单卡、收起式诊断信息和底部固定“激活授权”主 CTA，刷新状态、测试连接、同步授权作为显性次级操作。下载器配置依赖媒体库列表，并将 qBittorrent 使用的客户端保存路径与后端访问文件时使用的本地访问路径拆分配置。桌面端索引器通过对话框新增 / 编辑，保存时需要为每个索引器选择一个下载器；如果当前还没有下载器配置，索引器新增入口会禁用并提示先去下载器 Tab 创建下载器。移动端索引器页则使用概览卡 + API Key 卡 + 卡片列表的工作台样式，API Key 单独保存，索引器新增 / 编辑 / 删除走底部抽屉即时提交，不提供整页统一保存。移动端 LLM 配置页使用概览卡 + 单卡表单 + 底部双 CTA 的工作台结构，允许直接测试当前草稿，并明确展示最近一次测试状态；当前该入口名称保持通用，但底层接入的是影片信息翻译共享配置，接口路径仍沿用 `/movie-desc-translation-settings`，Base URL 示例当前统一写为 `https://ollama.com`，模型占位当前统一写为 `gemma4:31b-cloud`。移动端播放列表页使用说明卡 + 管理卡片列表 + 底部固定 CTA 的工作台结构，仅展示自定义播放列表，并显式提供“查看详情 / 编辑 / 删除”动作；新建、编辑、删除均走底部抽屉即时提交。

移动端当前已落地的配置类子页包括数据源、媒体库、下载器、索引器与 LLM 配置，统一遵循以下模式：

- 顶部说明卡或接入引导卡
- 中部卡片式列表
- 底部固定主 CTA
- 新建 / 编辑通过 `Bottom Drawer` 表单完成
- 删除通过确认抽屉完成
- 列表卡点击后进入详情抽屉，详情抽屉底部直接提供 `编辑` / `删除` 操作

### 6.13 排行榜页

当前排行榜页已在桌面端与移动端落地，路由分别为 `/desktop/library/rankings` 与 `/mobile/rankings`，模式为：

- Web 端沿用桌面导航与页面实现，入口与路径同样为 `/desktop/library/rankings`
- 当前来源与榜单由后端接口动态返回；按当前实现基线，已开放来源为 `javdb` 与 `missav`
- 当前已开放榜单为：`javdb` 下的 `censored` / `uncensored` / `fc2`，以及 `missav` 下的 `all`
- 当前两个来源都支持 `daily` / `weekly` / `monthly`

- 顶部筛选触发按钮（来源 / 榜单 / 周期摘要）
- Overlay 浮层筛选面板（来源、榜单、周期三组按钮）
- 总数统计（`X 部`）
- 下方复用影片卡片网格 + 排名角标（右上角）
- 底部分页加载反馈（加载中 / 失败重试）

当前交互规则：

- 首屏按“来源 -> 榜单 -> 周期”顺序完成默认选择后再加载榜单条目
- 默认来源取第一个来源，默认榜单取该来源下第一个榜单
- 默认周期优先 `default_period`，否则取 `supported_periods` 第一个
- 筛选面板点选后立即生效并刷新列表，面板保持打开
- 点击榜单影片卡片入栈到影片详情页；若由榜单页进入则返回回到榜单页，若深链直达详情则按详情页默认入口回退

## 7. 共享组件基线

### 7.1 AppButton

当前按钮支持：

- 变体：`primary`、`secondary`、`ghost`、`danger`
- 尺寸：`medium`、`small`、`xSmall`、`xxSmall`、`xxxSmall`
- 图标、尾图标、加载态、选中态

优先用现有按钮变体表达操作层级，不要在页面里临时拼装新按钮皮肤。

### 7.1.1 AppTextButton

当前共享文字按钮特征：

- 轻量筛选与视图切换按钮，支持纯文字，也支持 `leading/trailing icon`
- 尺寸：`medium`、`small`、`xSmall`、`xxSmall`、`xxxSmall`
- 选中态为强调色文字 + 极浅主色背景
- 未选中态默认透明背景，可选 `muted` 轻灰底色
- 适用于轻量排序、视图切换、弱层级筛选，以及带图标的筛选触发器

当前补充约束：

- `muted` 未选中底色用于影片相关的顶部筛选按钮组，例如影片列表 / 女优详情中的 `全部 / 最新订阅 / 最新入库`
- 其它带图标的筛选触发器、排序切换、参数切换等场景默认仍使用透明未选中态，避免把所有文字按钮做成统一灰底

不要在业务页继续手写无边框排序按钮样式，优先复用它。

### 7.2 AppTextField

当前输入框特征：

- 浅灰填充背景
- 细边框
- 默认紧凑密度
- 支持 label、helper、prefix、suffix、校验态

登录页和配置页都已经基于这个组件构建。

### 7.3 AppIconButton

当前共享 icon button 特征：

- 支持 `compact`、`regular` 两种尺寸
- 支持 tooltip、选中态、禁用态
- 支持按场景覆写图标色、背景色、边框色
- 默认图标尺寸仍走 `AppComponentTokens.iconSizeMd`

页面里如果只是单个图标操作，不应再直接使用原生 `IconButton` 拼样式。

### 7.4 AppSelectField

当前不是系统原生下拉，而是自绘触发器 + Overlay 菜单。视觉上与 `AppTextField`
保持同一套表单语言：

- 浅灰填充背景
- 细边框与统一圆角
- placeholder / 已选值 / 错误态文本分层清晰
- 菜单锚定到触发器本身，不应出现明显下沉错位
- 桌面端支持 hover、高度受限滚动，以及靠近底部时向上展开

使用要求：

- 配置类表单优先复用它
- 不要在同一页面混用完全不同风格的下拉控件

### 7.5 AppTabBar

当前支持：

- `desktop`
- `compact`

视觉特征是细线型底部指示器，而不是胶囊式或大块背景切换。

`compact` 变体的首项不额外引入左侧 label padding，左对齐基线应由外层容器内容区决定，而不是由
Tab 自身制造额外 gutter。

### 7.5.1 Dialog / Drawer 容器边距

弹窗与底部抽屉的容器级外边距统一由宿主组件负责：

- `AppDesktopDialog` 负责桌面弹窗内容 gutter
- `showAppBottomDrawer` / `AppBottomDrawerSurface` 负责抽屉内容 gutter
- 内容组件只能定义容器内部各分区间距、卡片内边距、控件之间 spacing
- 内容组件不得通过根节点 padding 重新定义整体 gutter
- 复杂布局允许做满高、滚动、分栏，但不允许绕过宿主内容 gutter

### 7.6 AppEmptyState / AppContentCard / AppPageFrame

这三个组件分别负责：

- 空态承载
- 标准内容卡
- 页面头部与正文框架

占位页、错误页、说明性页面优先复用，而不是每个页面单独拼一套容器。

`AppEmptyState` 当前基线是简洁的单句居中文案，不带额外 card、icon 或 title。

### 7.7 列表卡片

`MovieSummaryCard` 与 `ActorSummaryCard` 是当前卡片网格的基础样式：

- 大图封面；影片卡优先使用后端 `thin_cover_image` 作为竖版封面，缺失时使用 `cover_image` 在现有竖卡比例内 `contain` 展示，不再裁取横图右侧区域
- 底部渐变遮罩
- 白字标题
- 左上角状态徽标
- 右上角热度徽标（火焰 icon + 数字；若存在榜单排名，则在排名徽标下方纵向堆叠）
- 轻卡片阴影

影片卡和女优卡是同一套视觉家族，后续新增同类卡片应尽量保持统一。当前热度徽标属于通用 `MovieSummaryCard` 的一部分，因此复用该卡片的影片场景会共享这一表现。

### 7.8 Pull To Refresh

当前移动端下拉刷新分为两层共享封装：

- `AppPullToRefresh` 基于 `RefreshIndicator` 封装
- `AppAdaptiveRefreshScrollView` 负责平台分流：
  iOS 使用 `CupertinoSliverRefreshControl`
  Android / Web / 桌面继续走 `AppPullToRefresh`
- `AppPullToRefresh` 的 spinner 颜色使用主题 `colorScheme.primary`
- `AppPullToRefresh` 的背景色使用 `surfaceCard`
- `AppPullToRefresh` 支持传入 `notificationPredicate` 适配嵌套滚动

使用约束：

- 共享内容组件默认不启用下拉刷新，只有移动端宿主显式开启时才接入
- iOS 需要原生下拉刷新的页面，优先通过 `AppAdaptiveRefreshScrollView` 提供 `slivers`
- 页面需要保留已有内容时，优先使用控制器静默 `refresh()`，不要复用会清空数据的 `reload()`
- 刷新失败保留当前内容，并通过 toast 反馈，不回退到骨架屏
- 需要下拉刷新的滚动容器应显式使用 `AlwaysScrollableScrollPhysics`
- 桌面端默认不启用 `CupertinoSliverRefreshControl`

## 8. 状态与反馈

当前实现里的状态表达规则：

- 初次加载：骨架屏或块级 skeleton
- 空数据：`AppEmptyState`
- 请求失败：页面空态或底部重试条
- 小型操作成功 / 失败：toast
- 订阅切换中：徽标位置显示 loading
- 加载更多：底部圆形进度指示器
- 移动端下拉刷新：保留现有内容，刷新结束后自动收起指示器；失败时 toast 提示

不要把所有失败都做成弹窗；当前基线是尽量在原上下文里完成提示和重试。

## 9. 后续 UI 开发规则

- 新页面优先放进现有桌面壳层，不要绕开 `AppDesktopShell`
- 新样式优先复用 `lib/theme/` token
- 新共享组件优先进入 `lib/widgets/`
- 如果只是一个 feature 的局部逻辑，不要提前抽成“全局设计系统”
- 如果某个值已经在多个页面重复出现，应尽快提升为 token 或共享组件

## 10. 不应写进文档的内容

以下内容目前不应被描述成既定规范：

- 移动端完整页面布局规则
- Web 端完整视觉差异规则
- 尚未实现的多级侧栏导航
- 尚未接入的下载任务、文件整理、UI Kit 页面成品能力

这些内容可以规划，但不能冒充当前代码库现状。
