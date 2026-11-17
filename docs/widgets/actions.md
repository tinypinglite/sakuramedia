# actions —— 操作控件

## `AppButton`

路径：`lib/widgets/base/actions/app_button.dart`

主要按钮，支持 `primary`、`secondary`、`ghost`、`danger` 变体以及多档尺寸。用于提交、保存、确认等有明确动作的场景。

## `AppTextButton`

路径：`lib/widgets/base/actions/app_text_button.dart`

低强调文字操作，支持背景样式、强调色和尺寸。用于次要操作、筛选清除和卡片内联动作。选中态由 `selectedStyle` 区分：默认 `tinted`（主色文字 + 淡主色底，筛选弹层里的 chip）；页面内联的排序/切换传 `plain`（主色文字 + 加粗，无底色）。异步操作传 `isLoading: true`：沿用正常态配色、图标位换转圈，并自动禁用点击。

## `AppIconButton`

路径：`lib/widgets/base/actions/app_icon_button.dart`

图标操作按钮，支持 `mini`、`compact`、`inline`、`regular` 尺寸。`inline` 固定 32×32、`iconSizeSm`，用于设置页和列表行右侧的编辑/删除/同步等紧凑动作。必须提供可理解的 tooltip 或等价语义。

## `AppGlassIconButton`

路径：`lib/widgets/base/actions/app_glass_icon_button.dart`

导航栏、吸顶控制条、移动列表头和浮层使用的液态玻璃圆钮，默认 44×44；桌面顶栏传 `size: 32` 与更小的图标。移动列表头用它承载筛选、排序、搜索、刷新、选择和新建等可图标化操作。`tone: AppGlassTone.standard` 使用常驻 `control` 玻璃胶囊；`tone: AppGlassTone.toolbar` 用于顶栏，静止态只显示图标，hover/focus/press 才浮出 `toolbarControl` 轻玻璃胶囊。可用 `iconWidget` 承载加载指示器等非 `IconData` 内容。高对比度模式回退为带描边的实色圆钮。只用于功能层，内容卡和正文不要使用。

## `AppInteractiveSurface`

路径：`lib/widgets/base/interaction/app_interactive_surface.dart`

全项目统一的可点表面，所有可点元素都应经过它，不要再手写 `InkWell`。默认无水波纹、无 hover / 按下底色，按下整块透明度降到 `0.7`（整体变淡）；`onTap` / `onTapDown` / `onLongPress` / `onSecondaryTap` 都走这一层手势，可同时配合 `semanticLabel`。需要可见 hover 的入口通过 `onHoverChanged` 由调用方自绘背景（侧栏导航项），不要打开 InkWell 自带 hover 色。`focusRing` 默认开启，键盘聚焦时绘制 2px 主题色焦点环；需要自定义焦点顺序时传 `focusNode`。`onLongPress` 触发时统一播放一次选择触感（`core/platform/haptic_feedback.dart`，桌面端无副作用），调用方不要重复触发。禁用时只负责不响应，视觉禁用（降透明度、换前景色）由调用方决定。完整交互基线见 `docs/interaction-design.md`。

## `AppClickable`

路径：`lib/widgets/base/interaction/app_clickable.dart`

只为没有内置鼠标指针的自定义点击区域提供鼠标指针。传 `onTap` / `onLongPress` / `onSecondaryTap` 时内部委托给 `AppInteractiveSurface`，自动获得按下反馈、焦点环和语义；不传手势时保持纯 `MouseRegion`。只有确实要自行实现手势（例如自定义 `GestureDetector` 的拖拽 / 多指逻辑）时才在它外层包 `AppClickable`。调用方必须根据实际交互状态传入 `enabled`；禁用区域使用系统默认箭头指针。

## `AppModalActionRow`

路径：`lib/widgets/base/overlays/app_modal_action_row.dart`

弹层底部动作的统一布局：默认取消在左、确认在右、等宽；提交中 `isSubmitting` 让确认按钮转圈并禁用取消；`submitVariant: AppButtonVariant.danger` 只用于删除等不可恢复操作。表单等不需要重复退出入口的场景传 `showCancel: false`，只保留主按钮，此时无需传 `onCancel`；移动抽屉用通栏，桌面对话框用右对齐自然宽度。`extraAction` 存在时按剩余按钮等分。`AppConfirmDialog`、`AppMobileConfirmActions` 保留双按钮；`AppDesktopFormDialog`、`AppBottomFormSheet` 使用单主按钮，页面不要再手写底部 Row。

## `AppSwitch`

路径：`lib/widgets/base/actions/app_switch.dart`

设置项启停开关。远端保存状态由页面或 Provider 管理，组件只负责展示和值变化回调。

## 共同约定

按钮尺寸、圆角、颜色和文字样式由主题 token 控制。已有 `Key` 或 `labelKey` 属于测试和可访问性契约，修改前检查对应测试。

鼠标游标统一约定：可点区域一律优先用 `AppInteractiveSurface` 承载点击、鼠标指针与按下反馈；标准 Material 按钮、弹出菜单项、复选框和单选框由 `lib/theme.dart` 统一配置；确需自行实现手势的自定义 `GestureDetector` 才外包 `AppClickable`。不要再手写 `InkWell`，也不要给 `InkWell` 外层再套 `MouseRegion`。
