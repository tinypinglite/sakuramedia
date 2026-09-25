# actions —— 操作控件

## `AppButton`

路径：`lib/widgets/base/actions/app_button.dart`

主要按钮，支持 `primary`、`secondary`、`ghost`、`danger` 变体以及多档尺寸。用于提交、保存、确认等有明确动作的场景。

## `AppTextButton`

路径：`lib/widgets/base/actions/app_text_button.dart`

低强调文字操作，支持背景样式、强调色和尺寸。用于次要操作、筛选清除和卡片内联动作。

## `AppIconButton`

路径：`lib/widgets/base/actions/app_icon_button.dart`

图标操作按钮，支持 `mini`、`compact`、`regular` 尺寸。必须提供可理解的 tooltip 或等价语义。

## `AppInteractiveSurface`

路径：`lib/widgets/base/interaction/app_interactive_surface.dart`

全项目统一的可点表面，所有可点元素都应经过它，不要再手写 `InkWell`。默认无水波纹、无 hover / 按下底色，按下整块透明度降到 `0.7`（整体变淡）；`onTap` / `onLongPress` / `onSecondaryTap` 都走这一层手势，可同时配合 `semanticLabel`。禁用时只负责不响应，视觉禁用（降透明度、换前景色）由调用方决定。完整交互基线见 `docs/interaction-design.md`。

## `AppClickable`

路径：`lib/widgets/base/interaction/app_clickable.dart`

只为没有内置鼠标指针的自定义点击区域提供鼠标指针，不负责点击回调和按下反馈。**需要点击反馈时用 `AppInteractiveSurface`**；只有确实要自行实现手势（例如自定义 `GestureDetector` 的拖拽 / 多指逻辑）时才在它外层包 `AppClickable`。调用方必须根据实际交互状态传入 `enabled`；禁用区域使用系统默认箭头指针。

## `AppInlineActionButton`

路径：`lib/widgets/base/actions/app_inline_action_button.dart`

适合列表行或信息块内的轻量操作。需要异步反馈时使用它已有的 loading/disabled 语义，不要在页面外层再套一套状态。

## `AppSwitch`

路径：`lib/widgets/base/actions/app_switch.dart`

设置项启停开关。远端保存状态由页面或 Provider 管理，组件只负责展示和值变化回调。

## 共同约定

按钮尺寸、圆角、颜色和文字样式由主题 token 控制。已有 `Key` 或 `labelKey` 属于测试和可访问性契约，修改前检查对应测试。

鼠标游标统一约定：可点区域一律优先用 `AppInteractiveSurface` 承载点击、鼠标指针与按下反馈；标准 Material 按钮、弹出菜单项、复选框和单选框由 `lib/theme.dart` 统一配置；确需自行实现手势的自定义 `GestureDetector` 才外包 `AppClickable`。不要再手写 `InkWell`，也不要给 `InkWell` 外层再套 `MouseRegion`。
