# media & images —— 图片、预览和图片操作

## 图片展示

- `MaskedImage`：`lib/widgets/base/media/images/masked_image.dart`，带统一裁切、占位和远端 URL 处理的图片；首帧到达后淡入（内存缓存命中时直接显示），`borderRadius` 可为完整显示的图片添加贴合图片边缘的圆角。
- `AppImageFullscreenHost` / `AppPinchToFullscreenImage`：`app_image_fullscreen.dart`，全屏查看和缩放手势。
- `AppCoverBottomShade`：封面底部渐变遮罩。
- `AppCoverHoverInfo` / `AppCoverHoverInfoRow` / `AppCoverHoverActionBar` / `AppCoverHoverActionButton`：`lib/widgets/base/interaction/app_cover_hover_info.dart`，封面卡的桌面悬停披露层——收起态纯封面，指针悬停时底部渐显压暗层与信息（180ms，减弱动效时瞬时）；信息行是单行「主标签 + 副信息」，主标签先截断、副信息限宽后截断，避免大字体溢出；信息行下方是整行动作按钮（查看/播放/加入合集/移出/删除等按回调显隐），全站列表页与合集网格共用同一套。选择模式传 `enabled: false`，触摸端没有 hover 停在收起态。层内白字用同文件的 `resolveCoverOverlayTextStyle`。

影片详情专用的 `MoviePlotThumbnail` 位于 `features/movies/presentation/widgets/detail/`，不要因为它是图片就移动到 base。

## 图片操作

- `AppImageActionTrigger`：图片右键/长按操作入口。
- `AppImageActionDescriptor` / `buildImageActionMenuItems`：图片动作的领域描述符与统一菜单项构造；渲染走 `showAppActionMenu`（见 sheets-dialogs.md）。
- `AppImageActionType`：跨页面共用的图片动作枚举。
- `resolveGridColumnCount` / `resolveAppCardGridColumnCount`：根据可用宽度解析网格列数；后者读全站卡片网格统一规格（见 data-loading.md）。

实现图片保存、复制、外部打开等动作时，使用 core 的平台能力和现有 action menu，不在页面直接拼 URL 或写平台分支。

## 媒体预览

- `MediaPreviewDialog` / `showMediaPreviewOverlay`：`lib/widgets/domain/media/preview/media_preview_dialog.dart`，桌面 dialog 和移动 overlay 的统一入口。
- `PreviewImageStage`：预览主图区域。
- `MediaCenterPlayButton`：媒体封面中的可点击居中播放入口；只在确实可播放时放入封面 `Stack`。
- `MediaPreviewActionGrid` / `MediaPreviewActionTile`：预览动作区；预览数据请求期间可展示固定数量的动作骨架。影片信息区同时用封面和演员位置骨架占位。
- 图搜图预览启用 `useInlineNavigation`：封面进入影片详情，演员头像和姓名选择演员后关闭预览，由调用页跳转。底部隐藏重复的播放和详情动作；影片详情请求失败时保留详情入口。中央播放按钮保留，其它预览默认行为不变。
- `showMomentPreviewOverlay`：`lib/widgets/domain/moments/moment_preview_launcher.dart`，将时刻数据适配到
  `MediaPreviewDialog`；不另建一套预览 UI。

预览关闭后再执行导航或打开下一级弹层，避免旧弹层的 pop 影响新路由。具体动作由调用页面决定。
