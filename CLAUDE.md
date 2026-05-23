# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

SakuraMedia 是一个基于 Flutter 的 Jav 观影平台前端，面向 NAS 用户，覆盖影片发现、订阅、下载、播放与信息翻译。当前实现以桌面端为主，移动端和 Web 端仅具备基础路由与占位页面。

## 常用命令

```bash
# 获取依赖
flutter pub get

# 运行桌面端（macOS）
flutter run -d macos

# 运行 Web
flutter run -d chrome

# 运行 Android
flutter run -d android

# 运行全部测试
flutter test

# 运行单个测试文件
flutter test test/features/movies/movies_api_test.dart

# 静态分析
flutter analyze

# 路由代码生成（修改路由定义后需要执行）
dart run build_runner build --delete-conflicting-outputs

# 本地查看 Wiki 文档
cd wiki && npm run docs:dev
```

## 架构

### 技术栈
- Flutter + Dart (SDK ^3.7.2)
- `go_router` + `go_router_builder`：类型安全路由，路由定义在 `lib/routes/`，生成代码为 `*.g.dart`
- `provider`：依赖注入与局部状态管理
- `dio`：HTTP 请求，封装为 `ApiClient`（`lib/core/network/api_client.dart`）
- `media_kit`：视频播放
- `window_manager`：桌面窗口初始化
- `shared_preferences`：会话持久化

### 目录结构
- `lib/app/`：应用启动入口（`main.dart` → `bootstrapApplication()` → `MyApp`）、平台判定（`AppPlatform`）、全局 Provider 装配
- `lib/core/`：基础能力层
  - `network/`：`ApiClient`、`AuthInterceptor`（自动 token 刷新）、`ApiException`、SSE 支持
  - `session/`：`SessionStore`（`ChangeNotifier`，管理 baseUrl / accessToken / refreshToken）
  - `media/`：媒体 URL 构建工具
  - `format/`：时间格式化
- `lib/features/`：按业务域组织，每个 feature 遵循 `data/` + `presentation/` 模式
  - `data/`：`*_api.dart`（接口请求）、`*_dto.dart`（JSON 映射）
  - `presentation/`：页面、控制器、筛选状态
- `lib/routes/`：路由定义与导航
  - `desktop_routes.dart` / `mobile_routes.dart`：使用 `go_router_builder` 的类型安全路由
  - `app_router.dart`：根据平台选择路由配置，含登录守卫重定向逻辑
  - `app_route_paths.dart`：路由路径常量
- `lib/widgets/`：共享组件
  - `app_shell/`：桌面壳层（`AppDesktopShell`、`AppSidebar`、`AppTopBar`）与移动壳层
  - `forms/`：`AppButton`、`AppTextField`、`AppSelectField` 等表单组件
  - 其余子目录按业务域组织对应的共享组件
- `lib/theme/` + `lib/theme.dart`：设计系统 token 体系（颜色、间距、圆角、阴影、排版），桌面端与移动端各有独立配置
- `lib/config/`：应用级配置（如图片缓存参数）
- `test/`：对应 `lib/` 结构的测试目录

### 平台路由策略
- `AppPlatform` 枚举：`desktop`、`mobile`、`web`
- Web 端复用桌面路由（`buildWebRouter` 使用 `desktop_routes`）
- 路由路径分 `desktop_*` 和 `mobile_*`，通过 `app_route_paths.dart` 常量引用
- 未登录用户重定向到 `/login`，已登录用户访问登录页重定向到对应平台的概览页

### Provider 装配
`MyApp` 在 `MultiProvider` 中集中注册所有 API 实例和状态，各 feature 的 API 通过 `context.read<XxxApi>()` 获取。新增 API 需在 `lib/app/app.dart` 的 providers 列表中注册。

## 开发约束

1. **以代码为准**：文档与代码冲突时，以 `lib/theme.dart`、`lib/theme/*.dart`、`lib/widgets/app_shell/`、`lib/features/**/presentation/` 为准，并同步更新文档。

2. **桌面端优先**：涉及布局和导航时复用桌面壳层（`AppDesktopShell`、`AppSidebar`、`AppTopBar`），不要假设移动端/Web端有完整页面。

3. **设计系统优先**：颜色/间距/圆角/阴影/尺寸统一来自 `lib/theme.dart` 导出的 token，优先使用已有共享组件（`AppButton`、`AppTextField`、`AppSelectField`、`AppTabBar`、`AppEmptyState`、`AppContentCard`），不在业务页面散落裸值。

4. **遵循 feature 组织方式**：新增功能沿用 `data/*_api.dart` + `data/*_dto.dart` + `presentation/*controller.dart` / 页面 State 的模式。

5. **状态反馈一致**：列表加载用骨架屏，空态用 `AppEmptyState`，分页失败保留原列表并提供重试，轻量操作用 toast。

## 测试

- 修改主题 token → 检查 `test/theme/`
- 修改壳层/导航/页面行为 → 检查 `test/widgets/`、`test/features/`、`test/routes/`
- 修改 API → 检查对应 `test/features/*/`

## 后端项目

后端 FastAPI 项目路径：`~/Documents/Code/MyCode/SakuraMediaBE`。除非当前仓库缺少上下文，否则优先从本仓库代码推断约束。

## 文档维护

- 功能已实现但文档未同步时，优先补文档
- 新增共享组件或设计 token 后，同步更新 `docs/ui-spec.md`
- 占位/骨架能力必须在文档中明确标注，不能描述为"已完整支持"
