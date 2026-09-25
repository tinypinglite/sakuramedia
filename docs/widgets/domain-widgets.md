# domain-widgets —— 业务展示件

业务展示件可以依赖所属 DTO、筛选值或回调，但不应把某个页面的导航流程和完整数据请求隐藏在卡片里。单 feature 专用组件留在 feature 内。

## actors

路径：`lib/widgets/domain/actors/`

包含 `ActorAvatar`、`ActorSummaryCard` 和 `ActorFilterSections`。女优数据和筛选状态由 actors feature 提供。

## movies

路径：`lib/widgets/domain/movies/`

包含 `MovieSummaryCard`、`MovieSummaryGrid`、`MovieFilterSections`、`MovieBatchSelection`、`SubscriptionHeartBadge` 和 `MovieMagnetSearchContent` / `showMovieMagnetSearchDialog`。后两者复用影片磁力搜索的候选资源、下载器选择与提交交互；状态由 movies feature 的 Provider 提供。影片详情内部组件仍位于 `features/movies/presentation/widgets/detail/`。

`SubscriptionHeartBadge` 点击时经 `core/platform/haptic_feedback.dart` 播放一次选择触感（iOS / Android），桌面端无副作用。

`MovieSummaryCard` 的底部信息层收起时不铺底色（番号直接压在封面上）；指针悬停时以 180ms ease-out 渐显压暗层，标题/时长/日期与整行动作按钮（播放 / 订阅 / 标记合集-单体 / 屏蔽影片，按回调与订阅状态显隐）上滑淡入，动作行放不下时自动折行；排名徽标与 ⓘ 独立成行、贴面板右下角。系统开启「减弱动态效果」时退化为瞬时切换。右端的 ⓘ 打开详情检查器（评论 / 磁力 / 缩略图；桌面弹对话框、移动弹底部抽屉），点击后先取一次影片详情以带出默认媒体；右键与长按仍打开影片操作菜单（原「更多」按钮已移除）。

`MovieSummaryCard` 在左上可播放图标后显示有效媒体的最高分辨率角标：宽度 ≥7680 为 8K，3840 ≤宽度 <7680 为 4K 档；低于 4K、缺失或无效媒体不显示。选择模式及隐藏状态角标时一并隐藏。清晰度角标使用与热度一致的半透明灰色底并局部模糊，文字固定白色，圆角、边框粗细与颜色复用热度标签；一行空间不足时热度标签换到下一行左侧，按实际文字宽度判断以避免遮挡。

批量取消订阅遇到已有媒体时，未处理清单提供“删除媒体并强制取消订阅”入口。确认后先读取媒体总数，再按顺序删除；弹窗进度条显示已删除数量和当前影片，全部删除后显示批量取消订阅阶段。删除失败会停止。反馈返回最终合并结果，多选状态仅保留未处理番号。

## clips

路径：`lib/widgets/domain/clips/`

包含 `ClipGridCard`、`ClipCoverCard`、`ClipCoverOverlays`、`ClipSelectionStatusBar` 和 `ClipActionsPanel`。`ClipGridCard` / `ClipCoverCard` 整卡即封面、收起态不铺文字；桌面悬停时底部渐显单行「标题 + 番号 · 时长 · 大小」与下方整行动作按钮（播放 / 影片 / 加入合集 / 重命名 / 删除，按回调显隐），移动端信息走点击后的 `ClipActionsPanel`。`ClipActionsPanel` 提供切片操作面板（封面 + 标题 + 横向操作格），移动端走底部抽屉、桌面端走居中弹窗；切片创建、删除和重命名动作由 clips feature 负责，切片播放统一走 clips feature 的 `launchClipPlayback`（桌面轻量弹窗 / 移动全屏页）。

## collections

路径：`lib/widgets/domain/collections/`

包含 `CollectionCard`（`.clip` / `.video` / `.moment` 命名构造）、`CollectionCoverCard`、`CollectionHintBox`、`CollectionMemberViews` 以及 `playback/` 下的合集连播组件。影片合集、视频合集和切片合集的数据适配由各自 feature 完成；`CollectionHintBox` 是合集横滑区空态/加载失败的共用提示条。`CollectionMemberCard` 的 `clipOverlay` 桌面悬停披露由三个合集详情的成员网格共用：收起态只留封面，悬停渐显标题/副信息与整行动作按钮（播放 / 影片 / 缩略图 / 加入合集 / 移出合集 / 删除，按回调显隐）；时刻来源媒体已删除时隐藏播放键。

## media and preview

路径：`lib/widgets/domain/media/`

包含媒体时长徽标、快速播放、媒体缩略图网格、播放器缩略图面板和预览组件。图片预览的统一入口见 [media-images.md](media-images.md)。 播放组件直接使用后端提供的播放地址，播放失败时不再改写 `delivery` 并自动重开。

## moments

路径：`lib/widgets/domain/moments/`

包含 `MomentCard`、`MomentGrid`、`MomentImage` 和时刻预览适配器
`moment_preview_launcher.dart`（内部复用 `MediaPreviewDialog`）。时刻筛选和数据加载由
moments feature 负责。`MomentCard` 整卡即封面、收起态不铺文字；桌面悬停时底部渐显
单行「番号/视频号 + `JAV · 位置`」与靠右的播放键（`MomentGrid` / `MomentSliver` 的
`onItemPlay` 提供），来源媒体删除时悬停面板补「来源已删除」。已有时刻通过 `pointId`
执行删除和合集操作；来源媒体删除后预览仍可查看图片，显示“来源已删除”并隐藏播放入口。

## playlists and search

- `lib/widgets/domain/playlists/`：`PlaylistBannerCard`。
- `lib/widgets/domain/search/`：`CatalogSearchField`、`CatalogSearchContent`、`CatalogSearchStreamStatusCard`。`CatalogSearchContent` 固定搜索框和影片/女优页签，流式进度卡与结果一起滚动。`CatalogSearchField` 的后缀搜索图标可用 `isSearching` 切到转圈并禁用点击、用 `searchButtonTooltip` 定制文案；需要「输入框 + 搜索」统一外观时用它，不要再另拼输入框和独立按钮。

## media import and batch

- `lib/widgets/domain/media_import/`：`MediaImportSourcePicker` 和 `MediaLibrarySelectorField` 由桌面、移动端的 JAV / 视频导入表单共用。移动端路径与目录选择按钮分行显示，文件行支持触摸和长名称；浏览、分页、重试与选择回调保持一致。
- `lib/widgets/base/operations/batch/`：`BatchProgressDialog` 等通用批量任务反馈，不绑定单一业务域。

新增业务展示件时先确认复用范围，再决定放在这里还是 feature 私有目录；文档只同步当前实际文件和公共使用边界。

下载任务删除确认复用 `lib/widgets/domain/downloads/download_task_delete_dialog.dart`，支持展示一个或多个任务，每次独立选择是否同时删除下载器中的文件。 批量入口通过 `showProgress` 复用 `runBatchOperation` 展示处理进度和成功、失败数量。

影片筛选面板的分辨率选项仅在“可播放”状态启用，切换到其他状态时清空；与其他条件组合并即时生效。

播放列表分辨率筛选复用 `MovieFilterChoiceSection`，固定展示全部、8K、4K、2K、1080P、720P、480P、360P，不显示数量；桌面浮层与移动抽屉均即时生效。
