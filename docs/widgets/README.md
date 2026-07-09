# 共享组件索引

> **这份索引写给自动化 agent(Claude/Codex/…)看。写代码前先扫这里,避免复制粘贴、避免同类件二次抽象、保证 UI/UX 一致。**

深度规则(边界、Key 约定、四态容器、播放器双层复用、图片三入口……)已经写在 [`lib/widgets/CLAUDE.md`](../../lib/widgets/CLAUDE.md);本文档只做**"有没有 / 该用哪个 / 在哪个文件"** 的目录级索引。

## 使用规范(动手前先读这三条)

1. **要新写一个组件前,先在这里 grep**——按用途关键词(按钮 / 空态 / 骨架 / 底抽屉 / 缩略图 / 分页加载条 …)搜本目录。**有则复用,别再造第二个**。
2. **要不要抽到 `lib/widgets/` ?**
   - 判定标准:**被 ≥ 2 个 feature 借用** → 归 `lib/widgets/<类别>/`;仅一个域用 → 留在 `lib/features/<域>/presentation/widgets/`。
   - 抽出后**同步更新本索引对应分册**(以及必要时更新 `lib/widgets/CLAUDE.md`)。
3. **命名铁则**:抽到 `lib/widgets/` 的原子件一律 **`App` 前缀**(如 `AppButton`/`AppTextField`/`AppEmptyState`)。业务展示件(卡片、筛选栏、预览弹窗)按业务域命名(如 `MovieSummaryCard`/`ClipGridCard`),**不加 `App` 前缀**。

## 三层物理结构(base / shell / domain)

`lib/widgets/` 按**职责**分三个顶级目录,依赖只能从 shell/domain 向 base 单向流动(深度细则见 [`lib/widgets/CLAUDE.md`](../../lib/widgets/CLAUDE.md)):

| 顶级目录 | 放什么 | 依赖规则 |
|---|---|---|
| **`base/`** | 纯 UI/通用交互原子:`actions` `forms` `feedback` `navigation` `typography` `interaction/selection` `layout/{cards,grids,scrolling}` `overlays` `operations/batch` `media/images` | **禁** import `features/`、`routes/`;只可依赖 Flutter/theme/core |
| **`shell/`** | 应用壳层:`desktop`(AppDesktopShell/AppSidebar/AppTopBar) `mobile`(AppMobileShell/…) `window`(拖拽区) | 允许依赖 `app/`、`routes/`、feature presentation;不承载具体业务流程 |
| **`domain/`** | 跨 ≥2 feature 复用的业务展示件(actors/clips/collections/movies/…) | 可用该域 DTO/筛选/回调;尽量不直接发请求(`MediaPreviewDialog` 是已知例外) |

> ⏳ **迁移进行中**:base/ 与 shell/ 已落位;各业务目录(actors/clips/collections/media_player…)仍在 `lib/widgets/` 根,将在后续 step 迁入 `domain/`。**只被单个 feature 用的组件回迁 `features/<域>/presentation/widgets/`**,不留共享层。本索引各分册链接与内部路径正随迁移分步更新。

## 分册导航

| 分册 | 覆盖组件 | 什么时候来这里翻 |
|---|---|---|
| **[actions.md](./actions.md)** | `AppButton` / `AppTextButton` / `AppIconButton` / `AppInlineActionButton` | 要放一个"按钮" |
| **[forms.md](./forms.md)** | `AppTextField` / `AppPasswordField` / `AppSelectField<T>` / `AppInfoPill` | 要收集用户输入 / 显示只读字段 |
| **[feedback.md](./feedback.md)** | `AppEmptyState` / `AppSectionError` / `AppSectionSkeleton` / `AppMobileSectionError` / `AppSkeletonBlock` / `AppMobileSkeletonCard` / `AppMobileSkeletonList` / `showAppConfirmDialog` | 要展示"空 / 错 / 加载中"三态,或要弹确认框 |
| **[sheets-dialogs.md](./sheets-dialogs.md)** | `AppDesktopDialog` / `showAppBottomDrawer` / `AppBottomDrawerSurface` / `AppBottomFormSheet` / `AppMobileConfirmActions` | 要弹一个对话框 / 底部抽屉 / 底部表单 |
| **[layout-shell.md](./layout-shell.md)** | `AppDesktopShell` / `AppMobileShell` / `AppMobileSubpageShell` / `AppSidebar`(+`AppSidebarItem`/`AppSidebarGroup`) / `AppTopBar` / `AppPageFrame` / `AppContentCard` / `AppSettingsGroup`(+`AppSettingCell`/`AppSettingIconBox`/`AppSettingCellChevron`) / `AppSettingsRail` / `AppNoticeCard`(+`AppNoticeStat`) / `AppStatTile` / `AppInfoBlock` / `AppBadge` / `AppWindowDragArea` | 要搭新页 / 加卡片容器 / 建设置项 / 顶部说明卡 |
| **[navigation.md](./navigation.md)** | `AppTabBar` / `AppMobileTabHeader`(+`AppMobileTabChip`) / `AppMobileFilterDrawerScaffold` | 要横向切分内容(Tab)或做移动端筛选抽屉 |
| **[data-loading.md](./data-loading.md)** | `AppPullToRefresh` / `AppAdaptiveRefreshScrollView` / `AppPagedLoadMoreFooter` / `AppFilterTotalHeader` / `AppText` / `AppAdaptiveCardGrid<T>` / `MultiSelectStateMixin` / `SelectionCheckBadge` / `StaggeredLayout*` | 要接列表下拉刷新 / 分页脚 / 总数条 / **卡片自适应网格** / 多选状态 / 交错布局 / 文字统一样式 |
| **[media-images.md](./media-images.md)** | `MaskedImage` / `AppImageFullscreenHost`(+`AppPinchToFullscreenImage`) / `MediaPreviewDialog` / `showMediaPreviewOverlay` / `PreviewImageStage` / `MediaPreviewActionGrid`(+`MediaPreviewActionTile`) / `AppImageActionTrigger` / `showAppImageActionMenu` / `resolveThumbnailGridColumns` | 要展示远端图 / 要建媒体预览浮层 / 要给图片挂右键长按菜单 |
| **[media-player.md](./media-player.md)** | `ThemedVideoPlayer` / `MoviePlayerSurface` / `MoviePlayerSurfaceController` / `MovieMediaThumbnailGrid` / `MoviePlayerThumbnailPanel` / `CollectionPlaySplitLayout` / `CollectionPlaybackPageMixin` / `CollectionFilmstripController` / `EpisodeSelectorOverlay` / `MergedPositionIndicator` / `MoviePlayerBackOverlay`(+一族按钮) / `MoviePlayerSpeedButton` / `MoviePlayerSubtitleButton` / `showCollectionPlaybackModePicker` | 要接视频播放(任何入口) |
| **[domain-widgets.md](./domain-widgets.md)** | actors / movies / clips / collections / moments / rankings / playlists / overview / search / image_search / batch 共 30+ 个业务展示件 | 要做"影片卡 / 女优卡 / 切片卡 / 合集封面 / 时刻卡 / 排行榜网格 / 播放列表卡 / 图搜结果 / 批量任务进度…" |

## Agent 检索 tips

- **想不到组件叫什么?** 打开对应分册,顶部有"覆盖组件"列表,按用途分组。
- **发现文档没提到但代码里有?** 说明**索引没跟上**——补进对应分册,并同步 `lib/widgets/CLAUDE.md` 的相关段落。
- **组件长得很像但功能微妙不同?** 分册里对易混淆件都写了"何时用它 / 何时不用",不要拍脑袋合并。典型对子:
  - `MaskedImage` vs `MoviePlotThumbnail` vs `AppImageFullscreen`(图片三入口)——见 [media-images.md](./media-images.md)
  - `AppSectionError`(桌面) vs `AppMobileSectionError`(移动)——见 [feedback.md](./feedback.md)
  - `AppStatTile` vs `AppInfoBlock`(数字强调 vs 标签强调)——见 [layout-shell.md](./layout-shell.md)
  - `ThemedVideoPlayer`(轻)vs `MoviePlayerSurface`(重)——见 [media-player.md](./media-player.md)
  - `EpisodeSelectorOverlay`(选集浮层) vs `buildMoviePlayerInfoSideDrawerOverlay`(视频信息抽屉)——见 [media-player.md](./media-player.md)
- **只要样式 / 布局 token(圆角、间距、颜色、字号)**:那属于 `lib/theme/`,不在本索引;取值走 `context.appXxx` + `resolveAppTextStyle` / `AppText`。

## 维护约定

- 抽出 / 挪动 / 删除 `lib/widgets/` 下的组件时,**必须**同步本目录对应分册。
- 分册内保持"一件一小节 + 一句话用途 + required 参数 + 何时用不用",别塞完整签名——完整签名去读源码。
- 分册长度阈值:单个 md > 500 行就该考虑再拆(如果 domain-widgets 未来膨胀,按业务域拆成 `domain-movies.md` / `domain-clips.md` 等)。
