# domain-widgets —— 业务展示件

业务展示件可以依赖所属 DTO、筛选值或回调，但不应把某个页面的导航流程和完整数据请求隐藏在卡片里。单 feature 专用组件留在 feature 内。

## 封面卡共用壳

路径：`lib/widgets/base/layout/cards/app_cover_card.dart`

「整卡即封面」的卡片（影片 / 女优 / 切片 / 时刻 / 视频 / 合集成员 / 合集封面 / 图搜）统一由 `AppCoverCard` 提供外观：`surfaceCard` 底、`lg` 圆角、常驻 1px 边框（选中换 2px）、圆角裁剪与 `AppSkeletonUnite` 同圆角合并骨块；封面区可按 `coverAspectRatio` 定比例或铺满父约束，`infoBuilder` 非空时组装 `AppCoverHoverInfo` 悬停披露层，`overlays` / `overlaysBuilder` 放常驻角标，`selectionMode` 时统一叠勾选徽标，`footer` 放封面下方常驻内容（合集标题）。外层手势（整卡点击、右键 / 长按菜单、订阅命中分流）由调用方在壳外组合；不要再手写这套装饰与裁剪。

## actors

路径：`lib/widgets/domain/actors/`

包含 `ActorAvatar`、`ActorSummaryCard` 和 `ActorFilterSections`。女优数据和筛选状态由 actors feature 提供。`ActorSummaryCard` 与影片卡同参数（`lg` 圆角、常驻 1px 边框）：收起态底部渐变上常显姓名（Tooltip 补全截断），桌面悬停渐显姓名、资料行（影片数 / 年龄 / 出生年月 / 身高 / 胸围 / 腰围 / 臀围 / 罩杯，字段随列表接口下发、缺项跳过）与订阅 / 取消订阅动作，收起态姓名层淡出；演员页没有多选 / 右键菜单业务，卡片不接入。

## taste

路径：`lib/widgets/domain/taste/`

口味画像的展示件：`TastePanel` 渐变外壳、`TasteActressCard` / `TasteActressRail` / `TasteActressSection` 横向女优卡与分组、`TasteSplitLayout` 的 640px 双栏 / 堆叠布局、`TasteSectionLabel` 与 `TasteEntrance`。女优页和发现页共用同一套；数据由 discovery 的 `tasteProfileProvider` 提供，订阅切换统一走 `toggleActorSubscriptionWithFeedback`。分组在拉取时冻结，订阅 / 取消只翻心形状态，卡片留在原组，下一次刷新再由服务端重新分组。`TasteTagPill` 只服务发现页，放在 `features/discovery/presentation/widgets/`。

## movies

路径：`lib/widgets/domain/movies/`

包含 `MovieSummaryCard`、`MovieSummarySliver`、`MovieFilterSections`、`MovieBatchSelection`、`SubscriptionHeartBadge` 和 `MovieMagnetSearchContent`。后者复用影片磁力搜索的候选资源、下载器选择与提交交互；状态由 movies feature 的 Provider 提供。磁力搜索的弹窗壳（含订阅列表入口 `showMovieMagnetSearchDialog`）在 `features/movies/presentation/widgets/detail/movie_detail_inspector_dialog.dart`，与详情页三个入口共用同一个单功能面板。影片详情内部组件仍位于 `features/movies/presentation/widgets/detail/`。

`SubscriptionHeartBadge` 点击时经 `core/platform/haptic_feedback.dart` 播放一次选择触感（iOS / Android），桌面端无副作用。

`MovieSummaryCard` 整卡即封面：收起态番号（+ 推荐理由）与排名徽标压在底部渐变上常显，触摸端停留在这层；指针悬停时与全站封面卡共用同一套底部披露层（180ms ease-out），标题/时长/日期与整行动作按钮（播放 / 订阅 / 标记合集-单体 / 屏蔽影片，按回调与订阅状态显隐，放不下时自动折行）淡入，收起态主键层淡出；排名徽标只在收起态显示。卡片参数与全站封面卡一致（`lg` 圆角、`surfaceCard` 底色、常驻 1px 边框）。系统开启「减弱动态效果」时退化为瞬时切换。右键与长按打开影片操作菜单（原「更多」按钮已移除）。`MovieSummarySliver` / `MovieSummaryRail` 共用 `MovieSummaryCardWiring` 装配卡片回调，改卡片交互只改这一处；女优详情 loading 骨架直接用 `AppAdaptiveCardGrid` + `MovieSummaryCard` 渲染占位卡。

`MovieSummaryCard` 左上角在订阅心后显示有效媒体的最高分辨率角标：宽度 ≥7680 为 8K，3840 ≤宽度 <7680 为 4K 档；低于 4K、缺失或无效媒体不显示。清晰度角标只在存在有效媒体时出现，而有效媒体即 `canPlay`，所以 4K/8K 卡上不再重复显示可播放标，可播放标只出现在低于 4K 的可播放卡上；两者都受选择模式控制。清晰度角标、热度和排名角标统一使用 `AppMediaBadge`（无描边烟熏渐变：深色底 + 白色文字，不做背景模糊），文字固定白色；一行空间不足时热度标签换到下一行左侧，按实际文字宽度判断以避免遮挡。

批量取消订阅遇到已有媒体时，未处理清单提供“删除媒体并强制取消订阅”入口。确认后先读取媒体总数，再按顺序删除；弹窗进度条显示已删除数量和当前影片，全部删除后显示批量取消订阅阶段。删除失败会停止。反馈返回最终合并结果，多选状态仅保留未处理番号。

## tags

路径：`lib/widgets/domain/tags/`

`MediaTagFilterSection` 是影片库与女优详情作品区共用的媒体文件标签筛选分节。组件直接接收调用方的 `MovieFilterState`，通过 `onChanged` 回写完整筛选状态，不维护选择副本；标签加载、失败重试和空态也由该分节统一呈现。

女优详情私有的 `ActorTagFilterPanel` 复用 `TagSelectorPanel`，仅关闭搜索框和「热门标签 / 搜索结果」分组；标签数据仍来自女优作品标签接口，选择与匹配模式由 actors 域 Provider 持有。

## clips

路径：`lib/widgets/domain/clips/`

包含 `ClipGridCard`、`ClipCoverCard`、`ClipCoverOverlays`、`ClipSelectionStatusBar` 和 `ClipActionsPanel`。`ClipGridCard` / `ClipCoverCard` 整卡即封面、收起态不铺文字；桌面悬停时底部渐显单行「标题 + 番号 · 时长 · 大小」与下方整行动作按钮（播放 / 影片 / 加入合集 / 重命名 / 删除，按回调显隐），移动端信息走点击后的 `ClipActionsPanel`。`ClipActionsPanel` 提供切片操作面板（封面 + 标题 + 横向操作格），移动端走底部抽屉、桌面端走居中弹窗；切片创建、删除和重命名动作由 clips feature 负责，切片播放统一走 clips feature 的 `launchClipPlayback`（桌面轻量弹窗 / 移动全屏页）。

## collections

路径：`lib/widgets/domain/collections/`

包含 `CollectionCard`（`.clip` / `.video` / `.moment` 命名构造）、`CollectionHintBox`、`CollectionMemberViews`、`CollectionTargetPicker` 以及 `playback/` 下的合集连播组件。影片合集、视频合集和切片合集的数据适配由各自 feature 完成；`CollectionHintBox` 是合集横滑区空态/加载失败的共用提示条。`showCollectionTargetPicker`（`collection_target_picker.dart`）是切片、时刻、视频三处「加入合集」选择器的共用实现：只负责选中一个目标合集并返回，成员写入由调用方批量执行；各域只提供数据源、行文案（`N 个切片/时刻/视频`）、行 Key 前缀和「新建合集并加入」入口，弹窗/抽屉形态与既有测试锚点由参数保持。选项行是单行卡片：浅灰底 + 细边框，名称过长单行省略，右侧依次是计数和加号；点击整行返回所选合集。`CollectionMemberCard` 由三个合集详情的成员网格共用：整卡即封面、收起态不铺文字，桌面悬停渐显标题/副信息与整行动作按钮（播放 / 影片 / 缩略图 / 加入合集 / 移出合集 / 删除，按回调显隐），移动端信息与动作走点击后的操作面板 / 预览层；时刻来源媒体已删除时隐藏播放键。`CollectionCard.video` 固定使用封面内玻璃信息条承载标题和计数，不再渲染封面下方实色标题栏，调用方不需要传玻璃开关；`.clip` / `.moment` 仍使用默认实色标题栏。视频合集卡传 `coverBackdrop: true` 时，`BoxFit.contain` 的竖图两侧铺同图暗底，移动 PornBox 横滑区和合集列表使用。

## media and preview

路径：`lib/widgets/domain/media/`

包含媒体时长徽标、快速播放、媒体缩略图网格、播放器缩略图面板和预览组件。图片预览的统一入口见 [media-images.md](media-images.md)。 播放组件直接使用后端提供的播放地址，播放失败时不再改写 `delivery` 并自动重开。

## moments

路径：`lib/widgets/domain/moments/`

包含 `MomentCard`、`MomentSliver`、`MomentRail`、`MomentImage` 和时刻预览适配器
`moment_preview_launcher.dart`（内部复用 `MediaPreviewDialog`）。时刻筛选和数据加载由
moments feature 负责。`MomentCard` 整卡即封面、收起态不铺文字；桌面悬停时底部渐显
单行「番号/视频号 + `JAV · 位置`」与整行动作按钮（播放 / 影片 / 加入合集 / 删除，按
网格 / rail 传入的回调显隐；来源媒体删除时补「来源已删除」并隐藏播放键）。
时刻列表、时刻合集详情与发现推荐时刻统一走 `showMomentPreviewFlow`
（`moment_preview_flow.dart`）：预览层内联导航（封面进来源影片详情、头像进女优详情、
图片点按全屏），关闭后统一分发图搜 / 加入合集 / 播放 / 影片详情 / 演员详情；
`addMomentItemToCollection` 是悬停动作行与预览回执共用的加入合集入口。发现推荐条目的
`pointId` 是推荐 ID，预览与加入合集都按 mediaId + thumbnailId 反查真实时刻（推荐条目
不提供删除）。

## playlists and search

- `lib/widgets/domain/playlists/`：`PlaylistBannerCard`。
- `lib/widgets/domain/search/`：`CatalogSearchField`、`CatalogSearchContent`、`CatalogSearchStreamStatusCard`。`CatalogSearchContent` 固定搜索框和影片/女优页签，流式进度卡与结果一起滚动。`CatalogSearchField` 的后缀搜索图标可用 `isSearching` 切到转圈并禁用点击、用 `searchButtonTooltip` 定制文案；需要「输入框 + 搜索」统一外观时用它，不要再另拼输入框和独立按钮。

## account

- `lib/widgets/domain/account/`：`ApiKeyGeneratePanel` 是桌面账号安全区与移动端账号安全页共用的 API 密钥生成流程（备注名 → 生成 → 一次性明文展示与复制）。`keyPrefix`（`configuration` / `mobile`）派生本流程的控件 Key，桌面套 `AppDesktopDialog`、移动端塞进底部抽屉；数据由 account feature 的 `apiKeysProvider` 提供。

## media import and batch

- `lib/widgets/domain/media_import/`：`MediaImportSourcePicker` 和 `MediaLibrarySelectorField` 由桌面、移动端的 JAV / 视频导入表单共用。媒体库列表读取共享的 `mediaLibrariesProvider`；移动端路径与目录选择按钮分行显示，文件行支持触摸和长名称；浏览、分页、重试与选择回调保持一致。视频导入弹窗因额外包含合集字段，可为目录浏览器单独传入较矮的 `browserHeight`。
- `lib/widgets/base/operations/batch/`：`BatchProgressDialog` 等通用批量任务反馈，不绑定单一业务域。

## 列表排序入口适配器

以下适配器只负责把各 feature 的筛选状态映射到共享 `AppSortMenuButton`，不重复实现浮层、抽屉或 chip 外观：

- `lib/widgets/domain/movies/movie_sort_menu_button.dart`：影片库、标签结果、女优详情作品共用；切字段时清空个人评分维度。
- `lib/widgets/domain/actors/actor_sort_menu_button.dart`：搜索态显示「相关度」并禁用入口。
- `lib/widgets/domain/playlists/playlist_sort_menu_button.dart`：`sortField == null` 显示「最近触达」。
- `lib/widgets/domain/videos/video_sort_menu_button.dart`、`video_collection_sort_menu_button.dart`：视频列表与合集成员；合集的手动顺序隐藏方向分节。
- `lib/widgets/domain/rankings/ranking_sort_menu_button.dart`：默认项「默认（名次）」。
- `lib/widgets/domain/media/media_sort_menu_button.dart`：`sortField == null` 显示「默认排序」。
- `lib/widgets/domain/subscriptions/movie_subscription_sort_menu_button.dart`：字段 + 方向映射回完整 `MovieSubscriptionSort`；「没找到次数」隐藏方向。
- `lib/widgets/domain/activity/activity_task_sort_menu_button.dart`：任务历史的字段 + 方向。

新增列表排序时优先复用这些适配器或按同一模式扩展，不要在页面里手写筛选面板排序分节。

新增业务展示件时先确认复用范围，再决定放在这里还是 feature 私有目录；文档只同步当前实际文件和公共使用边界。

下载任务删除确认复用 `lib/widgets/domain/downloads/download_task_delete_dialog.dart`，支持展示一个或多个任务，每次独立选择是否同时删除下载器中的文件。 批量入口通过 `showProgress` 复用 `runBatchOperation` 展示处理进度和成功、失败数量。

影片筛选面板的分辨率选项仅在“可播放”状态启用，切换到其他状态时清空；与其他条件组合并即时生效。

`AppFilterOptionSection` 的选项整组变化（如排行榜切来源后的榜单/周期）以同步高度过渡替换；`isLoading: true` 时选项区用 `AppSkeletonizer` 骨架显示占位 options 并屏蔽点击，由调用方保证占位文案不暴露真实数据。

播放列表分辨率筛选复用 `AppFilterOptionSection`，固定展示全部、8K、4K、2K、1080P、720P、480P、360P，不显示数量；桌面浮层与移动抽屉均即时生效。
