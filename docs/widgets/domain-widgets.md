# domain-widgets —— 业务展示件

按业务域组织的"跨 feature 复用"展示件——卡片、网格、筛选栏、预览弹窗、专用交互。**判定标准**:被 ≥ 2 个 feature 借用才在这里;单域用留在 `lib/features/<域>/presentation/widgets/`。

各域下的**筛选栏**(`*_filter_toolbar.dart`)+ **筛选 sections**(`*_filter_sections.dart`)是**姊妹关系**:toolbar 是桌面横排入口,sections 是移动 drawer 内的通用 section 组件,两端复用同一份 filter state。

---

## actors —— 女优

### ActorAvatar
- **路径**: `lib/widgets/actors/actor_avatar.dart`
- **用途**: 女优圆头像(内部包 `MaskedImage`)。
- **required**: `imageUrl` · `size` · `placeholderKey`(可选)
- **何时用**: 一切女优头像展示——列表、详情、搜索建议、时刻卡。

### ActorSummaryCard
- **路径**: `lib/widgets/actors/actor_summary_card.dart`
- **用途**: 女优摘要卡(海报 + 名字 + 订阅徽标)。
- **required**: `actor: ActorSummary`
- **可选**: `onTap` · `onSubscriptionTap` · `isSubscriptionUpdating`

### ActorSummaryGrid
- **路径**: `lib/widgets/actors/actor_summary_grid.dart`
- **用途**: 女优网格(四态容器 + 自适应列宽 + 占位骨架)。
- **required**: `items` · `isLoading`
- **可选**: `errorMessage` · `onActorTap` · `onActorSubscriptionTap` · `isActorSubscriptionUpdating` · `emptyMessage` · `placeholderCount`(默认 8)
- **何时用**: 所有女优网格页面(女优发现、时刻里的女优、搜索结果女优 tab)。
- **实现**: 内部走 `AppAdaptiveCardGrid<ActorListItemDto>`(fixedAspect)。改列宽 / 四态观感请去 [data-loading.md](./data-loading.md) 的 `AppAdaptiveCardGrid<T>`。

### ActorFilterToolbar / ActorFilterSectionGroup / ActorFilterChoiceSection&lt;T&gt; / ActorSortSection
- **路径**: `lib/widgets/actors/actor_filter_toolbar.dart` · `actor_filter_sections.dart`
- **用途**: 女优筛选。桌面用 toolbar(横排 popover),移动把 sections 放进 `AppMobileFilterDrawerScaffold`。
- **ActorFilterToolbar required**: `filterState` · `onChanged` · `onReset`

---

## movies —— 影片

### MovieSummaryCard
- **路径**: `lib/widgets/movies/movie_summary_card.dart`
- **用途**: 影片摘要卡(封面 + 番号 + 标题 + 状态 / 订阅徽标 + rank 徽标)。
- **required**: `movie: MovieSummary`
- **可选**: `showStatusBadges` · `rank`(排行榜数字徽标) · `onTap` · `onRequestMenu` · `onSubscriptionTap` · `isSubscriptionUpdating`
- **何时用**: 所有影片网格 item——发现、搜索、女优详情、时刻库、订阅。

### MovieSummaryGrid
- **路径**: `lib/widgets/movies/movie_summary_grid.dart`
- **用途**: 影片网格(四态 + 自适应列宽,列宽用 `movieCardTargetWidth` token)。
- **required**: `items` · `isLoading`
- **可选**: `errorMessage` · `onMovieTap` · `onMovieMenuRequest` · `onMovieSubscriptionTap` · `isMovieSubscriptionUpdating` · `emptyMessage` · `placeholderCount`(默认 8)
- **实现**: 内部走 `AppAdaptiveCardGrid<MovieListItemDto>`(fixedAspect)。改列宽 / 四态观感请去 [data-loading.md](./data-loading.md) 的 `AppAdaptiveCardGrid<T>`。

### MovieFilterToolbar / MovieFilterSectionGroup / MovieFilterChoiceSection&lt;T&gt; / MovieYearFilterSection / MovieSortSection
- **路径**: `lib/widgets/movies/movie_filter_toolbar.dart` · `movie_filter_sections.dart`
- **用途**: 影片筛选。年份 section 独立(有年份选项 loading / error / retry 三态)。
- **MovieFilterToolbar required**: `filterState` · `onChanged` · `onReset`;可选 `yearOptions` · `isYearOptionsLoading` · `yearOptionsErrorMessage` · `onYearOptionsRetry` · `onOpened`

### MobileFollowMovieCard
- **路径**: `lib/widgets/movies/mobile_follow_movie_card.dart`
- **用途**: 移动"我的订阅"专用大卡(细封面 + 详情图 strip + 简介)。有延迟加载详情。
- **required**: `movie` · `onTap` · `onSubscriptionTap` · `isSubscriptionUpdating` · `isDetailLoading` · `detailStillImageUrls` · `detailSummary` · `detailThinCoverUrl` · `detailCoverUrl`
- **何时用**: 移动订阅页的"新映影片"这种详情 preview 卡。
- **何时不用**: 通用列表 → `MovieSummaryCard`。

---

## clips —— 切片

### ClipCard(list row 形态)
- **路径**: `lib/widgets/clips/clip_card.dart`
- **用途**: 切片**行 item**(横排:缩略图 + 元数据 + 菜单)。
- **required**: `clip` · `onPlay` · `onRename` · `onDelete`

### ClipGridCard(网格 tile,推荐主用)
- **路径**: `lib/widgets/clips/clip_grid_card.dart`
- **用途**: 切片**网格 tile**——支持多选、右键 / 长按上下文菜单、跳转原影片。
- **required**: `clip` · `onPlay` · `onRename` · `onDelete` · `onAddToCollection`
- **可选**: `onOpenMovie` · `selectionMode` · `isSelected` · `onSelectedChanged`
- **何时用**: 所有切片网格(切片总览、合集成员、时刻库切片)。

### ClipCoverCard
- **路径**: `lib/widgets/clips/clip_cover_card.dart`
- **用途**: 切片"纯封面 tile"(**无标题 / 菜单**),供合集封面 grid 拼图用。
- **required**: `clip` · `onTap`
- **可选**: `selectionMode` · `isSelected` · `onSelectedChanged`

### ClipPlayOverlay / ClipDurationBadge
- **路径**: `lib/widgets/clips/clip_cover_overlays.dart`
- **用途**: 切片封面上的两个覆盖层——中间"播放三角"和右下"时长徽标"。
- **ClipDurationBadge required**: `seconds`
- **何时用**: 自建切片封面时叠加。已经在 `ClipGridCard` / `ClipCoverCard` 里用过。

### ClipSelectionStatusBar
- **路径**: `lib/widgets/clips/clip_selection_status_bar.dart`
- **用途**: 影片播放页缩略图圈选后底部的"起止 / 时长 / 生成 / 清除"状态条。
- **required**: `keyPrefix` · `startSeconds` · `endSeconds` · `durationSeconds` · `canCreate` · `onCreate` · `onClear`
- **何时用**: 影片播放页缩略图圈选场景。

### ClipPlayerDialog + showClipPlayerDialog
- **路径**: `lib/widgets/clips/clip_player_dialog.dart`
- **签名**: `Future<void> showClipPlayerDialog(BuildContext context, { required String streamUrl, required String title })`
- **用途**: 切片快播弹窗(`AppDesktopDialog` 包壳 + `ThemedVideoPlayer` 播放器)。
- **何时用**: 任何"点小切片弹出播放"入口。**别自己 wrap `showDialog + Video`**。

---

## collections —— 合集

### CollectionCard / CollectionCoverCard
- **路径**: `lib/widgets/collections/collection_card.dart` · `collection_cover_card.dart`
- **用途**: 合集封面卡——`CollectionCard` 是内部私有 `._` 构造(不直接 new),`CollectionCoverCard` 是**对外的合集封面卡**(标题 + 计数 + 封面 + 编辑 / 删除菜单)。
- **CollectionCoverCard required**: `title` · `count` · `coverUrl` · `onTap`;可选 `tapKey` / `menuKey` · `coverFit`(默认 cover) · `placeholderIcon`(默认 `video_library_outlined`) · `onEdit` / `onDelete`
- **何时用**: 切片合集 / 视频合集的网格。

### CollectionMemberRow / CollectionMemberCard
- **路径**: `lib/widgets/collections/collection_member_views.dart`
- **用途**: 合集**成员**两种形态——`CollectionMemberRow` 是横排行(拖拽排序),`CollectionMemberCard` 是网格 tile。
- **CollectionMemberRow required**: `index` · `coverUrl` · `coverWidth` · `coverAspectRatio` · `title` · `isHovered` · `onTap` · `menuKey` · `dragHandleKey`
- **CollectionMemberCard**: 参见文件内 constructor,类似 grid tile 形态。
- **何时用**: 合集详情页里的成员列表 / 网格。

---

## moments —— 时刻

### MomentCard
- **路径**: `lib/widgets/moments/moment_card.dart`
- **required**: `item: MomentItem`
- **可选**: `onTap`

### MomentGrid
- **路径**: `lib/widgets/moments/moment_grid.dart`
- **required**: `items` · `onItemTap`
- **何时用**: 时刻库网格(列宽用**裸值** 220/280/300,是本项目里几个"网格四态容器"例外之一)。

### MomentSortHeader
- **路径**: `lib/widgets/moments/moment_sort_header.dart`
- **用途**: 时刻页顶"总数 + 排序(最新/最早)+ 可选类型筛选(jav/video)"条。
- **required**: `total` · `sortOrder` · `onSortChanged`
- **可选**: `kindFilter` · `onKindChanged` · `variant: standard|mobileTagCompact` · Key 一组默认预置
- **何时用**: 时刻库入口页。

### MomentPreviewDialog
- 见 [media-images.md](./media-images.md) —— 与 `MediaPreviewDialog` 语义 alias。

---

## rankings —— 排行榜

### RankedMovieSummaryGrid
- **路径**: `lib/widgets/rankings/ranked_movie_summary_grid.dart`
- **用途**: 排行榜网格(与 `MovieSummaryGrid` 类似,但每张卡带 rank 徽标)。
- **required**: `items` · `isLoading`
- **可选**: `errorMessage` · `onMovieTap` · `onMovieMenuRequest` · `onMovieSubscriptionTap` · `isMovieSubscriptionUpdating` · `emptyMessage` · `placeholderCount`
- **实现**: 内部走 `AppAdaptiveCardGrid<RankedMovieListItemDto>`(fixedAspect)。改列宽 / 四态观感请去 [data-loading.md](./data-loading.md) 的 `AppAdaptiveCardGrid<T>`。

### RankingFilterToolbar / RankingFilterSectionGroup / RankingFilterChoiceSection&lt;T&gt; / RankingSortSection / RankingFilterSectionKeys / RankingFilterAnchor
- **路径**: `lib/widgets/rankings/ranking_filter_toolbar.dart` · `ranking_filter_sections.dart`
- **用途**: 排行榜专用筛选(**多了 source / board / period 三个维度**,比 movies 复杂)。
- **RankingFilterToolbar required**: `sources` · `selectedSource` · `boards` · `selectedBoard` · `selectedPeriod` · `onSourceChanged` · `onBoardChanged` · `onPeriodChanged` · `isLoading` · `selectedSortField` · `selectedSortDirection` · `onSortChanged`

---

## playlists —— 播放列表

### PlaylistBannerCard
- **路径**: `lib/widgets/playlists/playlist_banner_card.dart`
- **用途**: 播放列表 banner 大卡(标题 + 封面)。
- **required**: `title`;可选 `coverImageUrl` · `onTap`
- **何时用**: 播放列表页顶部"这里是 xxx 播放列表"横幅。

### PlaylistManagementCard
- **路径**: `lib/widgets/playlists/playlist_management_card.dart`
- **用途**: 播放列表管理卡(封面 + 标题 + 元数据 + 查看/编辑/删除三个按钮)。
- **required**: `playlist: Playlist` · `layout: PlaylistCardLayout.normal|dense`
- **可选**: `coverImageUrl` · `keyPrefix`(默认 `'playlist'`) · `onViewTap` · `onEditTap` · `onDeleteTap`
- **何时用**: 播放列表管理页(设置 / activity center 里的列表)。

---

## overview —— 概览

### OverviewStatsStrip(+ `OverviewStatItem`)
- **路径**: `lib/widgets/overview/overview_stats_strip.dart`
- **用途**: 主页 overview 顶部横排统计条(loading / error 兜底)。
- **required**: `items: List<OverviewStatItem>` · `isLoading`
- **可选**: `errorMessage`
- **何时用**: overview 桌面 / 移动主页顶部。

---

## search —— 目录搜索

### CatalogSearchField
- **路径**: `lib/widgets/search/catalog_search_field.dart`
- **用途**: 目录搜索输入框(带图搜按钮 + 在线搜索开关)。
- **required**: `controller` · `hintText`
- **可选**: `fieldKey` / `searchButtonKey` / `imageSearchButtonKey` / `onlineToggleKey` · `onSubmitted` · `onSearchTap` · `onImageSearchTap` · `showImageSearchButton` · `showOnlineToggle` · `isOnlineSearchEnabled` · `onOnlineSearchToggle` · `autofocus` · `compact`
- **何时用**: 目录 / sidebar 搜索、全局搜索。

### CatalogSearchContent
- **路径**: `lib/widgets/search/catalog_search_content.dart`
- **用途**: 完整搜索面板(输入 + tab + 影片/女优/时刻结果)。
- **required**: `controller` · `textController` · `tabController` · `useOnlineSearch` · `onOnlineSearchToggle` · `onSubmitSearch` · `onTabSelected` · `onMovieTap` · `onActorTap` · `onMovieSubscriptionTap` · `onActorSubscriptionTap`
- **可选**: `onMovieMenuRequest`

### CatalogSearchStreamStatusCard
- **路径**: `lib/widgets/search/catalog_search_stream_status_card.dart`
- **用途**: 搜索**流式**状态提示卡(SSE 拉搜索时"正在从 xxx 拉"这种)。
- **required**: `status`

---

## image_search —— 图搜

### ImageSearchFilterPanel
- **路径**: `lib/widgets/image_search/image_search_filter_panel.dart`
- **用途**: 图搜筛选面板(当前影片范围 / 模式 / 女优选择)。
- **required**: `filterState` · `summaryText` · `onCurrentMovieScopeChanged` · `onModeChanged` · `onSelectActors` · `onSearch`
- **可选**: `currentMovieNumber` · `isSearching`

### ImageSearchResultCard
- **路径**: `lib/widgets/image_search/image_search_result_card.dart`
- **required**: `item: ImageSearchResult`
- **可选**: `onTap` · `onRequestMenu`

### ImageSearchResultGrid
- **路径**: `lib/widgets/image_search/image_search_result_grid.dart`
- **required**: `items` · `onItemTap`
- **可选**: `onItemMenuRequested`

### ImageSearchResultPreviewDialog
- **路径**: `lib/widgets/image_search/image_search_result_preview_dialog.dart`
- **用途**: 图搜结果预览浮层(`MediaPreviewDialog` 家族的语义包装)。
- **required**: `item` · `onSearchSimilar` · `onPlay` · `onOpenMovieDetail`
- **可选**: `presentation: dialog|bottomDrawer`

### ImageSearchToolbarIconButton
- **路径**: `lib/widgets/image_search/image_search_toolbar_icon_button.dart`
- **用途**: 图搜工具栏专用图标按钮(`AppIconButton` 之上的一层业务外观)。
- **required**: `tooltip` · `icon`
- **可选**: `onPressed` · `isSelected`
- **何时用**: 只有图搜工具栏内用;别处用 `AppIconButton`。

---

## batch —— 批量任务

### runBatchOperation&lt;T&gt;
- **路径**: `lib/widgets/base/operations/batch/batch_progress_dialog.dart`
- **签名**: `Future<BatchRunResult<T>> runBatchOperation<T>(...)`(具体参数见源码)
- **用途**: 批量操作进度弹窗——内部起 `_BatchProgressDialog`,追踪 N 个任务(排队 / 进行中 / 成功 / 失败),返回聚合结果 `BatchRunResult<T>`。
- **何时用**: 任何"批量删除 / 批量下载 / 批量补数据 / 批量刷新"操作,都走它,不要自己写 progress 弹窗。
- **注意**: 返回类型是 `BatchRunResult<T>`(带成功列表 / 失败列表 / 计数),caller 用它决定后续行为(比如"成功 3 个,失败 2 个,是否重试失败的?")。

---

## 相关约定

- **域内的展示件**(单域用)保留在 `lib/features/<域>/presentation/widgets/`,**不要**移到 `lib/widgets/<域>/`;真被两个 feature 借用了再上抬。
- **卡片上下文菜单**:clip / collection 封面 / collection 成员 / video 四处**仍是复制粘贴**——各自私有 enum + `_showContextMenu(...)`,改观感 / 行为要**逐处同步**(见 `lib/widgets/CLAUDE.md` "⚠️ 重复实现多" 段)。
- **多选勾选标记**统一走 `SelectionCheckBadge`(见 [data-loading.md](./data-loading.md)),别再自绘。
- **筛选状态**:filter state 是纯数据模型,变化后驱动 controller `reload()`(见各域的 `feature/CLAUDE.md`)。本目录只是**渲染 UI**,不管状态。
