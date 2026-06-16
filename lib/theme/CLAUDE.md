# lib/theme/ — 设计系统 token

颜色/间距/圆角/阴影/排版/组件尺寸/表单/导航/弹层/侧边栏 的全部视觉常量。共享 UI 组件在 `lib/widgets/`(见其 CLAUDE.md)。

## 两条硬规则

1. **取 token 一律 `context.appXxx`**(getter 名 = 类名首字母小写,如 `context.appColors` / `appSpacing` / `appRadius` / `appShadows` / `appComponentTokens` / `appOverlayTokens`)。文字必须用顶层函数 **`resolveAppTextStyle(context, size:, weight:, tone:)`** 或 `AppText` widget。**绝不写裸 `Color(...)` / `fontSize:` / 裸数值 `EdgeInsets` / `BorderRadius.circular(数字)`**。
2. **业务代码只 `import 'package:sakuramedia/theme.dart'` 这一个 barrel**,即可拿到全部 token + `AppText`,不要逐个 import `theme/` 子文件。

> 守卫测试 `test/theme/theme_source_guard_test.dart` 会扫描 `lib/`(除 `theme/` 自身)正则禁止上述裸值——引入裸视觉值**测试必红**。零值(`EdgeInsets.all(0)`/`circular(0)`)放行。

## token 文件清单(都是 `ThemeExtension`)

统一模式:`@immutable class AppXxx extends ThemeExtension<AppXxx>` + `required` 全字段 + `const AppXxx.defaults()`(桌面)+(部分)`const AppXxx.mobile()` + `copyWith` + `lerp`,文件尾两个扩展暴露 `context.appXxx`。

- `app_colors.dart` `AppColors`:~41 语义色(surface 系 / 侧边栏含 macOS 玻璃 / border / 状态面 / movieCard*/movieDetail* 业务色)。**注意:文字色不在这里**。
- `app_typography.dart`:三个扩展 `AppTextScale`(字号)/`AppTextWeights`(字重)/`AppTextPalette`(**文字色调** 10 种)+ 枚举 `AppTextSize/Weight/Tone`。核心入口是 `resolveAppTextStyle`。
- `app_spacing.dart`(xs4…xxxl40)、`app_radius.dart`(xs4…pill999 + `xxxBorder` getter)、`app_shadows.dart`(`card`/`panel` getter)、`app_layout_tokens.dart`、`app_component_tokens.dart`(最大 ~70 字段,图标/按钮多档、movieCard/movieDetail 尺寸)、`app_form_tokens.dart`、`app_navigation_tokens.dart`、`app_overlay_tokens.dart`(播放器叠层尺寸全在这)、`app_sidebar_tokens.dart`。

**两个例外(非 ThemeExtension)**:
- `app_page_insets.dart` `AppPageInsets`:纯静态常量(`desktopStandard`=24 / `compactStandard`=8),直接 `AppPageInsets.desktopStandard` 引用。
- `lib/config/app_image_config.dart` `AppImageConfig`:**运行时可变全局**(`enableBlur=false` 默认关、`blurSigma`、图片缓存上限)。

## 桌面 vs 移动主题分离

`theme.dart` 构建 `sakuraDesktopThemeData` / `sakuraMobileThemeData`,走同一 `_buildSakuraThemeData()`,**只传不同 token 实例**(桌面 `.defaults()`、移动 `.mobile()`)。**只有 5 类 token 区分平台**(`AppComponentTokens`/`AppFormTokens`/`AppNavigationTokens` + 文本三件套,且文本 `.mobile()` 当前与 `.defaults()` 同值,是预留差异位);其余共用 `.defaults()`。`sakuraThemeData = sakuraDesktopThemeData`(**Web 复用桌面**)。品牌主色 `0xFF6B2D2A` 硬编码在 `colorScheme.primary`。Web 字体走 `NotoSansSC` 子集 + `fontVariations` wght 轴(仅 `kIsWeb`)。

## 编辑前必须知道的坑

- **加 token 字段是"全家桶"改动**:一个字段要同步 6 处——主构造 `required`、`.defaults()`、(若有)`.mobile()`、`final` 声明、`copyWith`、`lerp`。漏 `lerp`/`copyWith` 编译错或插值丢字段。
- **加 token 文件**:`theme.dart` 同时加 `import`+`export`,并在 `_buildSakuraThemeData` 的 `extensions:` 注册实例,否则 `context.appXxx` 永远走 `?? .defaults()` 回退、主题值不生效。
- **改颜色注意分工**:背景/边框/状态面在 `AppColors`、**文字色在 `AppTextPalette`**、品牌主色还在 `colorScheme.primary`——三处可能要同步。
- `AppImageConfig.enableBlur` 默认 `false`(近期"关闭图片模糊");它是运行时全局开关,改它对全 app 立即生效。

## 与测试的关系

`test/theme/theme_source_guard_test.dart`(裸值守卫)、`test/theme/theme_tokens_test.dart`(token 值回归——改默认值先看这)。
