# sheets & dialogs —— 弹层和操作容器

## 桌面对话框

- `AppDesktopDialog`：`lib/widgets/base/overlays/app_desktop_dialog.dart`，统一桌面弹窗宽度、标题区、内容区和动作区。
- `showAppAdaptiveModal<T>`：`app_adaptive_modal.dart`，需要按平台选择弹层形态时使用；`dialogKey` / `drawerKey` 可分别指定两端测试锚点，`builder` 会被 `AppAdaptiveModalShellScope` 包住，body 可用 `maybeIsDrawer(context)` 感知壳体。

## 移动抽屉和表单

- `showAppBottomDrawer<T>` / `AppBottomDrawerSurface`：`app_bottom_drawer.dart`，移动筛选、动作和详情抽屉。
- `AppBottomFormSheet`：`app_bottom_form_sheet.dart`，带表单布局和提交区域的底部 sheet。
- `AppMobileConfirmActions`：`app_mobile_confirm_actions.dart`，移动确认操作区。

## 菜单和筛选

- `showAppActionMenu<T>` / `AppMenuItem<T>`：`app_action_menu.dart`，全应用唯一的右键 / 长按菜单壳；负责定位、统一表面样式与项渲染、底部操作表（可选标题 + 独立「取消」行）、全屏图片下的抽屉宿主。调用方只组装 items 并派发返回值，不要另写 `showMenu`。
  - `AppMenuPresentation` 由**触发方式**决定，不按平台：长按 / 右键用 `popup`（默认，锚定按压点），「更多」按钮的动作列表用 `bottomDrawer`。
  - 弹层宽度由最宽项决定（`min 112 / max 320`），正文 `s12`、行高 36（带副标题 52）、图标 16；菜单项之间固定 4px 间距分项，不使用分隔线；操作表行高 52、图标 18、正文 `s12`。
  - 弹层菜单项的 hover / 按压高亮是从菜单边缘内缩 4px 的同心圆角矩形（`sm` = 外层 `md` 12 − 4），由壳内私有 entry 渲染，不要再退回 `PopupMenuItem`（它写死无圆角 InkWell）。
- `AppAnchoredPopover` / `AppPopoverController`：`app_anchored_popover.dart`，桌面「触发器 + 锚定浮层」通用骨架；负责测量触发器、上下/左右定位、全屏遮罩、外部点击关闭、可选入场动画与 Esc 关闭。面板背景、滚动和 footer 由调用方提供。
- `AppFilterPopover` / `AppFilterPanelFooter`：`app_filter_popover.dart`，桌面筛选浮层和统一底部动作；筛选面板宽度、滚动区和 footer 约定保留在这里，浮层骨架内部使用 `AppAnchoredPopover`。浮层打开期间会暂时隐藏触发器的 Tooltip，避免其从面板上沿露出。
- `AppSortMenuButton`：排序入口复用同一套桌面锚定浮层与移动底部抽屉外壳；排序内容见 `navigation.md`。

合集成员选择器（添加切片 / 添加时刻）在弹层头部收口「搜索 + 仅看未加入 + 类型筛选 + 计数」，加入后即时出池；具体实现见各 feature 的 `add_*_to_collection_dialog.dart`。

「加入合集」目标选择器（切片 / 时刻 / 视频）共用 `lib/widgets/domain/collections/collection_target_picker.dart` 的 `showCollectionTargetPicker`：桌面弹窗 / 移动抽屉由调用方的 presentation 决定，列表数据监听各域 overview provider，只负责选中一个目标合集并返回，实际写入由调用方批量执行。

弹层关闭、导航和 API 操作的顺序由调用页面决定。弹层组件不要直接承担 feature 数据加载，除非该组件本身就是明确的跨域媒体预览组件。
