# 交互反馈设计基线

所有可点元素的交互反馈统一走
[`AppInteractiveSurface`](../lib/widgets/base/interaction/app_interactive_surface.dart)，
不要各自写 `InkWell`、hover 底色或按下叠色。组件级细节读该文件的文档注释。

## 基线规则

| 状态 | 表现 | 说明 |
|---|---|---|
| 常驻 | 无底色 | 不用浅灰胶囊表达「可点」，只有内容本身 |
| 桌面 hover | 无视觉变化 | 与移动端一致；可点性提示只有鼠标手型和 tooltip |
| 按下 | 整体变淡 `opacity 0.7` | 不叠灰色底；数值同微信小程序按钮默认按压态 |
| 键盘焦点 | 无额外视觉 | 已知取舍，后续做无障碍时再补 |
| 禁用 | 由调用方降透明度（项目惯例 `0.56`） | 表面组件只负责不响应 |
| 动效 | 无水波纹、无按压缩放 | `NoSplash` + 全透明 ink 颜色 |

桌面与移动使用同一套组件与 token，不做平台差异。

已接入 `AppInteractiveSurface`：`AppButton`、`AppTextButton`、`AppIconButton`、
`AppSwitch`、`AppLeftCoverCard`、`ActorSummaryCard`、
封面网格卡（切片 / 时刻 / 视频 / 合集成员 / 合集封面 / 图片搜索）与
`MovieSummaryCard`（多选态；普通点击经 `AppImageActionTrigger`，按下反馈与其一致）。
封面悬停动作按钮（`AppCoverHoverActionButton`）同样走它。

长按进入多选 / 弹菜单统一由交互层补一次选择触感，调用方不要再手写
`triggerSelectionHaptic()`：整卡长按走 `AppInteractiveSurface.onLongPress`，
带全局坐标的右键 / 长按菜单走 `AppContextMenuTrigger`（`app_context_menu_trigger.dart`）。

## 待清理（与基线不一致的存量）

1. **Material 内置控件（约 199 处直接使用）**：`lib/theme.dart` 目前仍为其保留
   hover 8% / 按下 12% 的灰色 overlay。本应用不需要 Material Design 的交互样式，
   待逐步替换为自研组件或在主题层清零。
2. **自绘 hover 的组件**：`login_page`、`app_select_field`、
   `movie_player_speed_button`、`movie_player_subtitle_button` 仍使用
   `AppOverlayTokens.hoverAlpha`。播放器浮层在深色视频画面上是否保留 hover
   需要单独评估。
3. **键盘焦点**：无焦点视觉提示（见上表）。

## 验证方式

- Widget 测试：`test/widgets/base/interaction/app_interactive_surface_test.dart`
  覆盖无 ink 叠色、hover 零变化、按下 `0.7`。
- 预览改动后渲染桌面 / 移动页面 PNG：桌面 hover 图必须与默认图逐像素一致，
  按下图整体变淡；预览脚本按仓库根 `AGENTS.md` 的预览规则临时使用、用完删除。
