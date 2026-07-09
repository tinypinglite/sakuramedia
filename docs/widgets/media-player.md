# media-player —— 视频播放统一入口

**任何视频播放都只走这里两层之一,别再写裸 `Video` / 自己嵌三层控制主题。**

## 一、两层复用(选一个)

### ThemedVideoPlayer(轻,大多数场景)
- **路径**: `lib/widgets/media_player/themed_video_player.dart`
- **用途**: **其余全部播放入口**(快播弹窗、单切片 / 单视频全屏页、切片 / 视频合集连播页)。调用方自建 `Player` / `VideoController` 传入,顶 / 底控制条按场景拼。
- **required**: `videoController` · `useTouchOptimizedControls`
- **可选**: `topControls`(默认 `[]`) · `bottomControls`(默认 `[]`) · `fullscreenBottomControls`(全屏态的底控件覆盖) · `videoKey` · `fit`(默认 contain) · `fill`(默认黑) · `displaySeekBar`(默认 true)
- **`useTouchOptimizedControls` 铁则**: **移动壳传 `true`(点击唤出控制条)、桌面 / 桌面弹窗传 `false`(hover 唤出)**。移动连播页是桌面页薄壳,**必须把该参数透传为 `true`**,否则触摸端 hover 唤不出进度条(历史 bug)。
- **组件内部**: 复用 `movie_player_surface.dart` 里的 `buildMoviePlayerXxxControlsThemeData` + `resolveMoviePlayerVideoControlsBuilder` 套统一主题(进度条 / 全屏 / 音量样式一致)。**改控制条样式**只改这里或那两个 themeData 构建函数,一处生效。

### MoviePlayerSurface(重,只影片播放页用)
- **路径**: `lib/widgets/media_player/movie_player_surface.dart`
- **用途**: **仅影片应用内播放页用**——自持 Player + 字幕 / 进度上报 / 缩略图圈选 / 播放信息。
- **required**: `movieNumber` · `resolvedUrl` · `surfaceController: MoviePlayerSurfaceController`
- **可选**: `initialPosition` · `onPositionChanged` · `onPlayingChanged` · `onCompleted` · `subtitleState` · `onSubtitleSelectionChanged` · `onSubtitleReloadRequested` · `onBackPressed` · `useTouchOptimizedControls`(默认 false)
- **何时用**: 影片播放页(桌面 / 移动)。**只有影片播放页用它**,别的地方一律 `ThemedVideoPlayer`。

### MoviePlayerSurfaceController
- **路径**: `lib/widgets/media_player/movie_player_surface_controller.dart`
- **用途**: `MoviePlayerSurface` 的外部控制句柄(seek / play / pause / 请求缩略图之类)。业务侧持有并传给 surface。

## 二、缩略图 / 关键帧

### MovieMediaThumbnailGrid
- **路径**: `lib/widgets/media_player/movie_media_thumbnail_grid.dart`
- **用途**: 缩略图网格核心(uniform16x9 / staggered 两种布局),支持"活动帧高亮 / 圈选(clip start/end)/ 长按右键菜单"。
- **required**: `thumbnails` · `isLoading` · `errorMessage` · `columns` · `activeIndex` · `isScrollLocked` · `onThumbnailTap` · `onRetry`
- **可选**: `onThumbnailMenuRequested` · `clipStartIndex` / `clipEndIndex` · `keyPrefix`(默认 `'movie-media'`) · `layout`(默认 `uniform16x9`)
- **何时用**: 影片播放页缩略图面板底层;合集连播页右侧关键帧面板底层。**不建议**外部单独用。

### MoviePlayerThumbnailPanel
- **路径**: `lib/widgets/media_player/movie_player_thumbnail_panel.dart`
- **用途**: 完整缩略图面板壳(自动列 / 手动列切换、锁滚动、`activeIndex` 高亮、错误 + 重试)。内部用 `MovieMediaThumbnailGrid` 渲染。
- **required**: `thumbnails` · `isLoading` · `errorMessage` · `columns` · `activeIndex` · `isScrollLocked` · `usesAutoColumns` · `onAutoColumnsResolved` · `onColumnsChanged` · `onToggleScrollLock` · `onThumbnailTap` · `onRetry`
- **可选**: `onThumbnailMenuRequested` · `clipSelectionMode` · `clipStartIndex` / `clipEndIndex`
- **何时用**: 影片播放页右侧缩略图 pane;合集连播页右侧"整部合集"关键帧面板(**不传圈选回调→圈选 UI 隐藏**)。

## 三、合集连播(左播放 + 右关键帧)

### CollectionPlaySplitLayout
- **路径**: `lib/widgets/media_player/collection_play_split_layout.dart`
- **用途**: 合集连播页**左右分栏壳**(`Area(0.72)/Area(0.28)` + `DividerPainters.grooved1`)。左 = player + `EpisodeSelectorOverlay`;右 = 关键帧面板。
- **required**: `keyPrefix` · `left` · `right`
- **何时用**: `desktop_{clip,video}_collection_play_page.dart` 的顶层布局。
- **注意**: 语义对齐 jav `_MoviePlayerSplitLayout` 但**独立实现**,jav 播放页不迁移到本组件。

### CollectionPlaybackPageMixin
- **路径**: `lib/widgets/media_player/collection_playback_page_mixin.dart`
- **用途**: 合集连播页 State mixin——**共享**播放器登记(`attachPlayback`)、`dispose`、跨集 seek 补偿(`seekToFrame`/待办 `_pendingSeek`)、右面板构建(`buildFilmstripPanel`)。
- **何时用**: 新增合集连播场景一定要 `with` 它,别自己复制播放器登记 / 跨集 seek。
- **注意**: `updatePosition` / 同集判定都用播放器**实时** `player.state.playlist.index`(非滞后的 `currentIndex`,position 流可能先于 playlist 流到);`seekToFrame` 覆盖待办时会先取消旧的一次性监听(防旧 offset 误 seek)。
- **`buildFilmstripPanel(onThumbnailMenuRequested:)`**: 桌面 video 合集页传菜单回调 → 右键 / 长按帧"添加时刻"(仅 pornbox 帧携真实 media/thumbnail id 时可用);切片合集页不传 → 无菜单。

### CollectionFilmstripController
- **路径**: `lib/widgets/media_player/collection_filmstrip_controller.dart`
- **用途**: 把整个合集拉平成"一部完整长片"——按集顺序无缝拼接第 1…N 集全部关键帧成一条连续序列。渐进逐集加载、**优先拉起播集** `start(priorityEpisode:)`、`updatePosition(集, 集内秒)`→全局活动帧高亮、`resolveTarget(全局帧)`→所属集+集内秒;`thumbnails` 由 `_frames` 惰性派生并缓存。
- **何时用**: `CollectionPlaybackPageMixin` 内部持有;业务侧一般不直接 new,通过 mixin 用。

### EpisodeSelectorOverlay
- **路径**: `lib/widgets/media_player/episode_selector_overlay.dart`
- **用途**: 合集连播页底栏"选集"按钮唤起的**剧集面板浮层**——右侧滑出、点遮罩 / 选集关闭、展开时自动滚动定位当前集。
- **required**: `isOpen` · `itemCount` · `currentIndex` · `itemBuilder(BuildContext, int)` · `onClose` · `title`
- **可选**: `itemExtent`(默认 72;**随系统字体缩放**放大,防双行标题溢出)
- **位置**: 现位于**左分栏面板内**(Video 的兄弟节点),media_kit 全屏会 push 独立路由把它盖住——故底栏"选集"按钮**只在窗口态出现**(`ThemedVideoPlayer.fullscreenBottomControls` 传一份去掉该按钮的列表)。**换集需先退出全屏**。
- **别混淆**: 与影片播放器右侧的"视频信息"抽屉(`buildMoviePlayerInfoSideDrawerOverlay`)**是两回事**,互不复用、勿混改。

### MergedPositionIndicator
- **路径**: `lib/widgets/media_player/merged_position_indicator.dart`
- **用途**: 合集"合并模式"下的全局位置指示器(把 N 集时长拼成一条,显示当前全局进度)。
- **required**: `player: Player` · `episodeDurationsSeconds: List<int>` · `onSeekGlobalSeconds(int)`
- **何时用**: `CollectionPlaybackMode.merged` 场景的进度条。

### showCollectionPlaybackModePicker
- **路径**: `lib/widgets/media_player/collection_playback_mode.dart`
- **签名**: `Future<CollectionPlaybackMode?> showCollectionPlaybackModePicker({ required BuildContext context, bool useBottomDrawer = false })`
- **用途**: 弹出"播放模式选择器"(playlist / merged)。桌面走 dialog,移动传 `useBottomDrawer: true`。

## 四、播放器控制条按钮(通常只被 ThemedVideoPlayer 组合)

### MoviePlayerBackOverlay 一族
- **路径**: `lib/widgets/media_player/movie_player_back_overlay.dart`
- 组件: `MoviePlayerBackButton` · `MoviePlayerInfoButton` · `MoviePlayerCurrentNumberBadge` · `MoviePlayerBackWithNumberControl` · `MoviePlayerBackOverlay`
- **用途**: 播放器左上角"返回 / 信息 / 番号徽标"按钮组。
- **何时用**: 拼 `ThemedVideoPlayer.topControls`。

### MoviePlayerSpeedButton
- **路径**: `lib/widgets/media_player/movie_player_speed_button.dart`
- **required**: `currentRate` · `hasExplicitSelection` · `onRateSelected`
- **用途**: 倍速菜单按钮(0.5x/1x/1.25x/1.5x/2x)。

### MoviePlayerSubtitleButton
- **路径**: `lib/widgets/media_player/movie_player_subtitle_button.dart`
- **required**: `subtitleStateListenable` · `isApplyingListenable` · `onSubtitleSelected` · `onReloadRequested`
- **用途**: 字幕菜单按钮(列出可选轨道、切换、重新拉字幕)。
- **配合**: `MoviePlayerSurface` 通过 `subtitleState` 透传状态给它。

### landscape_player_system_ui.dart
- **路径**: `lib/widgets/media_player/landscape_player_system_ui.dart`
- **用途**: 移动横屏播放的系统 UI 隐藏/恢复工具(状态栏、导航栏、屏幕方向)。业务侧一般直接引用其中函数。

---

## 相关约定

- **两层选择铁则**: 影片播放页 → `MoviePlayerSurface`;其余所有(快播弹窗、单切片 / 单视频全屏页、切片 / 视频合集连播页) → `ThemedVideoPlayer`。
- `useTouchOptimizedControls`:移动壳 `true`、桌面 / 桌面弹窗 `false`。**别忘了透传**。
- 合集连播 = `CollectionPlaySplitLayout` + `with CollectionPlaybackPageMixin`;右面板走 `mixin.buildFilmstripPanel(...)`,不要另建关键帧组件。
- "选集"浮层 vs "视频信息"抽屉:**两回事,勿混改**。
- 深入规则见 `lib/widgets/CLAUDE.md` "播放器控制组件两层复用" / "合集连播页布局" 段。
