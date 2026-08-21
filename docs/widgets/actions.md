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

## `AppInlineActionButton`

路径：`lib/widgets/base/actions/app_inline_action_button.dart`

适合列表行或信息块内的轻量操作。需要异步反馈时使用它已有的 loading/disabled 语义，不要在页面外层再套一套状态。

## `AppSwitch`

路径：`lib/widgets/base/actions/app_switch.dart`

设置项启停开关。远端保存状态由页面或 Provider 管理，组件只负责展示和值变化回调。

## 共同约定

按钮尺寸、圆角、颜色和文字样式由主题 token 控制。已有 `Key` 或 `labelKey` 属于测试和可访问性契约，修改前检查对应测试。
