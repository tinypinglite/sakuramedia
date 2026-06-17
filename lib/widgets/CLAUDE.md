# lib/widgets/ — 共享组件

跨 feature 复用的展示/交互组件。token 体系见 `lib/theme/CLAUDE.md`。

## 核心边界:展示组件 vs 控制器

`widgets/` 下绝大多数是**纯展示/交互 widget,不持有业务数据来源**。数据由 `features/*/presentation/*controller.dart`(`ChangeNotifier`)持有,页面 `AnimatedBuilder` 监听后把**快照字段 + 回调**透传进来。widget 内部只有 UI 局部 state(hover、overlay、滚动、临时 loading)。
- **改 UI** 找 `widgets/`;**改加载/分页/状态机** 找 `features/*/presentation/`。
- 例外(合理越界):少数"对话框/检查器启动器"是胶水层,自己 `context.read<XxxApi>()` 组装控制器(如 `media/media_preview_dialog.dart`、`movie_detail/movie_detail_inspector_panel.dart`——后者在 `initState` new 4 个子控制器并 dispose)。复用时注意它们会**真实发起请求**,不是哑组件。

## 壳层与基础组件(`app_shell/` `forms/` `feedback/` `navigation/` `actions/`)

- 壳层:`AppDesktopShell`(Sidebar | TopBar+body)、`AppSidebar`(`Consumer<AppShellController>` 折叠;`AppSidebarItem` 含角标;只有 `notifications` 组 watch 全局未读数)、`AppTopBar`、`AppMobileShell` / `AppMobileSubpageShell`。`AppWindowDragArea` 条件导出(桌面 `window_manager` / web stub)。
- 表单:`AppButton`(variant×size,`isLoading`/`isSelected`)、`AppTextButton`(`emphasis`/`backgroundStyle`)、`AppIconButton`、`AppTextField`(聚焦**不变色**,只有 error 变色)、`AppSelectField<T>`(**自绘下拉**,自动判上下展开)。
- 导航/反馈:`AppTabBar`(`variant: auto` 读 `Provider<AppPlatform?>`)、`AppContentCard`、`AppEmptyState`(只接 `message`)、`AppBadge`、`AppSettingsGroup`/`AppSettingCell`/`AppSettingsRail`(国内 App 风设置页)、`AppPageFrame`、`showAppConfirmDialog`(**返回恒非空 `Future<bool>`**,可直接 `if(!confirmed) return`)、`AppDesktopDialog`、`AppBottomDrawer`。

## 图片组件——三选一,各读一次 blur

远程图有三个**互不通用**的入口,各自调 `resolveMediaUrl` 拼 baseUrl、各自读 `AppImageConfig.enableBlur/blurSigma` 包模糊:
1. **`media/masked_image.dart` `MaskedImage`** — 普通封面/缩略图的**唯一标准入口**(自动 decode 提示 + 占位/错误图)。
2. **`movie_detail/movie_plot_thumbnail.dart` `MoviePlotThumbnail`** — 剧情图专用(`ResizeImage` 按高解码 + 监听真实宽高比)。**与 `MaskedImage` 不可互换**:列表封面用它会多开销,剧情图用 `MaskedImage` 会丢比例。
3. **`media/app_image_fullscreen.dart`** — 全屏/画廊(`photo_view`)。`AppImageFullscreenHost` 必须**包在路由树高处**,触发器靠 `findAncestorStateOfType` 找它,找不到则全屏/抽屉静默失败。

> 改模糊逻辑要**同时改这三处**;加新图片组件记得同样接 blur,否则模糊设置对它无效。

图片右键/长按菜单统一走 `media/app_image_action_trigger.dart` + `showAppImageActionMenu`。

## 通用范式(多处一致,改一处想想要不要同步)

- **网格四态容器**(actor/video/ranked/moment/movie 等 Grid 一致):`LayoutBuilder` 按 `((w+spacing)/(target+spacing)).floor()` 算列数并钳位 + `shrinkWrap` + `NeverScrollableScrollPhysics`(外层滚动);四态顺序固定 **骨架→错误→空态(`AppEmptyState`)→内容**。列宽多用 token `movieCardTargetWidth`(image_search/moment 例外用裸值 220/280/300)。
- **批量选择**:卡片约定 `selectionMode`+`isSelected`(选中换 `selectionBorder`、宽度 1→2、叠勾选标记、隐藏菜单/拖拽手柄);Grid 持 `Set<int> selectedIds`。多选状态机复用 `selection/multi_select_state_mixin.dart`。
- **卡片「···」菜单**:右上角圆形 + 半透明黑底 + `PopupMenuButton`,菜单项靠回调是否 `null` 决定显隐。
- **弹窗**:顶层 `showXxxDialog(...)` 函数包 `showDialog`/`showAppBottomDrawer`。media_kit 播放弹窗(`ClipPlayerDialog`/`VideoQuickPlayDialog`)仍用 `showDialog` + `AppDesktopDialog` 包壳,但**播放器本体统一走 `movie_player/themed_video_player.dart` 的 `ThemedVideoPlayer`**(见下)。
- **播放器控制组件两层复用(统一入口)**:所有视频播放只走这两层之一,别再写裸 `Video` / 自己嵌三层控制主题。
  - **层级一(重)`MoviePlayerSurface`**:仅影片应用内播放页用,自持 Player + 字幕 / 进度上报 / 缩略图圈选 / 播放信息。
  - **层级二(轻)`ThemedVideoPlayer`**:其余全部播放入口(快播弹窗、单切片 / 单视频全屏页、切片 / 视频合集连播页)。调用方自建 `Player`/`VideoController` 传入,顶 / 底控制条按场景拼(合集有上一首 / 下一首,单片 / 弹窗没有);组件内部复用 `movie_player_surface.dart` 的 `buildMoviePlayerXxxControlsThemeData` + `resolveMoviePlayerVideoControlsBuilder` 套统一主题(进度条 / 全屏 / 音量样式一致)。
  - `useTouchOptimizedControls`:**移动壳传 `true`(点击唤出控制条)、桌面 / 桌面弹窗传 `false`(hover 唤出)**。移动连播页是桌面连播页的薄壳,必须把该参数透传为 `true`,否则触摸端 hover 唤不出进度条(历史 bug)。改控制条样式 / 按钮只改 `ThemedVideoPlayer` 或那两个 themeData 构建函数,一处生效。
- **合集连播「选集」浮层 `movie_player/episode_selector_overlay.dart`**:切片 / 视频合集连播页**不再用右侧常驻队列**,改为底栏(全屏按钮左侧)的「选集」按钮(`MaterialCustomButton`/`MaterialDesktopCustomButton`)唤出 `EpisodeSelectorOverlay`——右侧滑出剧集面板、点遮罩或选集关闭、展开时自动滚动定位当前集。两个合集页共用此组件,各传 `itemBuilder`(封面 + 名称 + 高亮 + 点击跳转)。**与影片播放器右侧的「视频信息」抽屉(`buildMoviePlayerInfoSideDrawerOverlay`)是两回事,互不复用、勿混改。**「选集」浮层是**页面级**的(Video 的兄弟节点),media_kit 全屏会 push 独立路由把它盖住——故底栏「选集」按钮**只在窗口态出现**(`ThemedVideoPlayer.fullscreenBottomControls` 传一份去掉该按钮的列表),全屏态不放,避免死按钮;换集需先退出全屏。`EpisodeSelectorOverlay` 行高(`itemExtent`)随系统字体缩放放大,防双行标题在放大字号下溢出。

## ⚠️ 重复实现多(copy-paste 警告)

封面「···」菜单(clip/collection/video/member 四份)、选择勾选标记(两份)、Overlay 筛选骨架(`ActorFilterToolbar`/`RankingFilterToolbar` 两份高度雷同)、网格列数自适应(5+ 份)、URL/文件大小 helper(多份)**均为复制粘贴**。改观感/行为要**逐处同步**。注意 `collections/CollectionMemberMenu` 已抽公共版而其它三处未抽,别误以为同一组件。

## Widget Key 约定(强约束)

几乎每个可测节点都有稳定 `Key`,命名 `{domain}-{component}-{id}` / `{keyPrefix}-thumb-{index}`(`keyPrefix` 让同一网格在不同上下文产生不同 key)。播放器/详情有大量 `@visibleForTesting` 导出函数。**改名/删 Key/改导出签名 = 破测试**,改前先看对应 test。

## 与测试的关系

`test/widgets/` 与子目录一一对应,但覆盖**不均**:`app_shell`/`forms`/`movie_*`/`media` 较全;**`clips`/`collections`/`clip_collections`/`moments`/`rankings`/`batch` 几乎无 widget 测试**——改这些目录没有回归网,需手动验证或补测试。改 token 旁路查 `test/theme/`。
