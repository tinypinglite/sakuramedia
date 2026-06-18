# lib/features/ — 业务域通用范式

每个 feature 统一 `data/`(`*_api.dart` + `*_dto.dart`) + `presentation/`(页面 + 控制器 + 状态)。本文件是**所有 feature 共享的范式**;重型域另有自己的 CLAUDE.md(`movies/`、`configuration/`、`activity/`)。

## data 层范式

- **`XxxApi`** 是 `const` 类,只持 `ApiClient`(构造注入)。方法形如 `Future<Dto> verb({命名参数})`,组装 `queryParameters`/`data` Map 再调 `apiClient.get/post/...`,响应交给 `Dto.fromJson` / `PaginatedResponseDto.fromJson(resp, Dto.fromJson)`。命名参数翻译为 **snake_case** 查询键。
- 可选 enum 参数各带 `apiValue`,只在非 null 时塞键;`sort` 多用 `"field:dir"` 字符串。
- **DTO 是 `const` 不可变类 + `factory fromJson`,字段全部 `as Type? ?? 默认值`,永不抛**;日期 `DateTime.tryParse`/`asDateTime`。复用 `core/json/json_parse.dart`,不自写私有解析(历史上各 DTO 文件有重复的 `_intFromJson` 等 helper,新代码勿再复制)。
- 可空字段的 `copyWith` 用 **sentinel 哨兵**区分"不改"与"改为 null"(`Object _sentinel`);普通字段用 `??`。
- 错误**不在 API 层处理**,向上抛由控制器用 `apiErrorMessage(error, fallback: ...)` 转中文。

## presentation 层范式

### 分页:优先继承 `PagedLoadController<T>`

`features/shared/presentation/paged_load_controller.dart` 是通用分页基类(`ChangeNotifier`):管 items/page/total/hasMore/loading/syncedAt,内置 `ScrollController` + `attachScrollListener()`(滚到底自动 `loadMore`),`initialize()`(仅一次)/`reload()`(强制)/`refresh()`(保留态)/`loadMore()`。**失败时:初次加载置 `initialErrorMessage`;loadMore 失败置 `loadMoreErrorMessage` 但保留原列表**(符合"分页失败保留+重试")。用 `notifyListenersSafely()` + `_isDisposed` 防 dispose 后 notify。子类用 `@protected mutableItems/mutableTotal/fetchPage` 扩展(订阅/删除等)。

> 两个已知 hack:`PagedHotReviewController`/`PagedMomentController` 给基类传**抛 `UnimplementedError` 的占位 fetchPage** 再 override,以注入 period/sort——别"修"成正常传参。
> 改 `PagedLoadController` 签名/行为会**波及所有子类**(rankings/actors/videos/hot_reviews/moments/movies…)。

但**不是所有控制器都继承它**:`clips`、搜索、图搜、合集详情、导入等因有 SSE 合并/游标分页/本地排序而**自写 `ChangeNotifier`**。

### 页面状态缓存

很多列表页用 `obtainCachedPageState<T>(context, key: ...)` + 实现 `AppPageStateEntry` 的 `*PageStateEntry`,跨导航保留滚动/筛选/已选。key 用 `app/app_page_state_cache_keys.dart` 工厂(详见 `lib/app/CLAUDE.md`);entry **必须 `dispose()`** 释放控制器。**注意:不是所有页都缓存**(如 clips 页不缓存,每次重建)。

### 筛选状态驱动(关键约定)

筛选状态是**不可变值对象**(`XxxFilterState` + `copyWith` + `isDefault`)。**关键:筛选状态不在控制器里**,而在 page state 的可写字段,fetcher 闭包**惰性读取**它拼参数。UI 改完筛选后必须调 **`controller.reload()`** 重新走闭包才生效——**改 controller 字段不会生效**。

### 跨页状态一致:mutation 广播

改订阅/合集/删除等影响其它页面的状态,通过**全局 mutation `ChangeNotifier`**(`MovieSubscriptionChangeNotifier`、`MovieCollectionTypeChangeNotifier`、`VideoMutationChangeNotifier`、`ClipMutationChangeNotifier`,在 `lib/app/app.dart` 装配)广播:发起方 `reportXxx`,监听方读 `lastChange` 做**就地补丁**(精准移除/`applyXxxChange`),不整页刷新。批量信号常用 `scheduleMicrotask` 合并成一次刷新。**任何新的改状态入口都要 reportChange。**

### 乐观更新 + 回滚

轻量增删(订阅、加入合集、删除)统一:先改本地 → 调 API → 失败精准回滚被改项 + toast。

### SSE 消费范式(三重终止兜底)

1. 置 loading + notify;2. `api.xxxStream(...).listen(onData,onError,onDone,cancelOnError:false)`,存 `StreamSubscription`;3. onData 调 `_applyUpdate`;4. **onError / onDone(仍在 loading 视为中断)/ completed 事件都要兜底置终态**;5. `_isDisposed` 守卫 + dispose 里 `unawaited(_subscription?.cancel())`。

## 各业务域地图

- **影片核心**:`movies`(最复杂,见其 CLAUDE.md)、`videos`(PornBox 非 JAV)、`clips`(切片)、`clip_collections`(切片合集)。
- **发现/检索**:`discovery`、`search`、`rankings`、`actors`、`tags`、`image_search`、`hot_reviews`。多复用 movies 的 `MovieListItemDto`/`MovieSummaryGrid`/`MovieListContent`。
- **用户/活动**:`auth`(登录)、`account`、`subscriptions`、`activity`(通知中心,见其 CLAUDE.md)、`moments`、`overview`、`status`。
- **配置/导入/媒体**:`configuration`(设置,见其 CLAUDE.md)、`media_import`、`media`、`downloads`、`external_player`、`playlists`、`workbench`。

### 短视频/切片域(videos / clips / clip_collections)要点

与 movies 平行但裁掉了订阅/下载/番号筛选。易踩:
- **三种分页实现并存**:videos 列表继承 `PagedLoadController`;**clips 列表自写**(别假设有基类方法);合集详情/导入各自手写。
- **video 合集成员端点已分页**:`getCollectionItems` 返回 `PaginatedResponseDto`;`getAllCollectionItems` **并发翻页拉全**——逻辑统一抽到 `core/network/fetch_all_pages.dart` `fetchAllPagesConcurrently`(先取第 1 页拿 `total`,其余页按并发上限 6 `Future.wait`、批内保序拼接;`page_size` 上限 100;并发期间集合被改导致页窗口错位时按 `keyOf` 去重),墙钟从串行 O(N) 降到 ~O(N/6)。连播页传 `includePlayUrl: true`,后端为每个成员**内联「首个媒体(Media.id 升序)」的签名 `playUrl`**(对称于 clip 成员自带 `streamUrl`),前端据此直接组装播放列表,**不再逐集 `getVideoDetail`**(已删 N+1 的 `Future.wait`)。`playUrl` 为空=不可播,跳过并把 `startIndex` 重映射到实际可播列表(索引不能直接用下标)。clip 合集成员自带 `streamUrl`,详情页与连播页共用 `ClipCollectionsApi.getAllCollectionClips`(同样调 `fetchAllPagesConcurrently`,按 `clipId` 去重)。
- **合集详情页 → 连播页 走「交接信箱」`CollectionPlaybackHandoff`**(`features/shared/presentation/`,在 `app.dart` 注册的普通 Provider):详情页 `_playFrom` 跳转前 `offerVideoItems/offerClips`(传当前已排序、带播放地址的成员),连播页 `_load` 先 `takeVideoItems/takeClips`(**一次性,取后清空**)、取不到再自行拉取。常规「详情页点某集进连播」路径下连播页**零额外请求、秒开**;深链/刷新回退到上面的并发拉取。**video 详情控制器因此改为 `includePlayUrl: true` 加载**(成员带 `playUrl` 才能交接直用)。
- **video 合集 reorder 必须提交全部成员**否则后端 422;clip 合集无 reorder 端点,拖序走 `setCollectionClips` 全量覆盖。
- **clips 的 `createClip` 同步切片**,前端超时 130s(后端 ffmpeg 120s);**超时≠失败**,关对话框让用户去"我的切片"查看。
- 这些域**直接复用 movies 的 `MovieImageDto`/`MovieMediaItemDto`**——改 movies 这些 DTO 会波及它们。
- 移动连播页 body 直接 `return` 桌面连播页(改桌面同时影响移动)。
- **连播页右侧「整部合集」关键帧面板**(`CollectionFilmstripController` + `CollectionPlaySplitLayout`,详见 `lib/widgets/CLAUDE.md`):把合集拉平成一部长片的逐帧进度条。两侧各注入「按集取帧」闭包——切片用 `ClipsApi.getClipThumbnails(clipId)`(`GET /media-clips/{id}/thumbnails`,offset 相对切片起点);pornbox 用 `MoviesApi.getMediaThumbnails(firstMediaId)`(`VideoCollectionItemDto.firstMediaId`,后端与 `playUrl` 同源但**恒返回、不依赖 `include_play_url`**;offset 相对媒体起点)。集索引须对齐**实际可播列表**(不可播/无 firstMediaId 的集帧段为空、自然跳过),pornbox 侧用与 `playableVideos` 平行的 `firstMediaId` 列表喂控制器。两个连播页的**播放器/跨集 seek/面板接线逐字相同部分已抽到** `CollectionPlaybackPageMixin`(`lib/widgets/movie_player/`),各页只剩 `_load`/剧集列表/底栏/`_QueueItem`——改 seek 补偿或面板接线只动 mixin 一处。

## 与测试的关系

测试镜像 `lib/`:`test/features/<feature>/{data,presentation}/`。改 API/DTO → `*_api_test`;改控制器 → `*_controller_test`。覆盖度参差:data 层与控制器较全,**很多页面 widget、弹窗、移动页、SSE 控制器缺直接单测**,改动需手动验证。
