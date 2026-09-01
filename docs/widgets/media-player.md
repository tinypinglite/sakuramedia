# media-player —— 视频播放和合集连播

## 播放器入口

- `ThemedVideoPlayer`：`lib/widgets/base/media/video/themed_video_player.dart`，轻量、主题化的视频播放器，适合普通播放入口。
- `MoviePlayerSurface` / `MoviePlayerSurfaceController`：`lib/widgets/domain/movies/player/`，影片播放页使用的完整播放器 surface。
- `QuickPlayDialog` / `showVideoQuickPlayDialog`：`lib/widgets/domain/media/quick_play_dialog.dart`，从卡片或动作菜单快速播放。

播放器的媒体来源、字幕、续播、控制条和进度上报由播放器 surface、feature Provider 和页面共同完成。不要在列表卡片里直接复制播放器配置。

## 缩略图

- `MovieMediaThumbnailGrid`：媒体缩略图网格。
- `MoviePlayerThumbnailPanel`：播放器旁的缩略图面板。

两者位于 `lib/widgets/domain/media/`，缩略图请求和切片动作由调用方提供。

## 合集连播

- `CollectionPlaySplitLayout`：左侧播放器、右侧整部合集面板的布局。
- `CollectionPlaybackPageMixin`：合集连播页共用的播放器登记、跨集定位和面板接线。
- `CollectionEpisodeQueueItem`：选集队列条目。
- `CollectionFilmstripController`：合集胶片条和跨集位置计算。
- `EpisodeSelectorOverlay`：选集浮层。
- `MergedPositionIndicator`：合并后的整部进度指示。

这些组件位于 `lib/widgets/domain/collections/playback/` 或其关联的 player 目录。切片合集和视频合集通过闭包传入各自的数据，不要让共享组件依赖某个具体 API。

## 播放器控制

`MoviePlayerBackOverlay`、`MoviePlayerSpeedButton`、`MoviePlayerSubtitleButton` 和 `MoviePlayerMenuItemRow` 位于 `lib/widgets/domain/movies/player/`。移动端控制条需要保留触控唤起行为，桌面端可以使用 hover/鼠标行为；平台参数由页面壳传入。
