# SakuraMedia Riverpod 渐进引入与全面迁移方案

**方案日期**：2026-07-16

**状态**：R0 / R1 已落地，LLM 设置已完成 Riverpod 与双端单页面收敛

**首个试点**：LLM 设置

**关联文档**：

- `docs/dual-platform-code-audit.md`

## 1. 决策摘要

SakuraMedia 将渐进式引入 Riverpod，在过渡期保留现有 Provider / ChangeNotifier 代码，并按 feature 逐个迁移；最终目标是删除 Provider 状态管理与依赖注入体系，让 Riverpod 成为应用唯一的状态与依赖组合框架。

本次决策不是全量重写，也不是为了追随状态管理框架热度。引入 Riverpod 的直接目标是：

1. 让页面不再手工创建、销毁业务 Controller。
2. 用统一异步状态替代重复的 loading / error / data 布尔字段和 `try/catch/finally`。
3. 让业务状态和依赖组合脱离 `BuildContext`。
4. 让 Desktop / Mobile 入口复用同一个业务页面和单一状态来源。
5. 降低 Controller、页面测试和 Provider tree 测试夹具的重复量。

“完全迁移”允许按需要修改 API、DTO、Router、PageStateCache、Session、主题接缝和共享 Widget。Riverpod 不直接取代 DTO、Router 或 Widget 的职责，但迁移可以重构它们的接口、依赖方向和状态接入方式，以形成完整的 Riverpod 架构。

第一阶段不引入 Bloc 或 Cubit。LLM 设置作为项目的完整 Riverpod 基准示例，首批同时引入 Riverpod 代码生成和 Flutter Hooks：Provider / Notifier 使用 `riverpod_annotation` + `riverpod_generator` 声明，表单宿主使用 `flutter_hooks` + `hooks_riverpod` 管理 View 生命周期。试点结论不再决定“是否最终迁移”或“是否启用代码生成”，只用于验证迁移范式、边界和后续推进节奏。

## 2. 当前基线

当前状态管理与依赖注入主要使用：

- `provider: ^6.1.2`
- `ChangeNotifier`
- `ChangeNotifierProvider` / `Provider` / `ProxyProvider`
- `context.read/watch/select`
- `AnimatedBuilder`
- 页面 State 手工创建和释放局部 Controller

当前生产代码中可观察到：

| 指标 | 当前值 |
|---|---:|
| 导入 `package:provider/provider.dart` 的生产文件 | 112 |
| `context.read/watch/select` 调用 | 约 396 |
| 直接继承或混入 `ChangeNotifier` 的状态类 | 约 45 |
| `AnimatedBuilder` 调用 | 约 61 |
| ViewModel-like 状态与业务编排代码 | 约 11,133 行 |

Provider 本身仍然可靠，当前问题主要来自使用边界：

- 页面承担 Controller 生命周期和部分业务状态。
- 多数异步 Controller 手工维护 loading、error、data、saving、testing 等状态。
- mutation feedback 和 toast 混入 Controller。
- `TextEditingController`、`GlobalKey<FormState>` 等 View 对象进入业务 Controller。
- Desktop / Mobile 页面可能分别创建同一业务的 Controller。
- 全局 `MultiProvider` 集中装配所有 API 与状态，组合根持续增长。

Riverpod 首先用于改善这些边界，后续也会进入 API/service 装配、全局会话、缓存、Router 刷新依赖等应用基础设施。API、DTO、Router、主题接缝和共享 Widget 均允许在迁移中修改；是否修改取决于能否改善单向依赖、状态所有权、测试或代码量，而不是为了框架形式统一机械重写。

## 3. 为什么选择 Riverpod

### 3.1 与当前代码形态接近

现有 Controller 主要是方法驱动的 `ChangeNotifier`，与 Riverpod `Notifier` / `AsyncNotifier` 的迁移距离比完整 Bloc Event / State 模型更短。

典型映射：

| 当前实现 | Riverpod 目标 |
|---|---|
| `Provider<Api>` | 普通 `Provider<Api>` 或组合根 override |
| 同步 ChangeNotifier | `Notifier<State>` |
| 异步加载 Controller | `AsyncNotifier<State>` |
| 带业务参数的详情 Controller | 参数化 Notifier / family |
| 页面内 `initState + load` | Notifier `build()` |
| `isLoading + errorMessage + data` | `AsyncValue<State>` |
| 页面 `dispose controller` | Provider 生命周期 / auto-dispose |
| mutation notifier 广播 | 明确的 Notifier 状态或 provider invalidation |
| Provider test override | `ProviderContainer` / `ProviderScope` override |

### 3.2 更匹配当前业务类型

项目的主要状态形态是：

- 列表、筛选、分页、刷新
- 详情加载和按 ID 缓存
- 表单加载、测试、保存和失败保留草稿
- mutation 后同步其它页面
- SSE / 任务进度与通知

其中大部分是异步数据与 CRUD 状态，适合使用 `AsyncNotifier` 和不可变 State。Riverpod 原生提供 loading / error / data 表达、依赖组合、参数化状态和 override 测试能力。

### 3.3 渐进共存成本可控

Riverpod 可以与 Provider 同时存在。迁移单位可以是单个 feature，而不是应用整体：

- 未迁移 feature 继续使用 Provider / ChangeNotifier。
- 已迁移 feature 只使用 Riverpod。
- API、DTO、Widget 和路由不要求与首个状态试点同步重写，但允许在对应迁移阶段调整接口和依赖方向。
- 失败时可以删除单一试点和 Riverpod 根接缝，不影响其它 feature。

### 3.4 为什么不选择全量 Bloc

Bloc / Cubit 仍可用于事件密集模块，但不作为本项目的全局迁移目标：

- 普通列表、详情和表单使用完整 Event / State / Bloc 容易增加样板代码。
- `flutter_bloc` 的依赖提供通常仍围绕 Widget tree 和 `BuildContext`。
- 将约 45 个现有 Controller 全部转换为 Bloc，迁移面大于 Riverpod。
- Bloc 不能自动解决双端页面、双路由和跨 feature 依赖。

如果未来 Activity、Downloads、SSE 搜索或播放器出现复杂事件并发需求，可以单独评估 Bloc；同一阶段不得同时引入两套新状态框架。

## 4. 目标与非目标

### 4.1 目标

- 每个已迁移业务只有一个状态所有者。
- Desktop / Mobile / Web 共享同一业务 Notifier 和 State 类型。
- Notifier 不依赖 `BuildContext`、Widget、路由类或 UI Controller。
- 初次加载使用 `AsyncValue` 表达 loading / error / data。
- 保存、测试、删除等 mutation 有明确且可测试的进行中状态。
- 页面只负责布局、表单宿主、事件转发和一次性 UI feedback。
- Provider 与 Riverpod 共存期间没有重复 API client、SessionStore 或 SSE 连接。
- 已迁移 feature 可以使用纯 Dart 风格的 `ProviderContainer` 测试状态转换。
- Provider / Notifier 默认采用 `@riverpod` 代码生成语法，形成可复制的统一声明方式。
- 表单等确有局部生命周期样板代码的页面允许使用 Hooks，但 Hooks 不承担业务状态所有权。
- 所有业务 feature 迁移后，将 API/service、Session、全局缓存和 Router 依赖迁入 Riverpod 组合根。
- 最终删除 `MultiProvider`、`context.read/watch/select` 的生产调用和 `provider` 依赖。

### 4.2 非目标

- 不一次性迁移全部 Provider。
- 不立即删除 `provider` 依赖；它只作为过渡期兼容层存在。
- 不无条件改写每个 DTO、HTTP API 或后端协议；允许为单向依赖、不可变状态、请求参数和测试边界修改 API / DTO。
- 不因引入 Riverpod 同时增加 Repository、UseCase、Entity、Mapper 全套层级。
- 不要求所有 Widget 改写为 HookWidget；仅在输入控制器、FocusNode、动画或副作用生命周期能明显受益时使用 Hooks。
- 不把 `TextEditingController`、`AnimationController`、FocusNode、GlobalKey 放入 Notifier。
- 不用 Riverpod legacy `ChangeNotifierProvider` 包装旧 Controller 作为长期方案。
- 不把 Router、SessionStore 和全局 SSE 作为首批迁移对象。

## 5. 依赖与兼容性

当前 `pubspec.yaml`：

- Dart SDK：`^3.7.2`
- Provider：`^6.1.2`
- build_runner：`^2.4.15`
- go_router_builder：`^4.1.1`

实际落地依赖如下：

```yaml
dependencies:
  flutter_riverpod: 3.1.0
  hooks_riverpod: 3.1.0
  flutter_hooks: ^0.21.2
  riverpod_annotation: 4.0.0

dev_dependencies:
  # 项目已存在，继续与 go_router_builder 共用。
  build_runner: ^2.4.15
  riverpod_generator: 4.0.0+1
```

方案初稿中的 Riverpod 3.3.2 / Generator 4.0.4 / Hooks 0.21.3+1 需要更新的 Dart / Flutter SDK：Generator 4.0.4 的 analyzer 依赖要求 Dart 3.9，Hooks 0.21.3 要求 Flutter 3.32。当前仓库实际为 Dart 3.7.2 / Flutter 3.29.3，因此锁定到上述同代兼容版本；未为单一 feature 试点扩大 Flutter SDK 升级范围。

四个新增能力的职责边界：

| 依赖 | 职责 | LLM 基准示例中的用途 |
|---|---|---|
| `riverpod_annotation` | 提供 `@riverpod` / `@Riverpod` 注解 | 声明 API provider 和 LLM Notifier |
| `riverpod_generator` | 通过 build_runner 生成 provider 与 Ref 相关代码 | 生成 `*.g.dart`，统一后续 feature 声明范式 |
| `flutter_hooks` | 管理 Widget 局部对象和生命周期 | 管理表单控制器、FocusNode、Form key 与必要副作用 |
| `hooks_riverpod` | 在同一 Widget 中组合 Hooks 与 Riverpod | 使用 `HookConsumerWidget`、`ref.watch`、`ref.listen` |

这里的“最小示例”指项目最终技术栈的最小完整示例，而不是 Riverpod 能运行的绝对最小依赖。若只验证 Riverpod 是否能运行，`flutter_riverpod` 已足够；但该验证不能作为后续约 45 个业务状态类的迁移模板，因此 LLM 基准示例必须覆盖代码生成和 Hooks 的正确边界。

`hooks_riverpod` 虽然依赖 `flutter_riverpod` 和 `flutter_hooks`，但生产代码会直接 import 后两者时，应继续将它们声明为直接依赖。首批不为了 Riverpod 单独引入 `custom_lint`；`riverpod_lint` 作为开发期质量工具单独评估和配置，不影响完整示例的运行时架构。

版本和 API 参考：

- [flutter_riverpod package](https://pub.dev/packages/flutter_riverpod)
- [Riverpod 官方文档](https://riverpod.dev/)
- [从 ChangeNotifier 迁移](https://riverpod.dev/docs/migration/from_change_notifier)
- [Riverpod 代码生成说明](https://riverpod.dev/docs/concepts/about_code_generation)
- [riverpod_annotation package](https://pub.dev/packages/riverpod_annotation)
- [riverpod_generator package](https://pub.dev/packages/riverpod_generator)
- [flutter_hooks package](https://pub.dev/packages/flutter_hooks)
- [hooks_riverpod package](https://pub.dev/packages/hooks_riverpod)

## 6. Provider 与 Riverpod 共存架构

### 6.1 组合根接缝

现有 API、Session 和 SSE client 由 `lib/app/app.dart` 中的 `MultiProvider` 创建。Riverpod Notifier 不能直接读取 Provider 的 `BuildContext`，也不允许为了迁移复制一套 `ApiClient`。

过渡期采用“只在 Composition Root 桥接”的方式：

```text
MultiProvider
  ├─ SessionStore / ApiClient / FeatureApi / existing notifiers
  └─ Builder（读取现有 Provider 实例）
      └─ ProviderScope
          ├─ overrides：把现有 service / API 注入 Riverpod
          └─ OKToast / MaterialApp.router / feature pages
```

Riverpod 侧为需要桥接的服务定义占位 provider：

```dart
final llmSettingsApiProvider =
    Provider<MovieDescTranslationSettingsApi>((ref) {
  throw UnimplementedError('Override at the app composition root');
});
```

组合根从现有 Provider 读取唯一实例并 override：

```dart
ProviderScope(
  overrides: [
    llmSettingsApiProvider.overrideWithValue(
      context.read<MovieDescTranslationSettingsApi>(),
    ),
  ],
  child: const AppContent(),
)
```

以上代码只表示目标接缝，具体落地必须适配当前 `MyApp` 结构和测试 harness。

### 6.2 桥接规则

1. 兼容桥只能存在于 `app/` 组合根和测试根。
2. Feature 内的 Riverpod provider 不允许调用 `Provider.of` 或保存 `BuildContext`。
3. 不创建第二个 `ApiClient`、SessionStore、CredentialStore 或 SSE client。
4. 每迁移一个 service 到 Riverpod 原生装配，就删除对应 override。
5. 全部 feature 迁移完成前，ProviderScope 可以嵌套在 MultiProvider 内；该结构是有删除条件的过渡架构，不是最终形态。
6. 不建立 Provider ↔ Riverpod 双向同步工具。

### 6.3 单一状态所有者

允许不同 feature 分别使用不同框架，但同一业务状态只能由一个框架拥有：

```text
允许：
Movies -> Provider
LLM Settings -> Riverpod

禁止：
LLM ChangeNotifier <-> Riverpod Notifier 双向同步
同一页面同时监听两份 LLM draft
Provider mutation notifier 和 Riverpod invalidation 同时广播同一事件
```

迁移一个 feature 时，旧 Controller 必须在同一迁移中退出生产调用；不能为了“渐进”长期保留双状态源。

## 7. Riverpod 代码组织约定

建议新增 feature 内目录：

```text
lib/features/<feature>/
├── data/
└── presentation/
    ├── controllers/       # 尚未迁移的 ChangeNotifier Controller
    ├── providers/         # Riverpod provider / notifier / state
    ├── pages/
    └── widgets/
```

首个试点建议文件：

```text
lib/features/configuration/presentation/providers/
├── llm_settings_provider.dart
├── llm_settings_provider.g.dart
└── llm_settings_state.dart

lib/features/configuration/presentation/widgets/shared/
└── llm_settings_form_host.dart  # HookConsumerWidget，持有 View 生命周期对象
```

约束：

- Provider 声明、Notifier 和 State 可以按规模拆分，不建立全局 `providers.dart`。
- Provider / Notifier 默认使用 `@riverpod` 声明；生成的 `*.g.dart` 纳入统一生成流程且禁止手工修改。
- State 使用不可变值类型和 `copyWith`；首批不为此额外引入 Freezed。
- Notifier 方法使用业务动词，例如 `reload`、`updateDraft`、`save`、`runConnectionTest`。
- Provider 名称表达业务语义，不包含 `desktop`、`mobile`、`web`。
- Provider 不能导入具体页面、Dialog、Drawer、route data 或 theme。
- 一次性 toast、Dialog、导航由 UI 通过返回值或 `ref.listen` 处理。
- `TextEditingController`、FocusNode、Form key 和滚动 Controller 属于 View 生命周期。
- Hooks 只负责上述 View 生命周期和局部副作用；可跨页面、参与保存或需要测试的草稿必须进入 Notifier State。

## 8. 状态设计规范

### 8.1 初次异步加载

使用 `AsyncNotifier<State>`：

```text
AsyncLoading -> AsyncData<State>
             -> AsyncError
```

不要在 State 中重复添加 `isInitialLoading` 和 `initialErrorMessage`，除非业务确实需要“保留旧数据时刷新失败”的独立语义。

### 8.2 Mutation 状态

保存、测试、删除、重排等 mutation 可以保存在业务 State 中：

```text
LlmSettingsState
├── saved
├── draft
├── isSaving
├── isTesting
└── testResult
```

mutation 不应把整个 provider 切换为 `AsyncLoading` 并清空已展示内容。

### 8.3 草稿与持久化状态

表单必须区分：

- `saved`：后端最后确认的设置。
- `draft`：用户当前编辑值。
- `isDirty`：draft 是否与 saved 不同。

保存失败必须保留 draft；测试配置使用 draft，不应隐式保存。

### 8.4 页面参数状态

详情、搜索和合集等按参数创建状态：

- `movieNumber`
- `actorId`
- `collectionId`
- canonical search query

参数必须使用业务标识，不得包含 Desktop / Mobile 路径前缀。

### 8.5 生命周期与缓存

不能把所有 provider 默认设为 auto-dispose，也不能全部永久 keep-alive：

- 临时 Dialog、选图草稿、一次性子页面可以 auto-dispose。
- 需要跨 tab / resize 保持的列表、筛选、分页状态必须明确 keep-alive 策略。
- 状态生命周期应与 canonical route / shell branch 语义一致。
- Provider identity 替代旧平台 cache key 时，必须验证旧 URL、canonical URL 和 resize 不产生第二份状态。

## 9. 首个试点：LLM 设置

### 9.1 选择原因

LLM 设置具备足够代表性，同时业务边界较小：

- Desktop 与 Mobile 已共享 `LlmSettingsController`。
- 包含初次加载、刷新、校验、测试、保存和失败反馈。
- 有共享字段组件和较完整的双端测试。
- 不涉及分页、播放器、SSE 或复杂跨 feature mutation。
- 失败时容易回滚，不影响核心影片浏览和播放。

当前相关生产代码基线：

| 文件 | 物理行数 |
|---|---:|
| `llm_settings_controller.dart` | 245 |
| `desktop_llm_settings_section.dart` | 315 |
| `mobile_llm_settings_page.dart` | 303 |
| `llm_settings_form_fields.dart` | 95 |
| `llm_settings_copy.dart` | 12 |
| **合计** | **970** |

迁移后手写生产代码：

| 文件 | 物理行数 |
|---|---:|
| `llm_settings_page.dart` | 468 |
| `llm_settings_state.dart` | 165 |
| `llm_settings_provider.dart` | 166 |
| `llm_settings_copy.dart` | 12 |
| **手写合计** | **811** |
| `llm_settings_provider.g.dart`（生成） | 104 |
| **含生成代码合计** | **915** |

手写生产代码相对 970 行基线减少 159 行（约 16.4%）；即使计入 104 行生成代码，总量仍减少 55 行（约 5.7%）。旧 Controller、双端页面和旧字段胶水组件均已删除。

### 9.2 当前问题

现有 `LlmSettingsController` 同时持有：

- `ChangeNotifier` 状态通知
- `MovieDescTranslationSettingsApi`
- `GlobalKey<FormState>`
- 五个 `TextEditingController`
- loading / saving / testing / error 状态
- 表单校验开关
- toast feedback
- disposed 防护

它已经共享业务逻辑，但混合了 View 生命周期、业务状态和一次性 UI feedback。两端页面仍分别创建、load、监听和 dispose Controller。

### 9.3 目标拆分

```text
LlmSettingsNotifier（纯业务状态）
├── load / reload
├── updateDraft
├── save
└── runConnectionTest

LlmSettingsState（不可变）
├── saved settings
├── draft values
├── isSaving
├── isTesting
├── validation intent
└── test result

Shared form host（HookConsumerWidget）
├── Form key
├── TextEditingController
├── FocusNode
├── useEffect 等必要的 View 同步
└── 把字段变化转发给 Notifier，不能成为第二份业务草稿

LlmSettingsPage（唯一页面）
├── Desktop 配置区通过 active 参数保持懒加载
├── Mobile 设置路由直接使用默认 active=true
├── ref.watch 显示状态
└── action result 触发一次性 toast
```

Notifier 内不得 import Flutter Material、oktoast、具体页面或 `provider`。

### 9.4 试点步骤

#### 步骤 A：基础接入

1. 添加 `flutter_riverpod`、`riverpod_annotation`、`riverpod_generator`、`flutter_hooks` 和 `hooks_riverpod` 依赖。
2. 在现有 MultiProvider 内接入 ProviderScope。
3. 将 Riverpod generator 接入项目已有 build_runner 流程，确认 go_router 与 Riverpod 生成任务可共同执行。
4. 使用 `@riverpod` 建立 LLM API bridge provider。
5. 为测试 harness 增加 ProviderScope override helper。
6. 保证尚未迁移页面呈现和测试不变化。

#### 步骤 B：纯状态实现

1. 新增不可变 `LlmSettingsState` 和 draft value。
2. 使用 `@riverpod class LlmSettings extends _$LlmSettings` 新增生成式 AsyncNotifier。
3. 将 load、reload、save、test 和 payload 构造迁入 Notifier。
4. 保留纯校验函数，但移除 Form key、TextEditingController 和 toast。
5. 增加 `ProviderContainer` 单元测试。

#### 步骤 C：页面切换

1. 建立唯一 `LlmSettingsPage`，Desktop 配置区和 Mobile 设置路由直接复用，不保留平台薄壳。
2. 页面内建立 `HookConsumerWidget` 表单宿主，用 Hooks 持有 TextEditingController、FocusNode 和 Form key。
3. 把一次性反馈改为明确 action result，由页面统一显示 toast。
4. 保持文案、loading/error/content、下拉刷新和 Desktop lazy-load 行为。
5. Widget key 统一为 `llm-*`，测试和路由锚点同步收敛，不再维护两套 key 前缀。
6. 同一迁移中删除旧 Controller、双端页面和旧字段组件。

#### 步骤 D：收尾

1. 删除旧 Controller。
2. 更新共享表单字段接口。
3. 合并重复测试 fixture。
4. 记录迁移前后生产代码和测试代码行数。
5. 运行完整配置相关测试和全量测试。

### 9.5 必须保留的行为

- Desktop section 仅在 active 时懒加载。
- Mobile 页面进入时加载并支持下拉刷新。
- 初次加载失败显示错误态并可重试。
- 保存前校验 URL、模型、请求超时和连接超时。
- 保存成功应用后端返回状态。
- 保存失败保留用户草稿。
- 测试使用当前草稿，不触发保存。
- 修改草稿后清除旧测试结果。
- 保存和测试互斥，按钮 loading 和 disabled 状态正确。
- Desktop / Mobile 文案保持一致；Widget key 在本次双端单页面收敛中明确统一为 `llm-*`。
- Provider dispose 后不更新状态，不出现 mounted/disposed 异常。

## 10. 测试策略

### 10.1 Notifier 单元测试

至少覆盖：

- build 加载成功
- build 加载失败
- retry 成功
- draft 更新与 dirty 判断
- payload 映射
- 校验失败不请求 API
- save 成功应用返回值
- save 失败保留 draft
- test 成功 / 返回 false / 抛错
- 测试与保存互斥
- 修改 draft 清除旧测试结果
- provider dispose 后的异步完成安全

### 10.2 Widget 测试

页面行为测试收敛为单一页面覆盖：

- fake API / provider override
- pump helper
- 常用字段输入 helper
- loading/error/data fixture

Widget 测试继续验证布局、Key、按钮和用户反馈；API 状态转换细节由 Notifier 单元测试覆盖。Desktop 配置测试只保留 active 懒加载接入，Mobile 路由测试只保留真实页面接入，不再重复保存、测试、校验和错误分支。

### 10.3 回归范围

试点至少运行：

- LLM Notifier 单元测试
- `llm_settings_page_test.dart`
- `llm_settings_provider_test.dart`
- `desktop_configuration_page_test.dart` 中的 LLM 懒加载接入用例
- configuration API test
- ProviderScope / app bootstrap 相关测试
- `flutter analyze`
- 全量 `flutter test`

### 10.4 落地验证记录

- Riverpod 与 go_router 生成器已通过同一套 build_runner 流程成功执行。
- LLM Notifier、唯一页面、Desktop 懒加载接入和 Mobile 路由接入专项测试已通过。
- 全量 `flutter test` 共 1642 项全部通过。
- `flutter analyze` 保持仓库原有 74 条存量提示，本次迁移没有新增分析问题。

## 11. 量化验收门槛

试点只有同时满足以下条件才允许扩大：

### 11.1 架构门槛

- LLM 生产路径中不再引用旧 `LlmSettingsController`。
- LLM Notifier 不依赖 BuildContext、Widget、TextEditingController、GlobalKey 或 oktoast。
- Desktop / Mobile 使用同一 `LlmSettingsPage`、State 和 Notifier 类型。
- LLM API 只有一个运行时实例。
- 兼容 bridge 只存在于组合根和测试根。
- 同一状态没有 Provider / Riverpod 双写。

### 11.2 行为门槛

- 第 9.5 节列出的行为全部通过自动化测试。
- resize 和 Desktop / Mobile 页面切换不产生重复请求。
- 保存失败、测试失败和刷新失败不会清空用户草稿。
- 没有新增未捕获异步异常、disposed 更新或重复 toast。

### 11.3 代码量门槛

- 已记录 970 行基线、811 行迁移后手写代码和 915 行含生成代码数值。
- 不要求 State 类型零成本，但迁移后相关生产代码不应显著增长。
- 如果生产代码增长超过 10%，必须说明新增能力和长期删除计划。
- 业务状态测试可以增加，但 Desktop / Mobile 重复 fixture 应减少。
- Provider / Riverpod 桥接样板不得复制到每个 feature。

### 11.4 可维护性门槛

- 新开发者可以从单一 feature 目录找到 State、Notifier 和 provider。
- API override 测试不需要完整 MaterialApp 或 MultiProvider。
- Notifier 状态转换可在纯 ProviderContainer 测试中验证。
- 页面代码主要剩下布局、监听和事件转发。

## 12. 扩大与停止条件

### 12.1 扩大条件

LLM 试点通过后，业务 feature 按自身边界逐个迁移；同时必须维护 Riverpod 全面迁移清单，避免未迁移的 Provider 长期成为遗留孤岛。页面是否双端共用需按 feature 单独判断；LLM 因两端可接受同一布局而收敛为单页面，不代表引入响应式 UI 基础设施。

建议原则：

1. 优先迁移双端重复且异步状态明显的 feature。
2. 每次只迁移一个 feature。
3. 完成旧 Controller 删除后才能开始下一个。
4. 每个 feature 重新评估 auto-dispose / keep-alive，而不是复制模板。
5. 所有业务 feature 状态迁移后，进入 Session、Router、全局 PageStateCache、API/service 装配和 SSE 根连接迁移阶段。

### 12.2 暂停条件

出现以下任一情况应暂停扩大：

- LLM 相关生产代码显著增加且没有明确收益。
- 测试必须同时维护 Provider 和 Riverpod 两套复杂 harness。
- ProviderScope bridge 扩散到 feature 内部。
- 同一 API 或 Session 被创建两次。
- 页面仍然持有大量业务状态，只是把 `notifyListeners` 换成 `ref.watch`。
- 团队无法形成一致的 State、Notifier 和生命周期规范。
- Riverpod 迁移干扰现有 Router、双端 UI 行为或平台能力验收。

### 12.3 回滚条件

如果试点不通过：

1. 恢复 LLM 页面使用现有共享 Controller。
2. 删除 LLM Riverpod providers 和测试。
3. 删除 ProviderScope bridge。
4. 如果没有其它消费者，移除 `flutter_riverpod` 依赖。
5. 保留试点评估记录，但不保留双状态源。

## 13. 全面迁移阶段与允许修改范围

### 13.1 最终目标架构

最终应用组合根应收敛为：

```text
ProviderScope
  ├── Session / Credential / ApiClient providers
  ├── FeatureApi / Store / SSE providers
  ├── Router / app lifecycle providers
  └── MaterialApp.router
      └── Feature pages
          └── Notifier / AsyncNotifier providers
```

最终生产代码中：

- 不再使用 `MultiProvider`、`ChangeNotifierProvider` 或 `ProxyProvider`。
- 不再通过 `context.read/watch/select` 获取业务依赖或状态。
- 不再以 `ChangeNotifier` 作为应用或 feature 业务状态容器。
- `provider` 从 `pubspec.yaml` 删除。
- Riverpod 成为 API/service 装配、状态管理、生命周期和测试 override 的唯一框架。

Flutter SDK 自身的 `ChangeNotifier` / `ValueNotifier` 仍可在纯 UI 或第三方组件适配中保留，例如动画、播放器或 Router adapter；它们不得重新承担业务状态容器职责。

### 13.2 API 与 service

API 类允许并计划逐步修改：

- 每个 API / Store / client 由 Riverpod provider 创建或从上游 provider 组合。
- `ApiClient`、Session 和 SSE client 必须保持单实例语义。
- API 不再依赖 presentation 类型。
- 当前 `MoviesApi -> MovieFilterState`、`ActorsApi -> ActorFilterState` 的反向依赖必须拆除。
- 可以新增 data-neutral request/query DTO，让 presentation state 映射为请求参数。
- API 太大时允许按读取、mutation、stream 能力拆分，但不为每个 endpoint 建立无意义类。
- 可以为测试注入函数、接口或 fake 实现；不强制所有 API 增加 Repository 包装层。

过渡期的 API override bridge 在 API 原生 Riverpod 装配完成后删除。

### 13.3 DTO 与状态模型

DTO 允许修改、拆分或移动，但 Riverpod 不直接替代 DTO：

- Transport DTO 继续负责后端 JSON 映射。
- Riverpod State 负责界面和业务状态，不把 loading、saving、selection 等字段塞入 transport DTO。
- presentation filter 中实际属于 API 协议的枚举或 query object 移入 data-neutral 位置。
- DTO 如果同时承担 transport、领域计算和表单草稿三种职责，应拆分为明确模型。
- State 优先不可变；DTO 是否不可变按数据语义决定。
- 不为形式统一复制一套与后端 DTO 完全相同的 Domain Entity。

### 13.4 Router、Session 与缓存

Router 和全局状态属于全面迁移范围：

- canonical `GoRouter` 可以由 Riverpod provider 构建和持有。
- 登录态、Session 更新和 redirect 刷新通过明确 adapter 连接，不能因 provider 重建而重新创建 Router。
- Router location 和业务参数继续是状态恢复的外部真相，不把可分享 URL 状态只存进内存 provider。
- `AppPageStateCache` 可以被 Riverpod family / keep-alive 生命周期逐步替代；无法替代的 LRU 行为可以作为 Riverpod 管理的 service 保留。
- Desktop / Mobile cache key 必须迁移为 canonical 业务 identity。
- SSE 和下载任务 provider 必须有明确创建、订阅、取消和 Session 切换测试。

### 13.5 主题与共享 Widget

主题和 Widget 允许修改，但不要求所有 UI 都直接依赖 Riverpod：

- 静态 ThemeData、token 和纯展示 Widget 继续保持普通 Dart / Flutter 组件。
- 需要消费业务状态的页面或容器可以使用 `ConsumerWidget` / `ConsumerStatefulWidget`；同时存在适合 Hooks 管理的 View 生命周期时使用 `HookConsumerWidget`。
- 基础按钮、卡片、表单字段不应为了“全面 Riverpod”接收 `WidgetRef`。
- 共享领域 Widget 优先接收值和回调，状态所有权留在 feature provider。
- ThemeMode、用户偏好等真实应用状态可以由 Riverpod 管理，再投影到 ThemeData。

“完全引入 Riverpod”指状态和依赖体系完全迁移，不是让每个 DTO、Widget 和 theme 文件都 import Riverpod。

### 13.6 分阶段推进

| 阶段 | 范围 | 退出条件 |
|---|---|---|
| R0 | ProviderScope、代码生成、Hooks 基线、组合根 bridge、测试 harness | 现有应用行为不变，生成流程稳定，LLM 可获得唯一 API 实例 |
| R1 | LLM 设置完整基准示例 | 代码生成、Hooks、Notifier 与双端共享边界验收通过，旧 LLM Controller 无生产引用 |
| R2 | 按 feature 迁移业务状态 | 所有业务 feature 登记并完成，页面无业务 ChangeNotifier |
| R3 | API / Store / SSE 原生 Riverpod 装配 | feature 不再依赖 Provider bridge，API 无 presentation 反向依赖 |
| R4 | Session、Router、PageStateCache 与全局应用状态 | Router 和全局资源生命周期测试通过 |
| R5 | 删除过渡层 | 无生产 `provider` import / context read-watch-select，删除依赖和 MultiProvider |

每个阶段都必须保持应用可构建、核心流程可测试。R5 之前允许双框架共存，但任何 Provider 保留点都必须登记目标阶段和删除条件。

## 14. 代码生成与 Hooks 基准约定

代码生成和 Hooks 在首个 LLM 试点中启用，不再留到后续 feature 二次切换范式。

### 14.1 代码生成

- 新增 Provider / Notifier 默认使用 `riverpod_annotation` + `riverpod_generator`。
- 与 go_router 生成任务统一通过项目现有 build_runner 流程执行。
- 生成文件纳入项目既定的版本控制规则，任何情况下都禁止手工修改。
- CI 必须能发现源文件与生成文件不一致。
- Router 与 Riverpod 生成代码的大规模修改避免由多个并行任务同时进行。
- experimental Riverpod API 不进入核心业务，除非单独评审。
- 只有生成器无法表达、第三方兼容或明确降低复杂度时才手写 Provider，并在代码中记录原因。

### 14.2 Hooks

- Hooks 是 View 生命周期工具，不是第二套应用状态管理框架。
- `TextEditingController`、FocusNode、AnimationController、Form key 和局部 UI 副作用可以由 Hooks 管理。
- API 数据、可保存草稿、跨端共享状态和 mutation 进度必须由 Riverpod State / Notifier 管理。
- `useEffect` 同步异步加载结果时必须防止覆盖用户已经编辑的草稿。
- 纯展示 Widget 和没有生命周期样板代码的 Consumer 不为了统一形式强制改成 HookWidget。
- LLM 试点中 Desktop 与 Mobile 直接使用同一页面；其它 feature 即使保留不同宿主，也不得因 Hooks 各自建立第二份业务状态源。

## 15. 完成定义

### 15.1 首个试点完成定义

1. LLM 设置使用 `@riverpod` 代码生成完整迁移到 Riverpod。
2. Desktop / Mobile 使用同一个 `LlmSettingsPage` 和单一状态来源。
3. 旧 LLM ChangeNotifier 被删除或无生产引用。
4. 共享表单宿主使用 Hooks 管理 View 生命周期，Notifier 不持有 Flutter UI Controller 或 Form key。
5. build_runner 可同时稳定生成 go_router 与 Riverpod 代码，生成文件无手工修改。
6. Notifier 纯状态测试、统一页面测试和两端接入测试通过。
7. 代码量、测试量、重复 fixture 和维护体验完成对比记录。
8. 团队明确后续迁移范式、节奏和需要调整的边界。

### 15.2 全面迁移完成定义

1. 所有业务 feature 使用 Riverpod 状态所有者。
2. API、Store、Session、SSE、Router 和全局缓存完成 Riverpod 装配或由 Riverpod 管理生命周期。
3. Data 层不再导入 presentation 类型。
4. Desktop / Mobile / Web 共用平台无关的业务 provider identity。
5. 生产代码中不存在 `package:provider/provider.dart` import。
6. 生产代码中不存在 `MultiProvider`、`ChangeNotifierProvider`、`ProxyProvider` 或 `context.read/watch/select` 业务调用。
7. `provider` 从 `pubspec.yaml` 和 lockfile 依赖树的直接依赖中删除。
8. ProviderScope bridge 和所有临时 override adapter 已删除。
9. 全量 analyze、test、五平台关键构建与真实 Web / 移动验收通过。
10. Riverpod provider 生命周期、Session 切换、Router 不重建、SSE 单实例和 resize 状态保持有自动化覆盖。

长期目标不是“新代码默认使用 Riverpod”，而是整个项目最终只保留 Riverpod 状态与依赖体系。Provider 在过渡期未迁移 feature 中继续合法存在，但必须进入迁移清单并最终删除。任何阶段都不为追求框架统一而牺牲用户行为、现有双端 UI、平台能力或代码量目标。
