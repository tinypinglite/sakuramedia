# sheets & dialogs —— 弹层和操作容器

## 桌面对话框

- `AppDesktopDialog`：`lib/widgets/base/overlays/app_desktop_dialog.dart`，统一桌面弹窗宽度、标题区、内容区和动作区。
- `showAppAdaptiveModal<T>`：`app_adaptive_modal.dart`，需要按平台选择弹层形态时使用。

## 移动抽屉和表单

- `showAppBottomDrawer<T>` / `AppBottomDrawerSurface`：`app_bottom_drawer.dart`，移动筛选、动作和详情抽屉。
- `AppBottomFormSheet`：`app_bottom_form_sheet.dart`，带表单布局和提交区域的底部 sheet。
- `AppMobileConfirmActions`：`app_mobile_confirm_actions.dart`，移动确认操作区。

## 菜单和筛选

- `showAppCardContextMenu<T>` / `AppCardContextMenuItem<T>`：`app_card_context_menu.dart`，右键或长按后的卡片菜单。
- `AppFilterPopover` / `AppFilterPanelFooter`：`app_filter_popover.dart`，桌面筛选浮层和统一底部动作。

弹层关闭、导航和 API 操作的顺序由调用页面决定。弹层组件不要直接承担 feature 数据加载，除非该组件本身就是明确的跨域媒体预览组件。
