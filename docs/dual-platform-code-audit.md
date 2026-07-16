# Desktop / Mobile 双端代码量审计

**审计日期**：2026-07-16

**当前状态**：保留双端代码量审计数据；原响应式 UI 迁移方向已废弃，不作为当前执行依据。本轮仅完成 LLM 设置的双端单页面收敛。

**审计目的**：识别当前 Desktop / Mobile 双端实现中代码量最大、重复程度最高的区域，作为后续按 feature 决定是否复用页面或状态的参考。

**历史关联方案**：`refactor/responsive-cross-platform-migration-plan.md`（已废弃）

> 本文后续关于 `AppLayoutMode`、canonical Router 和响应式页面的建议仅作为历史审计结论保留，不代表当前实施计划。LLM 设置的收敛是一个独立、封闭的试点，没有合并、复用或迁移废弃分支 `codex/refactor-ui` 中的任何响应式实现。

## 1. 结论摘要

按 `lib/` 中显式区分 Desktop / Mobile 的生产代码统计：

1. `configuration` 是代码量最大的单一 feature，共 7,562 行 Dart 有效代码。
2. `routes` 位居第二，共 4,079 行，其中 1,741 行是生成代码，手写平台代码约 2,338 行。
3. `videos`、`clips`、`clip_collections` 合并看作“媒体与合集”业务域时，共 6,822 行，是配置管理之外最大的统一对象。
4. `movies` 不是原始代码量最大的 feature，但影片详情两端重复浓度最高，是当前最适合率先统一的业务页面。
5. 原始代码量排名不应直接等同于实施顺序。推荐依次推进：Movies 试点、canonical Router、低风险浏览页、媒体与合集、配置管理、概览与活动中心。
6. 当前项目不是严格 MVVM，更准确的定义是“Feature-first 业务分包 + Data / Presentation 分层 + Provider / ChangeNotifier Controller 模式”，属于轻量 MVVM-like 混合架构。

当前 `lib/` 约有 97,274 行 Dart 有效代码，其中显式平台命名代码为 33,778 行，占约 34.7%；排除路由生成文件后，显式平台手写代码约为 32,037 行。

测试目录约有 66,655 行 Dart 有效代码，其中显式 Desktop / Mobile 测试为 29,189 行，占约 43.8%。统一页面后，测试应收敛为“同一页面 × compact / medium / expanded 尺寸矩阵”，但不得以减少测试代码为由删除平台能力与关键行为覆盖。

## 2. 统计口径

生产代码统计使用 `cloc` 的 Dart `code` 列，只统计 `lib/` 下路径或文件名明确包含以下形式的文件：

- `/desktop/`、`/mobile/`
- `desktop_*`、`mobile_*`
- `*_desktop.dart`、`*_mobile.dart`

因此本统计描述的是“显式平台分叉代码量”，不是可直接删除的重复代码量。以下内容不会因为统一响应式页面而自动消失：

- Web 下载、原生文件写入、相册权限等平台能力适配
- Android 外部播放器与 iOS 原生刷新语义
- macOS / Windows 窗口初始化和桌面材质能力
- 播放器触摸、键盘、全屏与系统能力差异

近似重复度通过以下方式辅助判断：

1. 配对同一 feature 中的 Desktop / Mobile 页面。
2. 规范化类名和标识符中的 `Desktop / Mobile`、`desktop / mobile`。
3. 忽略空行与纯注释行后做行序列匹配。

该结果只用于发现热点，不作为最终可删除行数承诺。布局差异较大的同一业务流程可能无法逐行匹配，而相同 import、括号和样板代码也可能被计入匹配行。

## 3. 显式双端生产代码排名

| 排名 | 模块 | Desktop | Mobile | 合计 | 判断 |
|---:|---|---:|---:|---:|---|
| 1 | `configuration` | 4,174 | 3,388 | **7,562** | 总节省上限最高，但状态、表单和危险操作复杂 |
| 2 | `routes` | 1,747 | 2,332 | **4,079** | 含 1,741 行生成代码；统一后可消除平台路由语义 |
| 3 | `videos` | 1,532 | 1,797 | **3,329** | 视频列表、合集、合集详情与连播均有双端壳 |
| 4 | `movies` | 1,651 | 1,206 | **2,857** | 详情页重复浓度最高，最适合作为试点 |
| 5 | `clip_collections` | 1,024 | 866 | **1,890** | 合集列表、详情、连播均可形成单页面 |
| 6 | `activity` | 1,313 | 396 | **1,709** | Desktop 活动中心有较多单端能力，实际可删量低于原始规模 |
| 7 | `clips` | 592 | 1,011 | **1,603** | 两端入口不同，但列表、选择和操作流程可共享 |
| 8 | `overview` | 371 | 1,185 | **1,556** | 信息架构差异大，主要工作是重新组合而非机械去重 |
| 9 | `widgets` | 905 | 627 | **1,532** | 壳层和导航可统一接口，平台材质能力仍需保留 |
| 10 | `actors` | 517 | 444 | **961** | 已有 shared content，适合低风险收敛 |
| 11 | `hot_reviews` | 671 | 27 | 698 | Mobile 主要作为概览 tab，需统一内容而非页面壳 |
| 12 | `playlists` | 245 | 435 | 680 | 详情已高度共享，列表页仍可统一 |
| 13 | `discovery` | 383 | 284 | 667 | Desktop 独立页与 Mobile 概览 tab 可共享内容源 |
| 14 | `rankings` | 204 | 368 | 572 | 规模较小但重复比例高，属于快速收益项 |
| 15 | `tags` | 120 | 112 | 232 | 双端规模小，适合随浏览域批量迁移 |

若按更高层业务域合并：

| 业务域 | 包含 feature | 显式平台代码 |
|---|---|---:|
| 配置管理 | `configuration` | **7,562** |
| 媒体与合集 | `videos` + `clips` + `clip_collections` | **6,822** |
| 路由与导航 | `routes` | **4,079** |
| 影片 | `movies` | **2,857** |
| 概览与活动 | `overview` + `activity` | **3,265** |

## 4. 主要重复热点

### 4.1 影片详情：当前最优先

对应文件：

- `lib/features/movies/presentation/pages/desktop/movie_detail_page.dart`
- `lib/features/movies/presentation/pages/mobile/movie_detail_page.dart`
- `lib/features/movies/presentation/pages/shared/movie_detail_page_content.dart`

两个页面分别约千行。规范化平台名称后，约有 769 个非空行可以直接匹配，占较小端约 82%。两端已经共同使用 `MovieDetailPageContent`，但以下业务编排仍分别存在于两个页面：

- `MovieDetailController`、`MovieClipsController` 生命周期
- 订阅、合集、媒体选择与操作锁状态
- 播放、预览、图片操作、播放列表和删除回调
- loading / error / content 状态组合
- 路由跳转和 Desktop / Mobile 弹层选择

目标应是形成一个平台无关的 `MovieDetailPage`：共享 Controller 生命周期和业务回调，只在页面一级组合处根据 `AppLayoutMode` 选择 compact / medium / expanded 布局。

影片列表已经具备较好的共享基础：

- `desktop/movies_page.dart` 与 `mobile/movies_page.dart` 都使用 `shared/movie_list_content.dart`。
- 当前主要剩余差异是 cache key、导航、筛选承载、刷新容器、表面颜色和间距。

因此 Movies 试点的大部分工作量和代码节省都集中在详情页，不应重新实现已有列表内容。

### 4.2 配置管理：总节省上限最高

重点配对关系：

| Desktop | Mobile | 当前共享基础 |
|---|---|---|
| `desktop_download_clients_section.dart` | `mobile_downloaders_page.dart` | `DownloadClientFormFields`、probe controller |
| `desktop_indexer_settings_section.dart` | `mobile_indexers_page.dart` | `IndexerEntryFormFields`、connection test controller |
| `desktop_media_libraries_section.dart` | `mobile_media_libraries_page.dart` | `MediaLibraryFormFields` |
| ~~`desktop_llm_settings_section.dart`~~ | ~~`mobile_llm_settings_page.dart`~~ | **已收敛**为唯一 `LlmSettingsPage` + Riverpod Notifier + Hook 表单宿主 |
| `desktop_account_security_section.dart` | `mobile_change_username_page.dart`、`mobile_change_password_page.dart` | account API / profile controller |

当前已经共享部分字段组件和 Controller，但加载、保存、脏状态、列表操作、弹层、确认和反馈仍由两端页面分别编排。

LLM 设置试点已作为例外先行完成：旧双端页面、`LlmSettingsController` 和旧字段胶水组件已删除。Desktop 配置区与 Mobile 设置路由现在直接使用同一个 `LlmSettingsPage`；两端只保留路由/父容器接入差异，不再保留两份 LLM 页面布局。该试点不依赖已废弃的响应式 UI 分支，也不引入 `AppLayoutScope`。

迁移时应按下载器、索引器、媒体库、LLM、账户安全逐个垂直收敛，形成：

1. 一份状态与业务编排。
2. 一份表单内容。
3. compact 子页与 expanded 设置 section 两种外层组合。

不建议建立一个覆盖所有设置类型的万能配置页面或万能表单基类。

### 4.3 切片与视频合集详情：适合提取共同骨架

对应四个大页面：

- `clip_collections/.../desktop/clip_collection_detail_page.dart`
- `clip_collections/.../mobile/clip_collection_detail_page.dart`
- `videos/.../desktop/video_collection_detail_page.dart`
- `videos/.../mobile/video_collection_detail_page.dart`

切片合集详情双端合计约 1,337 个物理行，规范化后约 332 行直接相似；视频合集详情双端合计约 1,317 个物理行，约 239 行直接相似。

四个页面共同包含：

- Controller 初始化、加载、错误和空态
- 列表 / 网格切换
- `MultiSelectStateMixin`
- `CollectionMemberRow` / `CollectionMemberCard`
- 选择栏和批量操作栏
- 合集播放、成员移除、删除和 mutation 通知
- Desktop 重排与 Mobile 显式选择操作

推荐提取“自适应合集详情骨架”，只通过 adapter / callback 注入 Clip 与 Video 的 DTO、Controller 和领域动作。Desktop 的 hover / 重排与 Mobile 的长按 / 操作表应继续作为输入增强，不应被抹平成单一交互。

### 4.4 路由：必须在全量业务迁移前收敛

当前 `lib/routes/app_router.dart` 仍按 `AppPlatform` 选择：

- `desktop_routes.dart`
- `mobile_routes.dart`

双端路由不仅产生 route class 和生成文件重复，还让以下内容持续平台化：

- URL 前缀
- 页面构造
- 导航 action
- fallback path
- cache key
- shell 与分支状态
- 路由测试

Movies 试点验证单页面模式后，应立即推进 canonical Router。否则每迁移一个新 feature，仍需维护两套路由接缝，去重收益会被抵消。

### 4.5 Actors / Rankings / Tags：低风险快速收益

这几个 feature 的总规模不及配置和媒体域，但两端结构与测试高度相似：

- Actors 详情已有 `actor_detail_content.dart`。
- Rankings 两端页面规范化后，较小端约 82% 可以匹配。
- Tags 双端页面规模小，双端测试近似度高。

适合作为 Movies 和 canonical Router 之后的第一批批量迁移对象。

## 5. 推荐实施顺序

### 第 1 步：Movies 试点

1. 定义平台无关的 movies page state key。
2. 先把列表两个薄壳收成单一 `MoviesPage`。
3. 把详情页 Controller 生命周期、操作状态和业务回调收进单一 `MovieDetailPage`。
4. 保留 shared content，只在一级组合边界选择三档布局。
5. 将两端测试收敛为同一页面的 390 / 768 / 1440 宽度矩阵。

这一步与 `refactor/responsive-cross-platform-migration-plan.md` 的阶段 3 及 `refactor/responsive-phase-2-handoff.md` 的交接结论一致。

### 第 2 步：canonical Router

1. 建立一套 typed routes 和一个 Router 构建入口。
2. 移除平台对业务 URL 和页面语义的决定权。
3. 保留旧 `/desktop/*`、`/mobile/*` 地址的兼容重定向。
4. 同步迁移导航 action、cache key、fallback 和测试。

### 第 3 步：低风险浏览域

建议顺序：

1. `rankings`
2. `actors`
3. `tags`
4. `playlists`
5. `search`

这一批已有 shared content 或双端结构高度相似，适合快速固化统一页面范式。

### 第 4 步：媒体与合集

建议先构建共同合集详情骨架，再依次迁移：

1. `video_collections`
2. `clip_collections`
3. `videos`
4. `clips`
5. collection playback / player 路由

播放器的输入和平台能力差异应独立保留，不以减少文件数为目标强行合并。

### 第 5 步：配置管理

按独立业务切片迁移：

1. LLM 设置
2. 媒体库
3. 索引器
4. 下载器
5. 账户安全
6. 高级设置与其它桌面管理项

LLM 设置已验证“同一 Riverpod Notifier + 同一 Hook 表单宿主 + 同一页面组件”；后续配置 feature 是否沿用完全单页面模式，需要按各自弹层和危险操作复杂度单独评估。

### 第 6 步：概览、活动与系统管理

`overview`、`activity`、媒体维护和系统诊断的 Desktop / Mobile 信息架构差异较大，应在统一页面模式稳定后处理。该波次主要目标是共享内容、Controller 和卡片，不应机械追求两端像素级一致。

## 6. 代码缩减原则

1. 优先删除重复业务状态和回调，不只把两端 Widget 移到同一个文件。
2. 平台无关页面只在组合边界读取 `AppLayoutMode`。
3. 运行能力继续由平台 service / adapter 表达，不使用布局模式推断权限、文件、播放器或输入能力。
4. 共享 content 不应膨胀成包含大量 `isMobile` 参数的万能组件。
5. resize 不得重建 Router、Controller、SSE client 或首屏数据。
6. 旧页面在迁移期只能作为转发薄壳，不允许继续承载新业务逻辑。
7. 测试去重应共享 fixture、交互 helper 和页面矩阵，不能删掉 Desktop 键盘、Mobile 触摸或 Web 浏览器能力覆盖。

## 7. 后续复核

每完成一个迁移波次后，应重新执行同口径统计并记录：

- `lib/` 显式平台代码总量
- 对应 feature 的 Desktop / Mobile 行数变化
- 旧页面和旧 route 剩余引用
- shared content 与平台薄壳的行数变化
- 双端测试是否已转换为统一页面尺寸矩阵
- 为平台能力保留的代码及保留理由

目标不是让仓库中完全没有 `desktop` 或 `mobile` 字样，而是确保这些字样只用于真实的平台能力、布局宿主或输入增强，不再复制业务页面和状态编排。

## 8. 架构形态与分层代码量

### 8.1 架构结论

当前项目最准确的架构描述是：

> Feature-first 业务分包 + Data / Presentation 两层结构 + Provider 依赖注入 + ChangeNotifier Controller / PageState 状态管理。

它具有明显的 MVVM 特征，但不是严格 MVVM，也不是 Clean Architecture：

| MVVM 角色 | 当前项目中的对应实现 | 结论 |
|---|---|---|
| View | `presentation/pages`、页面同目录文件、feature widgets、共享 `lib/widgets` | 对应关系明确，但部分 View 同时持有业务状态和异步操作 |
| ViewModel | `*Controller`、`*PageStateEntry`、filter state、mutation notifier | 大量使用 `ChangeNotifier`，承担加载、分页、错误和界面状态，属于 ViewModel-like |
| Model | DTO、API、store、`ApiClient`、SessionStore | 以服务端 DTO 和 API client 为主，没有独立领域模型层 |
| Binding / DI | `provider`、`MultiProvider`、`context.read/watch`、`AnimatedBuilder` | 采用显式依赖注入和监听，没有代码生成式双向绑定 |
| Navigation | `go_router` typed route | 独立于 MVVM，当前仍存在 Desktop / Mobile 两套路由树 |

建议对外统一称为“Feature-first 分层架构”或“Provider / ChangeNotifier 的轻量 MVVM-like 架构”，不建议直接宣称为严格 MVVM。

### 8.2 为什么不是严格 MVVM

#### 1. Controller 很像 ViewModel

例如 `MovieDetailController`：

- 继承 `ChangeNotifier`。
- 保存 loading、error、详情、相似影片和预览选择状态。
- 接收异步 fetch 函数而不是依赖具体 Widget。
- 通过 `notifyListeners()` 驱动界面更新。

通用 `PagedLoadController<T>` 也集中管理分页数据、初次加载、加载更多、错误和滚动监听。当前仓库共约 45 个 controller 文件，并能检出约 45 个直接继承或混入 `ChangeNotifier` 的状态类。

这部分符合 ViewModel / Presentation Model 的基本职责。

#### 2. 页面仍承担较多 ViewModel 职责

部分页面会直接：

- 从 `BuildContext` 读取 API。
- 创建和销毁多个 Controller。
- 保存订阅、合集、删除、选择、弹层等业务状态。
- 执行 API mutation、错误转换和 toast 反馈。
- 决定 Desktop / Mobile 路由和交互容器。

例如两个 `movie_detail_page.dart` 都在页面 State 内创建 `MovieDetailController`、`MovieClipsController`，并保存多组 mutation override 和 action lock 状态。这些状态没有完全进入共享 Controller，因此页面并非纯 View，也是双端重复代码的主要来源。

#### 3. 没有独立 Repository / UseCase / Domain 层

当前典型调用链是：

```text
Page / Widget
  -> Controller / PageState
    -> FeatureApi
      -> ApiClient / SSE client
        -> Backend
```

API 通常直接返回 DTO，Controller 和 Widget 直接消费 DTO。仓库没有系统性的 Repository、UseCase、领域 Entity 或 Mapper 层。这种结构对于桌面优先的前端工作台足够轻量，但不属于 Clean Architecture 或严格分层 MVVM。

#### 4. 分层依赖存在少量反向引用

数据层原则上应独立于 presentation，但当前存在两个明确反向依赖：

- `actors/data/api/actors_api.dart` 导入 `actors/presentation/.../actor_filter_state.dart`。
- `movies/data/api/movies_api.dart` 导入 `movies/presentation/.../movie_filter_state.dart`。

这意味着筛选条件同时承担界面状态和 API request 参数职责。后续可将 API 所需枚举或 query object 移到 data/domain-neutral 位置，让依赖方向恢复为 presentation → data。

#### 5. Feature 边界是组织边界，不是严格模块边界

presentation 内部当前约有：

- 683 次同 feature import。
- 321 次跨 feature import。
- 110 个 presentation 文件直接依赖其它 feature。

常见依赖包括 `tags / rankings / actors / discovery -> movies`、`clips <-> clip_collections`、`movies -> clips / media / configuration`。这些依赖反映真实业务组合，但说明 feature 目录当前主要用于代码组织，并非具有严格依赖规则的独立模块。

### 8.3 顶层目录代码量

统计基线仍为 `lib/` 下 97,274 行 Dart 有效代码：

| 顶层目录 | 代码行 | 占 `lib/` | 文件数 | 主要职责 |
|---|---:|---:|---:|---|
| `features/` | **68,207** | **70.1%** | 355 | 业务数据、状态、页面和 feature 组件 |
| `widgets/` | **18,735** | **19.3%** | 116 | 基础组件、领域组件、壳层 |
| `routes/` | **5,219** | **5.4%** | 14 | Router、typed routes、导航动作与生成代码 |
| `theme/` | **2,432** | **2.5%** | 12 | 颜色、间距、组件、排版和阴影 token |
| `core/` | **1,888** | **1.9%** | 31 | 网络、会话、媒体能力、格式化与校验 |
| `app/` | **647** | **0.7%** | 10 | 启动、组合根、全局缓存和应用状态 |
| 根目录 Dart 文件 | 133 | 0.1% | 2 | 主题出口等入口文件 |
| `config/` | 13 | <0.1% | 1 | 应用级配置 |

`routes/` 的 5,219 行中：

- 手写代码：3,478 行，12 个文件。
- 生成代码：1,741 行，2 个 `.g.dart` 文件。

### 8.4 按架构职责估算

目录并不能完全对应架构层，因此进一步按职责重新归类。该表是基于目录和文件命名的近似值：

| 架构职责 | 代码行 | 占 `lib/` | 包含内容 |
|---|---:|---:|---|
| View / UI 与设计系统 | **69,761** | **71.7%** | feature pages/widgets/forms、直接页面文件、`lib/widgets`、theme、占位页面 |
| ViewModel-like 状态与业务编排 | **11,133** | **11.4%** | controllers、PageState、filter/store、presentation actions |
| Model / Data 与基础服务 | **10,501** | **10.8%** | feature data、DTO、API、store、`core/network/session/media` |
| Application / Router / Composition Root | **5,879** | **6.0%** | `app/`、`routes/`、应用配置，包含 1,741 行生成代码 |
| **总计** | **97,274** | **100%** | — |

需要注意：11,133 行只是已经从文件路径和名称上分离出来的状态与业务编排。大量页面 State 内嵌的异步操作、mutation 状态和回调仍被计入 View / UI，因此实际“ViewModel 职责代码”高于 11.4%。这也是双端统一时最值得迁出的部分。

### 8.5 Feature 内部 Data / Presentation 比例

`features/` 内部结构为：

| 层级 | 代码行 | 占 `features/` | 占 `lib/` |
|---|---:|---:|---:|
| `presentation/` | **59,412** | **87.1%** | **61.1%** |
| `data/` | **8,613** | **12.6%** | **8.9%** |
| 其它 / workbench 占位 | 182 | 0.3% | 0.2% |

主要 feature 的层级构成：

| Feature | 总计 | Data | Presentation | Presentation 占比 |
|---|---:|---:|---:|---:|
| `movies` | **12,896** | 1,317 | 11,579 | 89.8% |
| `configuration` | **12,085** | 1,433 | 10,652 | 88.1% |
| `videos` | **5,980** | 679 | 5,301 | 88.6% |
| `activity` | **5,241** | 793 | 4,448 | 84.9% |
| `clip_collections` | **3,329** | 185 | 3,144 | 94.4% |
| `media` | **2,964** | 777 | 2,187 | 73.8% |
| `image_search` | **2,345** | 178 | 2,167 | 92.4% |
| `downloads` | **2,330** | 598 | 1,732 | 74.3% |
| `clips` | **2,318** | 252 | 2,066 | 89.1% |
| `playlists` | **2,065** | 200 | 1,865 | 90.3% |

当前业务代码明显是 UI / Presentation-heavy。跨端收敛的主要节省空间在 presentation，而不是 DTO 或 API 层。

### 8.6 Presentation 内部构成

`features/presentation` 的 59,412 行进一步分为：

| Presentation 职责 | 代码行 | 占 Presentation | 统计组成 |
|---|---:|---:|---|
| 页面与 UI 组合 | **48,279** | **81.3%** | `pages/`、`widgets/`、`forms/`、hints、直接 page/tab/section/dialog/card 文件 |
| 状态与业务编排 | **11,133** | **18.7%** | `controllers/`、直接 controller、PageState/filter/store、actions |

按原始目录看：

| Presentation 目录/形态 | 代码行 | 文件数 |
|---|---:|---:|
| `pages/` | 20,724 | 60 |
| presentation 直属文件 | 19,292 | 73 |
| `widgets/` | 12,284 | 67 |
| `controllers/` | 4,761 | 40 |
| `actions/` | 1,173 | 6 |
| `forms/` | 875 | 3 |
| `hints/` | 303 | 7 |

直属 presentation 文件中还包含约 4,623 行 controller、576 行 state/filter/store，以及约 2,934 行 dialog/drawer/card/pane 等 UI 组件。说明早期 feature 与后期 feature 的目录规范尚未完全一致。

### 8.7 Data 内部构成

`features/data` 的 8,613 行按职责分为：

| Data 职责 | 代码行 | 占 Data | 文件数 |
|---|---:|---:|---:|
| DTO / 数据模型 | **5,789** | **67.2%** | 56 |
| API client | **2,158** | **25.1%** | 25 |
| Store / channel / specialized client | 233 | 2.7% | 4 |
| 其它 data helper / enum / mapping | 433 | 5.0% | 13 |

数据层以 DTO 映射和薄 API client 为主，基本没有额外 Repository / Domain Model 层。对当前目标而言，不需要为了“看起来像标准 MVVM”批量增加 Repository 和 UseCase；那会增加代码量而不直接改善双端复用。

### 8.8 共享 Widget 层构成

`lib/widgets` 共 18,735 行：

| Widget 层级 | 代码行 | 文件数 | 职责 |
|---|---:|---:|---|
| `domain/` | **11,393** | 54 | 影片、媒体、合集等领域 UI 物料 |
| `base/` | **6,193** | 54 | 按钮、表单、反馈、布局、弹层、媒体基础组件 |
| `shell/` | **1,149** | 8 | Desktop / Mobile / Adaptive 壳层与导航宿主 |

这一层已经承担了较多跨 feature 复用，是后续双端统一的良好基础。需要防止把页面业务状态继续下沉到共享 Widget；共享 Widget 应保持输入参数和回调驱动。

### 8.9 对后续统一工作的影响

基于当前架构，不建议为了双端统一进行一次性大爆炸重写。Feature-first 业务分包继续保留；状态与依赖体系按 `docs/riverpod-incremental-adoption-plan.md` 渐进迁移，最终以 Riverpod 全面替代 Provider / ChangeNotifier 业务状态。

1. **View 变薄**：把双端页面中重复的 Controller 生命周期、mutation 状态、异步动作和错误处理移入共享 Notifier / State。
2. **按 feature 迁移**：现有 Controller 在对应 feature 迁移前继续合法存在，迁移完成后退出生产调用；不需要先批量改名为 `ViewModel`。
3. **单向依赖**：清理 data → presentation 反向 import；API 接受 data-neutral request/query 类型。
4. **共享业务编排而非只共享 Widget**：只提取 content Widget 不能消除页面 State 重复。
5. **控制跨 feature 依赖**：高频依赖优先通过明确的共享领域组件、action/service 或 feature facade 暴露，不直接引用对方的页面内部实现。
6. **不引入无收益层级**：除非出现离线缓存、多数据源切换或复杂领域规则，否则不批量增加 Repository / UseCase 样板。
7. **Router 作为应用层统一**：canonical Router 完成后，页面不再知道 Desktop / Mobile route class，只依赖业务导航语义。

目标架构可以表述为：

```text
App composition root / canonical Router
  -> Feature page（只处理响应式组合）
    -> Riverpod Notifier / State（共享状态与业务编排）
      -> FeatureApi / Store（数据访问）
        -> ApiClient / platform capability adapter

Shared widgets / theme
  -> 仅提供视觉、布局、输入增强和领域 UI 物料
```

Riverpod 可以进入 API/service 装配、Session、Router 刷新依赖和全局缓存；API、DTO、Router、主题接缝与共享 Widget 也允许在对应阶段调整。Riverpod 不直接替代这些对象的职责，但最终生产代码将删除 Provider 依赖和业务 ChangeNotifier。该渐进路线同时服务“统一双端、减少代码量”和“完整迁移 Riverpod”两个目标。
