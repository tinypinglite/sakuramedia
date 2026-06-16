# lib/app/ — 启动与全局装配

应用启动入口、平台判定、**全局 Provider 装配**、登录态驱动的页面状态缓存。这一层是整个应用的"接线盒",改动牵一发动全身。

## Provider 装配(`app.dart`)——顺序敏感

`MyApp` 在一个大 `MultiProvider` 里集中注册**所有** API 实例与全局 `ChangeNotifier`。注册有**强制依赖顺序**:

- `SessionStore` / `CredentialStore` 必须最前 → `ApiClient` 依赖 `SessionStore` → `AuthApi` 依赖三者 → 几乎所有 feature API `context.read<ApiClient>()`。
- 链式依赖示例:`ActivityEventStreamClient` → `ActivityApi`(依赖前者)→ `NotificationCenterController`(依赖 `ActivityApi`,全局常驻)。`AppVersionInfoController` 依赖 `StatusApi`。
- `AppPageStateCache` 用 `ChangeNotifierProxyProvider<SessionStore, ...>` 绑会话,**登出自动清空全部缓存**。

**新增 API / 全局 notifier**:加到 providers 列表,**且排在它依赖的 Provider 之后**,否则运行时 `ProviderNotFoundException`。页面通过 `context.read<XxxApi>()` 取用,不要在页面里 `new`。

> `app.dart` 还集中创建了大量本属 feature 层的全局 `ChangeNotifier`(`MovieSubscriptionChangeNotifier`、`MovieCollectionTypeChangeNotifier`、`VideoMutationChangeNotifier`、`ClipMutationChangeNotifier`、`ExternalPlayerStore` 等)。新增跨页同步 notifier 也在这里装配。

## bootstrap 顺序(`bootstrap.dart`)——不可打乱

`bootstrapApplication()` 的步骤有先后依赖:
1. binding 初始化最先(debug 用 `MarionetteBinding`、release 用 `WidgetsFlutterBinding`,单例首个生效);
2. `configureImageCacheBudget`(图片缓存预算);
3. `MediaKit.ensureInitialized`(之前不能用播放器);
4. 仅 Web 调 `disableContextMenu`;**仅桌面**初始化窗口(条件导入 `window_bootstrap_desktop.dart` / `window_bootstrap_stub.dart`)。

桌面窗口固定 `1440×800` 且 `minimumSize == size`(小屏会被强制撑大);macOS 隐藏标题栏 + 透明背景。

`main.dart` 是唯一用**真实持久化 `SessionStore`** 启动的路径(`SessionStore.create()`);测试用 `inMemory` 注入。`MyApp.didUpdateWidget` 在 `platformOverride`/`sessionStore` 变化时重建 router。

## 页面状态缓存(`app_page_state_cache*.dart`)

跨导航保留列表滚动位置/已加载数据/筛选状态。要点:
- key **必须用 `app_page_state_cache_keys.dart` 的工厂函数**生成(统一 `平台:业务域:子标识`,如 `desktop:movies:list`;搜索/图搜类带路由 location 作动态参数),**不要散写字符串**。
- 缓存条目实现 `AppPageStateEntry`,**必须实现 `dispose()`**(被 LRU 驱逐 / 登出清空时调用),否则泄漏。默认上限 24 条,LRU 驱逐最旧。
- 页面侧用 `obtainCachedPageState(...)`(`cached_page_state_handle.dart`);无 cache provider 时退化为本地 owned state。
- 登出(`hasSession` true→false)自动 `clear()` 全部条目。

## 与测试的关系

- 改 `bootstrap.dart`(尤其 `configureImageCacheBudget`)→ `test/app/bootstrap_test.dart`
- 改 `AppPageStateCache` / key → `test/app/app_page_state_cache_test.dart`
- 改 `AppVersionInfoController` → `test/app/app_version_info_controller_test.dart`
- **`app.dart` 的 provider 装配本身无直接单测**——改了靠 `flutter analyze` + 各 feature 页面测试间接覆盖,谨慎。
