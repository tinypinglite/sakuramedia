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
- **video 合集成员只有概要、无播放地址**:连播前必须逐集 `getVideoDetail` 解析首个可播 media,并把 `startIndex` 重映射到实际可播列表(不可播项被跳过,索引不能直接用下标)。clip 合集成员自带 `streamUrl`,简单。
- **video 合集 reorder 必须提交全部成员**否则后端 422;clip 合集无 reorder 端点,拖序走 `setCollectionClips` 全量覆盖。
- **clips 的 `createClip` 同步切片**,前端超时 130s(后端 ffmpeg 120s);**超时≠失败**,关对话框让用户去"我的切片"查看。
- 这些域**直接复用 movies 的 `MovieImageDto`/`MovieMediaItemDto`**——改 movies 这些 DTO 会波及它们。
- 移动连播页 body 直接 `return` 桌面连播页(改桌面同时影响移动)。

## 与测试的关系

测试镜像 `lib/`:`test/features/<feature>/{data,presentation}/`。改 API/DTO → `*_api_test`;改控制器 → `*_controller_test`。覆盖度参差:data 层与控制器较全,**很多页面 widget、弹窗、移动页、SSE 控制器缺直接单测**,改动需手动验证。
