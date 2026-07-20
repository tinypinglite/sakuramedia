# media-player —— 视频播放统一入口

**任何视频播放都只走这里两层之一,别再写裸 `Video` / 自己嵌三层控制主题。**

## 一、两层复用(选一个)

### ThemedVideoPlayer(轻,大多数场景)
- **路径**: `lib/widgets/base/media/video/themed_video_player.dart`
- **用途**: **其余全部播放入口**(快播弹窗、单切片 / 单视频全屏页、切片 / 视频合集连播页)。调用方自建 `Player` / `VideoController` 传入,顶 / 底控制条按场景拼。
- **required**: `videoController` · `useTouchOptimizedControls`
- **可选**: `topControls`(默认 `[]`) · `bottomControls`(默认 `[]`) · `fullscreenBottomControls`(全屏态的底控件覆盖) · `videoKey` · `fit`(默认 contain) · `fill`(默认黑) · `displaySeekBar`(默认 true)
- **`useTouchOptimizedControls` 铁则**: **移动壳传 `true`(点击唤出控制条)、桌面 / 桌面弹窗传 `false`(hover 唤出)**。移动连播页是桌面页薄壳,**必须把该参数透传为 `true`**,否则触摸端 hover 唤不出进度条(历史 bug)。
- **组件内部**: 复用 `base/media/video/video_controls_theme.dart` 里的 `buildMoviePlayerXxxControlsThemeData` + `resolveMoviePlayerVideoControlsBuilder` 套统一主题(进度条 / 全屏 / 音量样式一致)。**改控制条样式**只改这里或那两个 themeData 构建函数,一处生效。

### MoviePlayerSurface(重,只影片播放页用)
- **路径**: `lib/widgets/domain/movies/player/movie_player_surface.dart`
- **用途**: **仅影片应用内播放页用**——自持 Player + 字幕 / 进度上报 / 缩略图圈选 / 播放信息。
- **required**: `movieNumber` · `resolvedUrl` · `surfaceController: MoviePlayerSurfaceController`
- **可选**: `initialPosition` · `onPositionChanged` · `onPlayingChanged` · `onCompleted` · `subtitleState` · `onSubtitleSelectionChanged` · `onSubtitleReloadRequested` · `onBackPressed` · `useTouchOptimizedControls`(默认 false)
- **何时用**: 影片播放页(桌面 / 移动)。**只有影片播放页用它**,别的地方一律 `ThemedVideoPlayer`。
- **族内文件分工(引擎 / UI / 装配三层,2026-07 拆分)**:`movie_player_surface.dart` 只是**装配宿主**(State = Player 生命周期 + stream 接线 + build),周边职责各归其文件——改哪类问题去哪个文件:
  - 引擎层(不依赖 material,可纯 Dart 测):`movie_player_media_source.dart`(来源 enum / UA / `buildMoviePlayerMedia` / 错误文案 / `buildMoviePlayerConfiguration`)、`movie_player_surface_coordinators.dart`(打开防竞态 / 字幕应用两协调器,**函数注入 media_kit 命令**——surface 直接把 `_player.open/play/seek/setSubtitleTrack` 传进来,不再有独立 driver 层)、`movie_player_resume_seek_coordinators.dart`(续播提示 + 起播 seek 重试两状态机)、`movie_player_playback_rate_coordinator.dart`(播放速率状态机:pending 保护 + rate 流去噪 + 移动端 speed display 快照)、`movie_player_mobile_drawer_coordinator.dart`(移动底部抽屉 + info side 三态互斥状态机)、`movie_player_native_stats_sampler.dart`(播放信息采样机:mpv 原生属性轮询 + 差分,输出 `ValueListenable<MoviePlayerPlaybackInfoSnapshot>`)、`movie_player_surface_readiness.dart`。
  - UI 层:`movie_player_controls.dart`(顶栏 / 桌面 / 移动底控制条 builder,**`buildMoviePlayerTopControls` 从这里 import**——切片 / 视频单播与合集连播页都用)、`movie_player_mobile_drawers.dart`(移动倍速 / 字幕抽屉 + 信息侧栏 overlay)、`movie_player_playback_error_overlay.dart`(播放失败覆盖层)、speed / subtitle button、playback_info 面板。
  - `movie_player_surface.dart` **不再 re-export 族内符号**——按上述分工直接 import 对应文件;测试也已按同缝镜像拆分(`test/widgets/domain/movies/player/` 一文件一测试,控制条主题测试在 `test/widgets/base/media/video/video_controls_theme_test.dart`)。

### MoviePlayerSurfaceController
- **路径**: `lib/widgets/domain/movies/player/movie_player_surface_controller.dart`
- **用途**: `MoviePlayerSurface` 的外部控制句柄(seek / play / pause / 请求缩略图之类)。业务侧持有并传给 surface。

### QuickPlayDialog + showVideoQuickPlayDialog
- **路径**: `lib/widgets/domain/media/quick_play_dialog.dart`
- **用途**: 桌面「点小图 → 弹小窗立刻播」的轻量播放弹窗——`AppDesktopDialog` 外壳 + `ThemedVideoPlayer` 播放器 + 空态 / 加载态。切片、视频列表卡、时刻缩略图共用。
- **QuickPlayDialog required**: `title` · `fallbackTitle`(标题为空时兜底) · `videoKey`(测试锚点) · `resolvePlayUrl(context)`(切片同步取 stream_url; 视频 async `GET /videos/{id}` 取首个可播源) · `noPlayableMessage`(resolver 返 null / 空时的空态文案)
- **可选**: `errorFallback`(resolver throw 时兜底)
- **`showVideoQuickPlayDialog(context, videoId, title)`**: 视频列表 / 时刻卡专用便捷函数,包好 videos_api + session_store 拉详情逻辑。切片走 [showClipPlayerDialog](./domain-widgets.md#showclipplayerdialog)。
- **别自己写**: `showDialog + Player() + VideoController + AppDesktopDialog` 那套骨架——一律走它。

## 二、缩略图 / 关键帧

### MovieMediaThumbnailGrid
- **路径**: `lib/widgets/domain/media/movie_media_thumbnail_grid.dart`
- **用途**: 缩略图网格核心(uniform16x9 / staggered 两种布局),支持"活动帧高亮 / 圈选(clip start/end)/ 长按右键菜单"。
- **required**: `thumbnails` · `isLoading` · `errorMessage` · `columns` · `activeIndex` · `isScrollLocked` · `onThumbnailTap` · `onRetry`
- **可选**: `onThumbnailMenuRequested` · `clipStartIndex` / `clipEndIndex` · `keyPrefix`(默认 `'movie-media'`) · `layout`(默认 `uniform16x9`)
- **何时用**: 影片播放页缩略图面板底层;合集连播页右侧关键帧面板底层。**不建议**外部单独用。

### MoviePlayerThumbnailPanel
- **路径**: `lib/widgets/domain/media/movie_player_thumbnail_panel.dart`
- **用途**: 完整缩略图面板壳(自动列 / 手动列切换、锁滚动、`activeIndex` 高亮、错误 + 重试)。内部用 `MovieMediaThumbnailGrid` 渲染。
- **required**: `thumbnails` · `isLoading` · `errorMessage` · `columns` · `activeIndex` · `isScrollLocked` · `usesAutoColumns` · `onAutoColumnsResolved` · `onColumnsChanged` · `onToggleScrollLock` · `onThumbnailTap` · `onRetry`
- **可选**: `onThumbnailMenuRequested` · `clipSelectionMode` · `clipStartIndex` / `clipEndIndex`
- **何时用**: 影片播放页右侧缩略图 pane;合集连播页右侧"整部合集"关键帧面板(**不传圈选回调→圈选 UI 隐藏**)。

## 三、合集连播(左播放 + 右关键帧)

### CollectionPlaySplitLayout
- **路径**: `lib/widgets/domain/collections/playback/collection_play_split_layout.dart`
- **用途**: 合集连播页**左右分栏壳**(`Area(0.72)/Area(0.28)` + `DividerPainters.grooved1`)。左 = player + `EpisodeSelectorOverlay`;右 = 关键帧面板。
- **required**: `keyPrefix` · `left` · `right`
- **何时用**: `desktop_{clip,video}_collection_play_page.dart` 的顶层布局。
- **注意**: 语义对齐 jav `_MoviePlayerSplitLayout` 但**独立实现**,jav 播放页不迁移到本组件。

### CollectionPlaybackPageMixin
- **路径**: `lib/widgets/domain/collections/playback/collection_playback_page_mixin.dart`
- **用途**: 合集连播页 State mixin——**共享**播放器登记(`attachPlayback`)、`dispose`、跨集 seek 补偿(`seekToFrame`/待办 `_pendingSeek`)、右面板构建(`buildFilmstripPanel`)、「选集」浮层开合状态(`isEpisodePanelOpen` / `openEpisodePanel` / `closeEpisodePanel`)。
- **何时用**: 新增合集连播场景一定要 `with` 它,别自己复制播放器登记 / 跨集 seek / 选集浮层开合。
- **注意**: `updatePosition` / 同集判定都用播放器**实时** `player.state.playlist.index`(非滞后的 `currentIndex`,position 流可能先于 playlist 流到);`seekToFrame` 覆盖待办时会先取消旧的一次性监听(防旧 offset 误 seek)。
- **`buildFilmstripPanel(onThumbnailMenuRequested:)`**: 桌面 video 合集页传菜单回调 → 右键 / 长按帧"添加时刻"(仅 pornbox 帧携真实 media/thumbnail id 时可用);切片合集页不传 → 无菜单。

### CollectionEpisodeQueueItem
- **路径**: `lib/widgets/domain/collections/playback/collection_episode_queue_item.dart`
- **用途**: 合集连播「选集」浮层内的一项(88 宽 16:9 封面 + 标题 + 副信息 + 当前集高亮 icon)。切片 / 视频两页公用。
- **required**: `itemKey` · `coverUrl`(可空) · `coverStyle: cover|containOnMuted`(切片 cover, pornbox contain 加灰底) · `title` · `subtitle`(切片时长 / video「第 N 集」) · `isCurrent` · `onTap`

### CollectionFilmstripController
- **路径**: `lib/widgets/domain/collections/playback/collection_filmstrip_controller.dart`
- **用途**: 把整个合集拉平成"一部完整长片"——按集顺序无缝拼接第 1…N 集全部关键帧成一条连续序列。渐进逐集加载、**优先拉起播集** `start(priorityEpisode:)`、`updatePosition(集, 集内秒)`→全局活动帧高亮、`resolveTarget(全局帧)`→所属集+集内秒;`thumbnails` 由 `_frames` 惰性派生并缓存。
- **何时用**: `CollectionPlaybackPageMixin` 内部持有;业务侧一般不直接 new,通过 mixin 用。

### EpisodeSelectorOverlay
- **路径**: `lib/widgets/domain/collections/playback/episode_selector_overlay.dart`
- **用途**: 合集连播页底栏"选集"按钮唤起的**剧集面板浮层**——右侧滑出、点遮罩 / 选集关闭、展开时自动滚动定位当前集。
- **required**: `isOpen` · `itemCount` · `currentIndex` · `itemBuilder(BuildContext, int)` · `onClose` · `title`
- **可选**: `itemExtent`(默认 72;**随系统字体缩放**放大,防双行标题溢出)
- **位置**: 现位于**左分栏面板内**(Video 的兄弟节点),media_kit 全屏会 push 独立路由把它盖住——故底栏"选集"按钮**只在窗口态出现**(`ThemedVideoPlayer.fullscreenBottomControls` 传一份去掉该按钮的列表)。**换集需先退出全屏**。
- **别混淆**: 与影片播放器右侧的"视频信息"抽屉(`buildMoviePlayerInfoSideDrawerOverlay`)**是两回事**,互不复用、勿混改。

### MergedPositionIndicator
- **路径**: `lib/widgets/domain/movies/player/merged_position_indicator.dart`
- **用途**: 合集"合并模式"下的全局位置指示器(把 N 集时长拼成一条,显示当前全局进度)。
- **required**: `player: Player` · `episodeDurationsSeconds: List<int>` · `onSeekGlobalSeconds(int)`
- **何时用**: `CollectionPlaybackMode.merged` 场景的进度条。

### showCollectionPlaybackModePicker
- **路径**: `lib/widgets/domain/collections/playback/collection_playback_mode.dart`
- **签名**: `Future<CollectionPlaybackMode?> showCollectionPlaybackModePicker({ required BuildContext context, bool useBottomDrawer = false })`
- **用途**: 弹出"播放模式选择器"(playlist / merged)。桌面走 dialog,移动传 `useBottomDrawer: true`。

## 四、播放器控制条按钮(通常只被 ThemedVideoPlayer 组合)

### MoviePlayerBackOverlay 一族
- **路径**: `lib/widgets/domain/movies/player/movie_player_back_overlay.dart`
- 组件: `MoviePlayerBackButton` · `MoviePlayerInfoButton` · `MoviePlayerCurrentNumberBadge` · `MoviePlayerBackWithNumberControl` · `MoviePlayerBackOverlay`
- **用途**: 播放器左上角"返回 / 信息 / 番号徽标"按钮组。
- **何时用**: 拼 `ThemedVideoPlayer.topControls`。

### MoviePlayerSpeedButton
- **路径**: `lib/widgets/domain/movies/player/movie_player_speed_button.dart`
- **required**: `currentRate` · `hasExplicitSelection` · `onRateSelected`
- **用途**: 倍速菜单按钮(0.5x/1x/1.25x/1.5x/2x)。

### MoviePlayerSubtitleButton
- **路径**: `lib/widgets/domain/movies/player/movie_player_subtitle_button.dart`
- **required**: `subtitleStateListenable` · `isApplyingListenable` · `onSubtitleSelected` · `onReloadRequested`
- **用途**: 字幕菜单按钮(列出可选轨道、切换、重新拉字幕)。
- **配合**: `MoviePlayerSurface` 通过 `subtitleState` 透传状态给它。

### MoviePlayerMenuItemRow
- **路径**: `lib/widgets/domain/movies/player/movie_player_menu_widgets.dart`
- **用途**: 播放器菜单 / 抽屉里的一行(左右留白 + 中央 label + 右侧勾选槽)。桌面 speed / subtitle 菜单项与移动 speed / subtitle 抽屉项四处逐字相同的骨架合并到此。
- **required**: `label` · `selected` · `checkColor`(桌面 & 移动 speed = accent token; 移动 subtitle = `Theme.colorScheme.primary`)
- **可选**: `labelKey` / `checkKey` / `checkSlotKey`(测试锚点) · `overflow` / `maxLines`(subtitle 传 ellipsis + 1) · `background`(桌面 hover 半透明 onMedia,移动无背景)
- **别自己拼**: 「SizedBox(sideGap) × 2 + Expanded(Center(Text)) + 勾选槽 + trailingGap」这套 row 骨架。

### landscape_player_system_ui.dart
- **路径**: `lib/widgets/domain/movies/player/landscape_player_system_ui.dart`
- **用途**: 移动横屏播放的系统 UI 隐藏/恢复工具(状态栏、导航栏、屏幕方向)。业务侧一般直接引用其中函数。

---

## 相关约定

- **两层选择铁则**: 影片播放页 → `MoviePlayerSurface`;其余所有(快播弹窗、单切片 / 单视频全屏页、切片 / 视频合集连播页) → `ThemedVideoPlayer`。
- `useTouchOptimizedControls`:移动壳 `true`、桌面 / 桌面弹窗 `false`。**别忘了透传**。
- 合集连播 = `CollectionPlaySplitLayout` + `with CollectionPlaybackPageMixin`;右面板走 `mixin.buildFilmstripPanel(...)`,不要另建关键帧组件。
- "选集"浮层 vs "视频信息"抽屉:**两回事,勿混改**。
- 深入规则见 `lib/widgets/CLAUDE.md` "播放器控制组件两层复用" / "合集连播页布局" 段。
