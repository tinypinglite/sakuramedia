# lib/features/configuration/ — 设置/配置域

最大的非影片 feature(~9.8k 行)。**桌面端是一个聚合页**(`desktop_configuration_page.dart`,左 `AppSettingsRail` + 右 `IndexedStack`,8 个分类),**移动端是 4 个独立路由页**(媒体库/下载器/索引器/LLM)。先读 `lib/features/CLAUDE.md`。

## 无本地持久化——全走后端 REST

**没有 `settings.json` / shared_preferences 配置项**,所有配置直接读写后端。每个子域一对 `*_api.dart` + `*_dto.dart`(在 `lib/app/app.dart` 注册 Provider):

| 子域 | 端点 | 形态 |
|---|---|---|
| 媒体库 | `/media-libraries` | 列表 CRUD |
| 下载器 | `/download-clients` | 列表 CRUD(`password` 留空=不改) |
| 索引器 | `/indexer-settings` | 单对象 GET + **整体 PATCH**(整批 indexers) |
| 合集特征 | `/collection-number-features` | GET + PATCH(`?apply_now=bool` 触发全库重算,返回 `sync_stats`) |
| LLM/翻译 | `/movie-desc-translation-settings` | GET + PATCH + POST `/test` |

DTO:snake_case↔camelCase,配套 `CreateXxxPayload`/`UpdateXxxPayload`(Update 用 `if(x!=null)` 部分更新)。`IndexerEntryDto` 因整批回传**同时有 `fromJson` 和 `toJson`**。

## 桌面范式:左 Rail + IndexedStack + active 懒加载

- 8 个分类在 `_categories`(`desktop_configuration_page.dart` 顶部)定义,**顺序即右侧 `IndexedStack` 索引**。
- 每个 tab 接收 `active` bool,**仅 active 时才发请求**(守卫 `if(!_initialized && !widget.active) return SizedBox.shrink();`)。加载逻辑**同时写在 `initState` 和 `didUpdateWidget`**。
- 分组卡片用 `AppSettingsGroup`/`AppSettingCell`("新增"按钮本身也是个 accent 色 `AppSettingCell`);编辑用 `showDialog`+`AppDesktopDialog`,表单复用 `MediaLibraryFormFields`/`DownloadClientFormFields`/`IndexerEntryFormFields`。

## 移动范式:独立全屏页 + 抽屉 + 乐观更新

`_OverviewCard` + `AppAdaptiveRefreshScrollView` + 底部 `AppButton`;CRUD 全走 `showAppBottomDrawer`(编辑/详情-动作/删除三段式,enum 返回动作);乐观更新(抽屉返回新 DTO → 本地 upsert → `unawaited(_syncXxxInBackground())` 后台对账,**对账失败只 toast 不回滚**)。

## ⚠️ 编辑前必须知道的坑

1. **`_categories` 顺序 = IndexedStack 索引 = `active: _selectedIndex == N` 的硬编码 N**(三处)。插入/重排分类必须同步改三处,否则 active 判断错位、错误 tab 发请求。`itemKey` 沿用原 tab key 保持深链/测试兼容。
2. **active 懒加载双触发**:`initState`(首屏即 active)和 `didUpdateWidget`(切到该 tab)两处都要改,都靠 `_initialized && !_isLoading` 防重入。
3. **媒体维护 tab 不包滚动容器**(直接嵌 `DesktopMediaMaintenancePage`,它自带无限滚动)。
4. **索引器持久化时机两端不一致**:桌面延迟批量(点"保存配置"才提交)、移动每次抽屉提交即时落库。
5. **LLM 桌面/移动逻辑各一份**(两份独立 `_LlmConfigTestState` enum、`_isValidHttpUrl`),改校验/流程两边都改。
6. **下载器密码**:编辑时留空=保持原密码,校验对编辑放行空密码。

## 跨模块契约(改这里会动全局)

- **LLM 配置 = 全站翻译开关的唯一入口**(同时驱动影片标题/简介翻译)。
- **媒体库是下载器的依赖根**(删媒体库会让下载器 `mediaLibraryId` 失效)。
- **下载器←索引器绑定链**:索引器条目必须绑定下载器才能投递(影片详情页搜索结果依赖此链路)。
- **合集特征 `apply_now=true`** 触发全库 `is_collection` 重算。
- **账号安全改密码**后用新密码重登校验 → `context.logOut()` 强制重登(影响全局登录态)。
- 部分分类是**跨 feature 嵌入**:账号安全(account/auth)、播放列表(playlists)、媒体维护(media)。
- 注意:CLAUDE.md/全局提到的**"图片模糊"开关不在本模块**(它是 `lib/config/AppImageConfig` 运行时常量),别在 configuration 里找。

## 与测试的关系

`test/features/configuration/`(测试量约源码 1/2):`configuration_api_test.dart`(DTO/payload 序列化)、`presentation/desktop_configuration_page_test.dart`(最重,按 `configuration-tab-*`/`*-create-button`/`*-card-{id}` Key 驱动)、各 `mobile_*_page_test.dart`。任何 Key、toast 文案、按钮 enable 条件改动都可能触发测试失败。
