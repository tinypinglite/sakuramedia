# CLAUDE.md

本文件为 Claude Code 提供仓库级指引。

> **本项目超大(~88k 行 / 26 个 feature),采用分层 CLAUDE.md。**
> 本文件只放**全局必读**规则;模块级细节写在各子目录的 `CLAUDE.md`,Claude Code 会在你**读写该目录下文件时自动加载**——所以你不必把所有约定都塞进本文件,改某个模块时去读它自己的 `CLAUDE.md`。导航见下方「分层文档」。

## 项目概述

SakuraMedia 是基于 Flutter 的 Jav 观影平台前端,面向 NAS 用户,覆盖影片发现、订阅、下载、播放与信息翻译。**桌面端是一等公民**;移动端覆盖部分核心页面(且**多数移动页直接复用桌面页**,仅换布局/控件),Web 端复用桌面路由、原生能力受限。

## 常用命令

```bash
flutter pub get                                          # 获取依赖
flutter run -d macos                                     # 运行桌面端(macOS)
flutter run -d chrome                                    # 运行 Web
flutter run -d android                                   # 运行 Android
flutter test                                             # 运行全部测试
flutter test test/features/movies/movies_api_test.dart   # 运行单个测试文件
flutter analyze                                          # 静态分析
dart run build_runner build --delete-conflicting-outputs # 路由代码生成(改路由定义后必跑)
cd wiki && npm run docs:dev                              # 本地查看 Wiki 文档
```

## 技术栈

- Flutter + Dart (SDK ^3.7.2)
- `go_router` + `go_router_builder`:类型安全路由,定义在 `lib/routes/`,生成代码为 `*.g.dart`
- `provider`:依赖注入与局部状态管理(`ChangeNotifier`)
- `dio`:HTTP,封装为 `ApiClient`(`lib/core/network/api_client.dart`)
- `media_kit`:视频播放 · `window_manager`:桌面窗口 · `shared_preferences` / `flutter_secure_storage`:会话与凭据持久化

## 顶层目录(各目录细则见其自身的 CLAUDE.md)

- `lib/app/`:启动入口(`main.dart` → `bootstrapApplication()` → `MyApp`)、平台判定、**全局 Provider 装配**、页面状态缓存
- `lib/core/`:基础能力——`network/`(ApiClient + token 自动刷新 + SSE)、`session/`、`media/`(URL/图片保存)、`format/`、`json/`
- `lib/features/`:按业务域组织,统一 `data/`(`*_api.dart` + `*_dto.dart`) + `presentation/`(页面 + 控制器 + 状态)模式
- `lib/routes/`:路由定义、平台选择、登录守卫、导航数据、跳转扩展方法
- `lib/widgets/`:共享组件——`app_shell/`(壳层)、`forms/`、`feedback/`,及各业务域展示组件
- `lib/theme/` + `lib/theme.dart`:设计系统 token 体系(桌面/移动各有配置)
- `lib/config/`:应用级配置(图片缓存/模糊)
- `test/`:**镜像 `lib/` 结构**的测试目录

## 分层文档(改对应模块前先读它的 CLAUDE.md)

| 文档 | 覆盖范围 |
|---|---|
| `lib/app/CLAUDE.md` | bootstrap 顺序、**Provider 注册顺序与依赖链**、页面状态缓存 |
| `lib/core/CLAUDE.md` | ApiClient/动词/SSE、**AuthInterceptor token 刷新(三处联动)**、Session/Credential、URL 解析、json 容错 |
| `lib/routes/CLAUDE.md` | typed route 范式、**改路由必跑 build_runner**、query 参数双命名、顶栏/返回机制、登录守卫 |
| `lib/theme/CLAUDE.md` | token 体系、`context.appXxx` 取值、**theme_source_guard 硬守卫(禁裸值)**、加 token 的全家桶改动 |
| `lib/widgets/CLAUDE.md` | 展示组件 vs 控制器边界、共享组件清单、图片三大组件、**Widget Key 约定**、copy-paste 重复实现警告 |
| `lib/features/CLAUDE.md` | feature 通用范式:`PagedLoadController`、筛选状态驱动、**mutation 跨页同步**、SSE 消费、乐观更新、各域地图 |
| `lib/features/movies/CLAUDE.md` | 最复杂域:筛选 reload、详情页两端重复、检查器子控制器、订阅/合集双 notifier |
| `lib/features/configuration/CLAUDE.md` | 设置页:桌面聚合 vs 移动独立页、active 懒加载、IndexedStack 索引耦合、跨 feature 配置 |
| `lib/features/activity/CLAUDE.md` | 通知中心:双 SSE、无感自动已读、全局 vs 页面级控制器 |

## 全局铁律(跨模块,务必遵守)

1. **以代码为准**:文档与代码冲突时以代码为准(尤其 `lib/theme.dart`、`lib/widgets/`、`lib/features/**/presentation/`),并同步更新文档。
2. **桌面端优先**:布局/导航复用桌面壳层(`AppDesktopShell`/`AppSidebar`/`AppTopBar`),不假设移动端/Web 有完整页面;多数移动页是桌面页的薄包装。
3. **设计系统优先**:颜色/间距/圆角/阴影/尺寸**一律走 `context.appXxx` token**,文字用 `resolveAppTextStyle`/`AppText`,**禁止散落裸值**(有专门测试守卫会拦截)。优先用共享组件(`AppButton`/`AppTextField`/`AppSelectField`/`AppTabBar`/`AppEmptyState`/`AppContentCard`/`AppSettingsGroup`/`showAppConfirmDialog` 等)。
4. **遵循 feature 组织方式**:新增功能沿用 `data/*_api.dart` + `data/*_dto.dart` + `presentation/*controller.dart` / 页面 State。DTO 用 `core/json/json_parse.dart` 容错解析,**`fromJson` 永不抛异常**(字段 `?? 默认值`)。
5. **状态反馈一致**:列表加载用骨架屏,空态用 `AppEmptyState`,**分页失败保留原列表并提供重试**,轻量操作用 toast(`oktoast`),错误文案统一走 `apiErrorMessage(error, fallback: ...)`。
6. **Provider 注册**:新增 API/全局 `ChangeNotifier` 必须在 `lib/app/app.dart` 的 providers 列表注册,**且排在它依赖的 Provider 之后**(顺序敏感,详见 `lib/app/CLAUDE.md`)。
7. **改路由定义必跑 build_runner**:任何对 typed route 的增删改后执行 `dart run build_runner build --delete-conflicting-outputs`,否则 `*.g.dart` 不更新、编译失败。
8. **跨页状态一致**:改订阅/合集/删除等会影响其它页面的状态时,通过全局 mutation `ChangeNotifier`(如 `MovieSubscriptionChangeNotifier`)广播,监听方就地补丁,不整页刷新。

## Git 约定

- **未经用户明确允许,不要创建新分支**:默认直接在当前分支提交,即使当前是 `main`/默认分支。需要分支时先征求同意。

## 测试

- 测试目录**镜像 `lib/` 结构**;改任何代码先找对应 `test/` 路径。
- 改主题 token → `test/theme/`(含 `theme_source_guard_test.dart` 硬守卫,引入裸视觉值会红)
- 改壳层/导航/页面 → `test/widgets/`、`test/features/`、`test/routes/`
- 改 API → 对应 `test/features/*/data/`;改控制器 → `test/features/*/presentation/`
- 组件/页面大量用稳定 `Key('...')` 作测试锚点,**改/删 Key 会破测试**。

## 后端项目

后端 FastAPI 项目路径:`~/Documents/Code/MyCode/SakuraMediaBE`。除非当前仓库缺少上下文,否则优先从本仓库代码推断约束。

## 文档维护

- 功能已实现但文档未同步时,优先补文档。
- 新增共享组件或设计 token 后,同步更新 `docs/ui-spec.md`(87KB 大文档,**只在需要时按需阅读,不要整篇载入上下文**)。
- 占位/骨架能力必须明确标注,不能描述为"已完整支持"。
- 注:根目录 `AGENTS.md` 被 gitignore,是给其它工具的本地副本,**非追踪文档**;权威文档是本 `CLAUDE.md` 及各模块 `CLAUDE.md`。
