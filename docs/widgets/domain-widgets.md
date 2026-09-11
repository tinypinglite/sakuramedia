# domain-widgets —— 业务展示件

业务展示件可以依赖所属 DTO、筛选值或回调，但不应把某个页面的导航流程和完整数据请求隐藏在卡片里。单 feature 专用组件留在 feature 内。

## actors

路径：`lib/widgets/domain/actors/`

包含 `ActorAvatar`、`ActorSummaryCard` 和 `ActorFilterSections`。女优数据和筛选状态由 actors feature 提供。

## movies

路径：`lib/widgets/domain/movies/`

包含 `MovieSummaryCard`、`MovieSummaryGrid`、`MovieFilterSections`、`MovieBatchSelection`、`SubscriptionHeartBadge` 和 `MovieMagnetSearchContent` / `showMovieMagnetSearchDialog`。后两者复用影片磁力搜索的候选资源、下载器选择与提交交互；状态由 movies feature 的 Provider 提供。影片详情内部组件仍位于 `features/movies/presentation/widgets/detail/`。

批量取消订阅遇到已有媒体时，未处理清单提供“删除媒体并强制取消订阅”入口。确认后先读取媒体总数，再按顺序删除；弹窗进度条显示已删除数量和当前影片，全部删除后显示批量取消订阅阶段。删除失败会停止。反馈返回最终合并结果，多选状态仅保留未处理番号。

## clips

路径：`lib/widgets/domain/clips/`

包含 `ClipGridCard`、`ClipCoverCard`、`ClipCoverOverlays`、`ClipSelectionStatusBar` 和 `ClipPlayerDialog`。切片创建、删除和重命名动作由 clips feature 负责。

## collections

路径：`lib/widgets/domain/collections/`

包含 `CollectionCard`、`CollectionCoverCard`、`CollectionMemberViews` 以及 `playback/` 下的合集连播组件。影片合集、视频合集和切片合集的数据适配由各自 feature 完成。

## media and preview

路径：`lib/widgets/domain/media/`

包含媒体时长徽标、快速播放、媒体缩略图网格、播放器缩略图面板和预览组件。图片预览的统一入口见 [media-images.md](media-images.md)。 播放组件直接使用后端提供的播放地址，播放失败时不再改写 `delivery` 并自动重开。

## moments

路径：`lib/widgets/domain/moments/`

包含 `MomentCard`、`MomentGrid`、`MomentImage` 和时刻预览适配器
`moment_preview_launcher.dart`（内部复用 `MediaPreviewDialog`）。时刻筛选和数据加载由
moments feature 负责。

## playlists and search

- `lib/widgets/domain/playlists/`：`PlaylistBannerCard`、`PlaylistManagementCard`。
- `lib/widgets/domain/search/`：`CatalogSearchField`、`CatalogSearchContent`、`CatalogSearchStreamStatusCard`。`CatalogSearchContent` 固定搜索框和影片/女优页签，流式进度卡与结果一起滚动。

## media import and batch

- `lib/widgets/domain/media_import/`：`MediaImportSourcePicker` 和 `MediaLibrarySelectorField` 由桌面、移动端的 JAV / 视频导入表单共用。移动端路径与目录选择按钮分行显示，文件行支持触摸和长名称；浏览、分页、重试与选择回调保持一致。
- `lib/widgets/base/operations/batch/`：`BatchProgressDialog` 等通用批量任务反馈，不绑定单一业务域。

新增业务展示件时先确认复用范围，再决定放在这里还是 feature 私有目录；文档只同步当前实际文件和公共使用边界。

下载任务删除确认复用 `lib/widgets/domain/downloads/download_task_delete_dialog.dart`，支持展示一个或多个任务，每次独立选择是否同时删除下载器中的文件。 批量入口通过 `showProgress` 复用 `runBatchOperation` 展示处理进度和成功、失败数量。
