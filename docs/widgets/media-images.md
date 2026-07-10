# media & images —— 远端图、预览浮层、图片右键菜单

**图片有三个互不通用的入口——选错会丢比例或多开销。开工前先读本页第一节。**

## 一、图片三入口(⚠️ 互斥,别混用)

三个组件都自己读 `AppImageConfig.enableBlur/blurSigma` 包模糊、都自己拼 baseUrl,**改模糊逻辑要同时改三处**。

### MaskedImage
- **路径**: `lib/widgets/base/media/images/masked_image.dart`
- **用途**: **普通封面 / 缩略图**的**唯一标准入口**(自动 decode 提示 + 占位 / 错误图)。
- **required**: `url`
- **可选**: `fit`(默认 `BoxFit.cover`) · `alignment`(默认居中，控制 `cover` 裁切焦点) · `visibleWidthFactor`(0<x<=1,只显左侧一段) · `visibleAlignment` · `memCacheWidth` / `memCacheHeight`
- **何时用**: 影片封面、女优头像(内层)、切片封面、合集封面、播放列表 banner、任意"网格里那张图"。
- **何时不用**: 剧情图(要真实比例) → `MoviePlotThumbnail`;全屏 / 画廊 → `AppImageFullscreenHost` + `AppPinchToFullscreenImage`。

### MoviePlotThumbnail(**不在 lib/widgets/**,提示引用)
- **路径**: `lib/features/movies/presentation/widgets/detail/movie_plot_thumbnail.dart`
- **用途**: **剧情图专用**——`ResizeImage` 按高解码 + 监听真实宽高比。
- **何时用**: 详情页剧情帧 / plot gallery。
- **和 `MaskedImage` 的差异**: 列表封面用它会多开销;剧情图用 `MaskedImage` 会丢比例(cover 裁掉)。**不可互换**。

### AppImageFullscreenHost(+ `AppPinchToFullscreenImage`)
- **路径**: `lib/widgets/base/media/images/app_image_fullscreen.dart`
- **用途**: 全屏 / 画廊(基于 `photo_view`),支持双指捏合放大 → 拉起全屏。
- **AppImageFullscreenHost required**: `child`(**必须包在路由树高处**——触发器靠 `findAncestorStateOfType` 找它,找不到则全屏 / 抽屉**静默失败**)。
- **AppPinchToFullscreenImage required**: `child` · 二选一 `url` / `imageProvider`
- **AppPinchToFullscreenImage 可选**: `imageAspectRatio` · `fallbackAspectRatio`(默认 1) · `fit`(默认 contain) · `enabled` · `fullscreenGalleryItems` / `fullscreenGalleryIndex` · `onFullscreenImageIndexChanged` · `onFullscreenImageMenuRequested` · `onFullscreenChanged` · `fullscreenImageKey`
- **何时用**: 剧情图 gallery、moment 预览、图搜结果的"点大图"入口。
- **注意**: Host 已经在顶层 shell 里挂过一次,业务代码通常直接用 `AppPinchToFullscreenImage`。

> 加新图片组件记得同样接 blur,否则模糊设置对它无效。

## 二、图片右键 / 长按菜单

### AppImageActionTrigger
- **路径**: `lib/widgets/base/media/images/app_image_action_trigger.dart`
- **用途**: 给图片包裹一层手势(右键 + 长按)→ 通过 `onRequestMenu(Offset globalPosition)` 回调让调用方唤菜单。
- **required**: `child`
- **可选**: `onRequestMenu`(为 `null` 时不接长按/右键手势,只保留 `onTap`)· `onTap` · `mouseCursor`
- **何时用**: 任何"图片支持复制链接 / 保存 / 搜索相似"的场景——影片封面卡、剧情图、moment、图搜结果;也可只传 `onTap` 当作统一手势入口用(菜单回调按需可空)。

### showAppImageActionMenu
- **路径**: `lib/widgets/base/media/images/app_image_action_menu.dart`
- **签名**: `Future<AppImageActionType?> showAppImageActionMenu({ required BuildContext context, required List<AppImageActionDescriptor> actions, required Offset? globalPosition, AppImageActionMenuPresentation presentation = popup })`
- **用途**: 图片操作菜单(复制链接 / 保存到相册 / 用它搜相似 …),自适应 popup(桌面弹右键菜单) vs bottomDrawer(移动底抽屉)。
- **何时用**: 配合 `AppImageActionTrigger` 的 `onRequestMenu` 回调唤起。
- **别自己写**: `showMenu` + 菜单项集合——统一走它。

## 三、媒体预览浮层(点小图 → 弹大浮层看细节)

### MediaPreviewDialog
- **路径**: `lib/widgets/domain/media/preview/media_preview_dialog.dart`
- **用途**: 通用**媒体项预览浮层**(自适应桌面 dialog / 移动底抽屉)——顶部主图 stage + 下方"操作"(搜相似 / 播放 / 打开影片详情 / 删除时刻)+ 影片信息 + 女优条。
- **required**: `item: MediaPreviewItem`
- **可选**: `availableActions: Set<MediaPreviewAction>` · `onPointRemoved` · `closeOnPointRemoved` · `presentation: dialog|bottomDrawer`
- **何时用**: 点媒体缩略图 / 点剧情帧 / 点 moment 时打开的"详情浮层"。**别自己组合 `AppDesktopDialog + Image + Buttons`**。
- **别名 caller**: `MomentPreviewDialog` 和 `ImageSearchResultPreviewDialog` 是它的语义化包装。
- **动作时序**: 外部跳转统一由 `showMediaPreviewOverlay` 返回 `MediaPreviewAction` 后执行；预览先关闭，页面再处理相似图片、播放或影片详情，避免旧弹层的 `pop` 影响新路由或桌面 Quick Play 弹窗。

### MomentPreviewDialog(相当于 MediaPreviewDialog 的语义 alias)
- **路径**: `lib/widgets/domain/moments/moment_preview_dialog.dart`
- 参数为 `item`、`onPointRemoved`、`closeOnPointRemoved`、`presentation`；可用动作由时刻数据自动推导，语义清楚"这是时刻"。
- **何时用**: 时刻列表 / 时刻库点击。

### ImageSearchResultPreviewDialog(见 [domain-widgets.md](./domain-widgets.md))
- 图搜结果的预览浮层,内部也是 `MediaPreviewDialog` 家族。

## 四、预览浮层的**积木**(自建预览时用)

### PreviewImageStage
- **路径**: `lib/widgets/domain/media/preview/preview_image_stage.dart`
- **用途**: 预览浮层顶部那块"图 + 关闭按钮 + 可选 overlay"stage。
- **required**: `imageUrl` · `height` · `onClose`
- **可选**: `stageKey` / `imageKey` / `closeButtonKey` · `backgroundColor` · `fit` · `showCloseButton` · `overlayChild` · `enablePinchToFullscreen` · `fullscreenImageKey`
- **何时用**: 自建预览浮层的图区域(与 `AppDesktopDialog` 搭配用)。

### MediaPreviewActionGrid(+ `MediaPreviewActionTile`)
- **路径**: `lib/widgets/domain/media/preview/media_preview_action_grid.dart`
- **用途**: 预览浮层下方"操作按钮网格",支持 wrap / fixedColumns / horizontalScroll 三种布局。
- **required**: `actions: List<MediaPreviewActionItem>`
- **可选**: `layout`(默认 wrap) · `columns`(默认 3) · `spacing` · `tileWidth`(默认 92) · `gridKey`
- **何时用**: 自建预览浮层的操作区。

## 五、封面遮罩

### AppCoverBottomShade
- **路径**: `lib/widgets/base/media/images/app_cover_bottom_shade.dart`
- **用途**: 封面底部"从中间往下加深"的渐变遮罩(`mediaOverlaySoft` → `mediaOverlayStrong`),保证浮层白字与图标可读。始终包 `IgnorePointer`,不吃点击。
- **可选**: `stops`(默认 `[0.45, 0.72, 1]`; actor 卡传 `[0.42, 0.7, 1]` 稍强)
- **何时用**: 卡片封面上叠"白色标题 / 图标"时。movie / actor / rankedMovie / video / collection member 都走它。
- **别自己写**: `DecoratedBox + LinearGradient` 那套 gradient——别再复制粘贴。

## 六、缩略图列数解析

### resolveThumbnailGridColumns(工具函数,非 widget)
- **路径**: `lib/widgets/base/media/images/thumbnail_grid_column_resolver.dart`
- **用途**: 按容器宽 / 目标 tile 宽解析出列数(与 media_player 的 `MovieMediaThumbnailGrid` 共用规则)。
- **何时用**: 需要"跟播放器缩略图面板同规则"计算列数的地方。

---

## 相关约定

- **图片三入口** 是**互斥且规则明确**的,别在业务侧自建"新图片组件"——先看能不能扩这三个。
- 图片右键 / 长按菜单**统一**走 `AppImageActionTrigger` + `showAppImageActionMenu`,别自己 `showMenu`。
- 预览浮层**首选** `MediaPreviewDialog`;真要自建也用它内部的两个积木(`PreviewImageStage` / `MediaPreviewActionGrid`)+ `AppDesktopDialog` 外壳,别自己拼壳。
- 深入规则见 `lib/widgets/CLAUDE.md` "图片组件——三选一,各读一次 blur" 段。
