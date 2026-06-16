# lib/routes/ — 路由与导航

三平台(desktop / mobile / web)的类型安全路由(`go_router_builder`)、平台选择、登录守卫、导航数据、跳转扩展方法。是 features 页面挂载到导航树的唯一入口。

## ⚠️ 改 typed route 必跑代码生成

任何对 typed route 的增删改(注解类、`@TypedGoRoute` path、字段、shell branch 结构)后**必须执行**:

```bash
dart run build_runner build --delete-conflicting-outputs
```

否则 `*.g.dart`(`$appRoutes`、`$XxxRouteData` mixin、`_fromState`)不更新 → 编译失败或路由错乱。`*.g.dart` 头部 `DO NOT MODIFY BY HAND`,**绝不手改**。仓库无 `build.yaml`,用默认配置。

## 平台路由选择(`app_router.dart`)

- `desktop`→`buildDesktopRouter`、`mobile`→`buildMobileRouter`、`web`→`buildWebRouter`。
- **Web 不是独立路由树**:`buildWebRouter` 复用 `desktop_routes.$appRoutes`,只把全局 `currentDesktopRoutePlatform` 设为 `web`。**改桌面路由会同时影响 Web**;Web 专属差异只能靠这个可变全局变量区分(目前仅 `LoginPage` 用)。
- **登录守卫** `redirect`(靠 `refreshListenable: sessionStore` 触发):无 session 且不在 `/login`→跳 `/login`;有 session 在 `/login`→跳对应平台 overview;`'/'`→按 session 去 overview 或 `/login`。

## typed route 定义范式

- 顶层(shell 外)用 `@TypedGoRoute<XxxRouteData>(path: ...)` 注解;shell 内 sub-route 写在 `@TypedShellRoute`(桌面)/`@TypedStatefulShellRoute`(移动)的 `routes:` 里,**不单独加 `@TypedGoRoute`**。
- 每个类 `extends` 一个本模块抽象基类(决定 page 包装:桌面多为 `NoTransitionPage`,移动子页 `CupertinoPage`+`AppMobileSubpageShell`)+ `with $XxxRouteData`。
- **带参路由手写 `location` getter 用 `buildRouteLocation(...)`(camelCase 键),但生成器默认 kebab-case**。因此 `buildContent` 里取参数**必须 `resolveXxxQueryParameter(state, names: ['camelCase','kebab-case'])` 同时兼容两种**。这是本层最关键的隐性约定,漏了会导致深链/历史 URL 解析失败。
- **路由声明顺序有意义**:`/search/image` 必须在 `/search/:query` 之前,否则被 `:query` 吞掉。
- 移动端要浮在底栏之上的子页声明 `static final $parentNavigatorKey = mobileRootNavigatorKey`;漏写会被困在 branch 内、底栏异常。

## 路径常量、顶栏、返回目标

- **路径一律引用 `app_route_paths.dart` 常量**,不写裸字符串。`app_navigation.dart` `export` 了它。`@Deprecated` 的手写 `buildXxxRoutePath` 新代码勿用。
- **顶栏**(桌面 `desktop_top_bar_config.dart`):`resolveDesktopTopBarConfig` 按 **path 前缀 if 链**算标题/返回路径。新增带返回栏的详情页**必须在此 if 链补一条**,否则标题错/返回按钮缺失。
- **返回目标** `AppBackDestination.defaultLocationForPath(path)`:按前缀把深链反推到合理列表页(兜底)。
- **image search 大字节禁止放 `extra`**:走 `ImageSearchDraftStore` 存草稿、URL 只带 `draftId`,`buildContent` 里 `context.read<ImageSearchDraftStore>().get(draftId)` 取回。

## 跳转与登出

页面跳转**统一走 `context.pushXxx(...)` / `context.goPrimaryRoute(path)`**(`app_navigation_actions.dart` 的扩展方法),**不让页面直接 `new RouteData` 或散落 `context.go(path)`**。新增可跳转页面要在此加一个 `pushXxx` 扩展方法。`context.logOut()` 同时清 session + 凭据。

## 新增页面标准流程

**列表主页(带侧边栏入口)**:① `app_route_paths.dart` 加 path 常量;② `app_navigation.dart` 加 `_NavSeed`(侧边栏/底栏入口)+ `_desktopRouteBuilders`/`_mobileRouteBuilders` 加 `path→Page` 映射(未命中回退 `WorkbenchPlaceholderPage`);③ `desktop_routes.dart`/`mobile_routes.dart` 加 typed route(spec 型用 `_DesktopShellSpecRouteData` 自动取 builder/title);④ 跑 build_runner。

**详情/带返回栏子页**额外:桌面在 `desktop_top_bar_config.dart` 补顶栏项、必要时补 `app_back_destination.dart`;移动用 `_MobileSubpageRouteData` 并按需加 `$parentNavigatorKey`;在 `app_navigation_actions.dart` 加 `pushXxx`。

## 与测试的关系

`test/routes/app_router_test.dart`(巨型,覆盖平台选择/守卫/page 包装/深链返回/顶栏/image search 等)、`app_navigation_logout_test.dart`。测试大量引用 path 常量与稳定 `Key`,**新增页面带稳定 `Key`**。改 typed route 先 build_runner 再跑测试。
