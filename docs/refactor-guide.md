# SakuraMedia Refactor Guide

## 1. 目标与范围

本文档基于当前 `sakuramedia` 仓库的实际实现做代码审查，目标是给后续 agent 一份可执行的重构指南，而不是抽象的架构建议。

本轮扫描重点覆盖：

- `lib/features/**/presentation`
- `lib/features/**/data`
- `lib/routes/**`
- `lib/widgets/app_shell/**`
- `lib/core/network/**`

判断标准：

- 是否存在明显重复的状态机、页面装配、路由样板或网络边界代码
- 是否已经出现“一个问题在多个 feature 内各写一遍”的趋势
- 抽象后是否能降低后续维护成本，而不会破坏当前桌面优先的实现边界

## 2. 总体结论

当前仓库不是“没有结构”，而是已经形成了一套可运行的结构，然后在多个 feature 中平铺复制。

最值得优先处理的不是 UI token，也不是大规模重写，而是下面 6 个重复簇：

1. 分页 controller 重复
2. 桌面/移动双页面装配重复
3. page-state cache 获取与生命周期重复
4. routes / shell 样板重复
5. data / core 边界的 query / JSON / error plumbing 重复
6. 详情 controller 的 load / refresh / error 包装重复

这 6 个点里，前 4 个收益最大，建议优先做。

## 3. 优先级排序

### P1. 分页 controller 抽象

重复最重的文件：

- `lib/features/movies/presentation/paged_movie_summary_controller.dart`
- `lib/features/actors/presentation/paged_actor_summary_controller.dart`
- `lib/features/rankings/presentation/paged_ranked_movie_controller.dart`
- `lib/features/hot_reviews/presentation/paged_hot_review_controller.dart`
- `lib/features/moments/presentation/paged_moment_controller.dart`

重复内容：

- `initialize`
- `reload`
- `refresh`
- `loadMore`
- `_loadPage(reset: ...)`
- scroll listener attach / detach
- `_safeNotifyListeners`
- dispose

额外重复：

- `paged_movie_summary_controller.dart` 与 `paged_ranked_movie_controller.dart` 还重复了订阅切换逻辑

建议抽象边界：

- 先抽一个窄基础层，例如 `PagedLoadController<T>`，只负责分页状态机
- 再按需要补 `ScrollLoadMoreSupport`
- 影片类列表再补 `MovieSubscriptionToggleSupport`

不要一开始就做成过度泛化的万能 controller。当前仓库更适合“一个稳定基础类 + 少量 feature wrapper”。

建议落地方式：

1. 先拿 `movies` 和 `rankings` 做第一版
2. 稳定后合并 `actors`
3. 最后迁移 `hot_reviews` 和 `moments`

原因：

- `movies` / `rankings` 的行为最像
- 回归路径清晰
- 测试已经比较完整，适合作为基线

### P1. 桌面 / 移动页面双份装配收口

最明显的重复对：

- `lib/features/actors/presentation/desktop_actor_detail_page.dart`
- `lib/features/actors/presentation/mobile_actor_detail_page.dart`
- `lib/features/movies/presentation/desktop_movies_page.dart`
- `lib/features/movies/presentation/mobile_movies_page.dart`

高概率还有同类问题的区域：

- `desktop_rankings_page.dart` / `mobile_rankings_page.dart`
- `catalog_search_page.dart` / `mobile_catalog_search_page.dart`

重复内容：

- controller 初始化
- filter apply / reset
- subscription toggle
- collection type 变化后的列表裁剪
- 滚动重置后 reload
- 主体列表渲染骨架

实际平台差异反而很有限，主要集中在：

- `surface` 颜色
- `pull-to-refresh`
- 路由跳转目标
- footer 呈现
- 局部 spacing
- 页头样式

建议抽象边界：

- 抽共享的“页面组合层”，不要直接抽成巨型 widget
- 推荐结构是：`SharedContent + Thin Platform Shell`

例如：

- `ActorDetailContent`
- `MovieListContent`
- `RankingListContent`

平台层只负责：

- 外层 shell
- padding / surface
- refresh 包装
- 导航回调
- 平台专属 header

建议实施顺序：

1. 先做 `actor detail`
2. 再做 `movies list`
3. 再评估 `rankings` 和 `search`

### P1. Page State Cache 接入模式收口

重复文件：

- `lib/features/movies/presentation/movie_list_page_state.dart`
- `lib/features/actors/presentation/actor_list_page_state.dart`
- `lib/features/search/presentation/catalog_search_page_state.dart`
- `lib/features/image_search/presentation/image_search_page_state.dart`
- `lib/features/rankings/presentation/rankings_list_page_state.dart`

重复消费点：

- `lib/features/movies/presentation/desktop_movies_page.dart`
- `lib/features/movies/presentation/mobile_movies_page.dart`
- `lib/features/actors/presentation/desktop_actors_page.dart`
- `lib/features/actors/presentation/mobile_actors_page.dart`
- `lib/features/search/presentation/catalog_search_page.dart`
- `lib/features/search/presentation/mobile_catalog_search_page.dart`
- `lib/features/image_search/presentation/desktop_image_search_page.dart`
- `lib/features/rankings/presentation/mobile_rankings_page.dart`

重复内容：

- `maybeReadAppPageStateCache`
- fallback local create
- `cache.obtain(...)`
- `_ownsPageState`
- dispose 分支
- bootstrap / initialize 时机控制

建议抽象边界：

- 加一个统一 helper，例如 `obtainCachedPageState<T>()`
- 或者做一个窄组件 / 宿主类，例如 `CachedPageStateHost<T>`
- entry 自身可以有一个很轻的基类，例如 `ControllerPageStateEntry<TController>`

注意：

- 这个抽象应该排在分页 controller 简化之后
- 否则只是把现在复杂的 page state 包了一层，收益会被稀释

### P2. Routes / Shell 样板清理

主要问题不在导航能力，而在样板太多。

重复文件与模式：

- `lib/routes/desktop_routes.dart`
- `lib/routes/mobile_routes.dart`
- `lib/routes/desktop_top_bar_config.dart`
- `lib/routes/app_navigation.dart`

明确重复点：

- `desktop_routes.dart` 里多个 route data 只是反复做 `firstWhere((spec) => spec.path == ...)`
- `mobile_routes.dart` 的 primary route data 也有同类重复
- `desktop_routes.dart` 与 `mobile_routes.dart` 都各自维护 `_buildLocation`、`_scopeFromQuery` 一类工具
- `app_navigation.dart` 通过 `navGroupsForPlatform(...)` 再生成 `routeSpecsForPlatform(...)`，但 `builder` 端是长串条件表达式
- `desktop_top_bar_config.dart` 里详情页 / 搜索页的 title 与 fallback 解析是硬编码分支

建议抽象边界：

- 先把“按 path 取 route spec”的逻辑收成 lookup helper 或 map
- 再把基础 route data 的重复 pageName / builder 模式做成更窄的工厂
- 最后再考虑整合 desktop / mobile 共享的 query helper

不建议现在做的事情：

- 不要把全部 typed routes 改造成动态元编程
- 不要为了消灭样板而牺牲 go_router typed route 的可读性

更合适的方向：

- 减少重复 lookup
- 减少重复 location builder
- 让 route spec 和 nav seed 的关联更直接

### P2. Data / Core Plumbing 收口

最适合抽成共享基础设施的，不是 repository，而是边界辅助代码。

#### 1) 分页 query / parse 重复

涉及文件：

- `lib/features/movies/data/movies_api.dart`
- `lib/features/actors/data/actors_api.dart`
- `lib/features/activity/data/activity_api.dart`
- `lib/features/rankings/data/rankings_api.dart`
- `lib/features/hot_reviews/data/hot_reviews_api.dart`
- `lib/features/media/data/media_api.dart`
- `lib/features/playlists/data/playlists_api.dart`

建议：

- 在 `lib/core/network/` 新增小型 helper
- 例如 `buildPagedQuery(...)`
- 或者 `ApiClient.getPage<T>(...)`

目标是减少：

- `page`
- `page_size`
- optional filters
- `PaginatedResponseDto.fromJson(...)`

的重复拼装

#### 2) JSON 宽松解析 helper 重复

涉及文件：

- `lib/features/image_search/data/image_search_session_dto.dart`
- `lib/features/movies/data/missav_thumbnail_result_dto.dart`
- `lib/features/downloads/data/download_request_dto.dart`
- `lib/features/actors/data/actors_api.dart`
- 以及若干 DTO 内部私有 map / date parse helper

建议：

- 抽到 `lib/core/network/json_decode_helpers.dart`

可包含：

- `asJsonMap`
- `asJsonList`
- `mapList<T>`
- `parseDateTimeOrNull`

#### 3) error payload decode 重复

涉及文件：

- `lib/core/network/api_client.dart`
- `lib/features/activity/data/activity_event_stream_client_web.dart`

建议：

- 抽一个共享的 error parser
- 例如 `ApiErrorParser.fromResponseBody(...)`

#### 4) 配置类 CRUD API 重复

涉及文件：

- `lib/features/configuration/data/media_libraries_api.dart`
- `lib/features/configuration/data/download_clients_api.dart`
- `lib/features/configuration/data/indexer_settings_api.dart`
- `lib/features/configuration/data/collection_number_features_api.dart`

建议：

- 只在 configuration 域内做窄抽象
- 不要扩展成全仓库的 repository 框架

### P3. 详情 Controller 基类化

重复文件：

- `lib/features/movies/presentation/movie_detail_controller.dart`
- `lib/features/actors/presentation/actor_detail_controller.dart`
- `lib/features/playlists/presentation/playlist_detail_controller.dart`

重复内容：

- `_entity`
- `_isLoading`
- `_errorMessage`
- `load`
- `refresh`
- 404 -> 友好文案

建议抽象边界：

- `LoadableDetailController<T>`

保留差异：

- `MovieDetailController` 的 preview 选择逻辑继续保留在子类或组合对象里

优先级放后面的原因：

- 好做
- 风险小
- 但总体收益不如分页和页面装配收口

## 4. 建议暂时不要抽象的区域

以下模块虽然也复杂，但当前不适合优先泛化：

- `lib/features/activity/presentation/activity_center_controller.dart`
- `lib/features/image_search/presentation/image_search_controller.dart`
- `lib/features/movies/presentation/movie_player_controller.dart`
- `lib/features/movies/presentation/movie_detail_missav_thumbnail_controller.dart`

原因：

- 它们不是简单重复，而是有真实业务编排复杂度
- 如果在分页基础设施还没稳定前就强行抽象，容易得到一层比原实现更难懂的“通用框架”

原则：

- 先收口简单重复
- 再观察复杂模块里哪些能力真正可复用

## 5. 推荐实施顺序

### Phase 1: 低风险高收益基础设施

1. 抽分页基础 controller
2. 把 `movies` 和 `rankings` 合到这套基础设施上
3. 抽 JSON decode helper
4. 抽 paged query helper

交付标准：

- 不改业务行为
- 测试全绿
- controller / API 文件长度明显下降

### Phase 2: 页面组合层收口

1. 合并 `desktop_actor_detail_page` / `mobile_actor_detail_page`
2. 合并 `desktop_movies_page` / `mobile_movies_page`
3. 视情况合并 `rankings` / `search`

交付标准：

- 平台差异只保留在 shell 层
- shared content 不依赖具体平台 route class

### Phase 3: Page State 与 Route 样板清理

1. 抽 `obtainCachedPageState<T>()`
2. 统一 page state entry 的生命周期模式
3. 抽 route spec lookup helper
4. 清理重复的 `_buildLocation` / `_scopeFromQuery`

交付标准：

- 页面 `initState` 不再充满 cache 接入样板
- route data 不再反复手写同一种 spec lookup

### Phase 4: 细部收尾

1. 抽 `LoadableDetailController<T>`
2. 清理 configuration CRUD 样板
3. 清理 Auth token persistence 重复
4. 抽 error payload decode helper

## 6. 后续 Agent 的执行约束

后续 agent 按本文档做重构时，建议遵守下面几条：

1. 一次只动一个重复簇，不要多线重构。
2. 优先改基础层，再改消费层。
3. 每个阶段都先迁移一组最相似的文件，不要一口气全仓替换。
4. 不要引入新的大层级，比如全仓库 repository / service / coordinator 三连。
5. 继续遵守现有 theme token 与桌面壳层约束，不要把重构顺手改成新 UI。
6. 对 shared abstraction 的命名要贴近当前仓库，而不是引入外部框架化术语。

## 7. 测试与回归重点

每个阶段至少覆盖以下测试面：

- 主题和共享组件变更：`test/theme/`、`test/widgets/`
- 路由与壳层变更：`test/routes/`、`test/app_shell_test.dart`、`test/app_shell_behavior_test.dart`
- page-state cache 变更：`test/app/app_page_state_cache_test.dart`
- controller 重构：对应 `test/features/**/presentation/*controller*_test.dart`
- API helper 重构：对应 `test/features/**/data/*_api_test.dart` 与 `test/core/network/`

额外注意：

- `test/theme/theme_source_guard_test.dart` 已经在保护视觉字面量，不要为了重构破坏它
- 分页 controller 改造后，要重点回归 `loadMore`、初次加载失败、滚动触发加载、dispose 后不再 notify

## 8. 一个可执行的首轮任务单

如果让其他 agent 直接开始做，建议第一轮只做下面这组：

1. 新增分页基础 controller
2. 迁移 `PagedMovieSummaryController`
3. 迁移 `PagedRankedMovieController`
4. 保持所有现有测试通过
5. 新增这套基础 controller 的单测

原因：

- 范围清晰
- 风险可控
- 成功后能为后续 `actors` / `moments` / `hot_reviews` 打模板

## 9. 一个可执行的第二轮任务单

第二轮建议做：

1. 抽 `ActorDetailContent`
2. 收口 `desktop_actor_detail_page.dart`
3. 收口 `mobile_actor_detail_page.dart`
4. 补页面共享内容相关测试

如果第二轮顺利，再继续 `movies list`。

## 10. 不建议的方案

本仓库当前阶段，不建议做下面这些事：

- 一次性重写所有 feature controller
- 强推 MVVM / Clean Architecture / repository 全家桶
- 为了抽象 routes 而牺牲 typed route 的清晰度
- 给 `activity` / `image_search` 硬套通用状态机
- 把桌面 / 移动所有页面完全合并成单文件

更合理的目标是：

- 降低重复
- 保留当前目录结构
- 提高后续 feature 的复用率
- 让 agent 能按阶段稳定推进
