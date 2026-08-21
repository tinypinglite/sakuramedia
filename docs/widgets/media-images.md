# media & images —— 图片、预览和图片操作

## 图片展示

- `MaskedImage`：`lib/widgets/base/media/images/masked_image.dart`，带统一裁切、占位和远端 URL 处理的图片。
- `AppImageFullscreenHost` / `AppPinchToFullscreenImage`：`app_image_fullscreen.dart`，全屏查看和缩放手势。
- `AppCoverBottomShade`：封面底部渐变遮罩。

影片详情专用的 `MoviePlotThumbnail` 位于 `features/movies/presentation/widgets/detail/`，不要因为它是图片就移动到 base。

## 图片操作

- `AppImageActionTrigger`：图片右键/长按操作入口。
- `showAppImageActionMenu`：统一显示图片操作菜单。
- `resolveThumbnailGridColumns`：根据可用宽度解析缩略图列数。

实现图片保存、复制、外部打开等动作时，使用 core 的平台能力和现有 action menu，不在页面直接拼 URL 或写平台分支。

## 媒体预览

- `MediaPreviewDialog` / `showMediaPreviewOverlay`：`lib/widgets/domain/media/preview/media_preview_dialog.dart`，桌面 dialog 和移动 overlay 的统一入口。
- `PreviewImageStage`：预览主图区域。
- `MediaPreviewActionGrid` / `MediaPreviewActionTile`：预览动作区。
- `MomentPreviewDialog`：时刻语义的预览入口。

预览关闭后再执行导航或打开下一级弹层，避免旧弹层的 pop 影响新路由。具体动作由调用页面决定。
