# media-player —— 视频播放和合集连播

## 播放器入口

- `ThemedVideoPlayer`：`lib/widgets/base/media/video/themed_video_player.dart`，轻量、主题化的视频播放器，适合普通播放入口。
- `MoviePlayerSurface` / `MoviePlayerSurfaceController`：`lib/widgets/domain/movies/player/`，影片播放页使用的完整播放器 surface。
- `QuickPlayDialog` / `showVideoQuickPlayDialog`：`lib/widgets/domain/media/quick_play_dialog.dart`，从卡片或动作菜单快速播放。

## 应用内全屏

带右侧面板的播放页不能用 media_kit 的原生全屏（它 push 的独立路由只含 `Video`，面板会丢）：

- `PlayerAppFullscreenScope` / `PlayerAppFullscreenButton` / `PlayerAppFullscreenDoubleTap` / `PlayerAppFullscreenStateMixin`：`lib/widgets/base/media/video/player_app_fullscreen.dart`，桌面端在当前路由内切换布局 + 叠加系统窗口全屏，Esc 退出；移动端不渲染全屏按钮。
- 播放页 `State` mix `PlayerAppFullscreenStateMixin`，用 scope 暴露状态，并在 `dispose` 首行调 `disposePlayerAppFullscreen()`；`ThemedVideoPlayer` / `MoviePlayerSurface` 传 `disableNativeFullscreen: true` 关掉 media_kit 的双击全屏，避免两套全屏打架。
- 无 scope 时按钮回退 media_kit 原生全屏（快播弹窗等无面板场景行为不变）。
- 移动端播放页进入时默认锁横屏并隐藏系统栏，底栏不提供应用内全屏按钮；移动影片页始终纯黑全出血，右侧缩略图面板默认展开。移动影片播放页和视频单播页右上角提供横竖屏切换按钮，切换后右侧缩略图面板自动收起，仍可用面板开关重新展开。竖屏时控制条自动收窄：番号压缩，底栏隐藏音量与时间文本，避免小屏溢出。
- 移动端控制层接入 `media_kit` 的左半屏拖动亮度、右半屏拖动媒体音量手势，使用其内置百分比浮层。亮度只改当前 App 并在播放面销毁时恢复，音量保持系统设置。
- 窗口层那一半在 `lib/app/app_window_fullscreen.dart`：macOS / Windows 都走
  window_manager 的原生 `setFullScreen`（Windows 无边框由 runner 的
  `WM_NCCALCSIZE` 实现，只去可见框、不动窗口样式），移动端 / 测试环境没有
  窗口插件时吞掉异常。

播放器的媒体来源、字幕、续播、控制条和进度上报由播放器 surface、feature Provider 和页面共同完成。不要在列表卡片里直接复制播放器配置。

## 缩略图

- `MovieMediaThumbnailGrid`：媒体缩略图网格。
- `MoviePlayerThumbnailPanel`：播放器旁的缩略图面板。
- `CollapsiblePlayerSplitView`：播放器左右分栏共享壳。桌面与移动端的右侧面板默认展开，右上角常显纯图标开关（与顶栏同一行）可收起/再展开；双端顶栏会为开关和横竖屏按钮预留位置与间距，避免右上角操作互相覆盖。

两者位于 `lib/widgets/domain/media/`，缩略图请求和切片动作由调用方提供。

当前帧在统一缩略图网格中用主题主色 3px 内描边、1px 高对比外环和右上角播放角标标记；角标仅做视觉提示，不拦截点击与菜单。切片起止角标仍在左上角，可与当前帧角标同时出现。

## 合集连播

- `CollectionPlaySplitLayout`：左侧播放器、右侧整部合集面板的布局。
- `CollectionPlaybackPageMixin`：合集连播页共用的播放器登记、跨集定位和面板接线。
- `CollectionEpisodeQueueItem`：选集队列条目，可传入尾部操作；播放标记会移到副标题旁。
- `CollectionFilmstripController`：合集胶片条和跨集位置计算，移除成员时复用缓存并丢弃过期帧请求。
- `EpisodeSelectorOverlay`：选集浮层，打开时定位当前集。PornBox 通过根导航浮层让窗口和全屏共用选集管理。
- `MergedPositionIndicator`：合并后的整部进度指示。

这些组件位于 `lib/widgets/domain/collections/playback/` 或其关联的 player 目录。切片合集和视频合集通过闭包传入各自的数据，不要让共享组件依赖某个具体 API。

## 播放器控制

`MoviePlayerBackOverlay`、`MoviePlayerScreenRotationButton`、`MoviePlayerSpeedButton`、`MoviePlayerSubtitleButton` 和 `MoviePlayerMenuItemRow` 位于 `lib/widgets/domain/movies/player/`。移动端控制条需要保留触控唤起行为，桌面端可以使用 hover/鼠标行为；平台参数由页面壳传入。倍速/字幕菜单和移动端右侧抽屉统一使用 `AppSurface` 的全站唯一材质，不再维护独立的播放器玻璃组件。

播放区方向以实际布局约束为准（`player_viewport.dart`），不要直接用 `MediaQuery.orientationOf` 判断：iOS 从横屏切竖屏后 MediaQuery 可能滞后，会把竖屏顶栏误用横屏的非紧凑宽度，导致旋转/信息按钮被面板开关覆盖。紧凑顶栏、底栏和旋转按钮方向共用同一份布局判定。

## 播放信息

`MoviePlayerPlaybackInfoPanel` 复用播放器实际采样，独立展示播放模式、流类型和原始解复用格式。流类型为 HLS、HTTP 文件流或未确认，不通过 URL 后缀猜测 HLS，也不把 MP4/MKV 当作 HTTP Range 的证据。

HTTP(S) 播放中，解复用格式 `mkv` 与 `matroska` 均识别为 HTTP 文件流。

`MediaPlaybackInfoButton` 位于 `lib/widgets/domain/media/`，供 PornBox 单播/合集和切片单播/合集复用。控制条的信息按钮在窗口与全屏中均可打开同一侧面板；切换合集成员时重置采样并忽略过期结果。媒体网关播放地址使用 `withPlaybackAttemptId` 生成本次播放标识，模式查询失败时显示未确认；切片固定由后端提供文件。
