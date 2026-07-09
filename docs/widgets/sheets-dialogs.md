# sheets & dialogs —— 弹层、抽屉、对话框

任何弹起的层——一律走这里的 4 个入口。确认框见 [feedback.md](./feedback.md) 的 `showAppConfirmDialog`。

## AppDesktopDialog
- **路径**: `lib/widgets/base/overlays/app_desktop_dialog.dart`
- **用途**: 桌面通用对话框壳:圆角、阴影、右上角 X 关闭按钮、可配尺寸/约束/背景。
- **关键参数**: `child`(必填,通常你自己 build) · `dialogKey` · `contentKey` · `width` / `height` / `constraints`(**互斥,不能同时给**) · `insetPadding` · `backgroundColor` · `shape` · `showCloseButton`(默认 true) · `closeButtonKey` · `closeButtonInset` · `onClose`
- **配合**: 一般 `showDialog(context, builder: (_) => AppDesktopDialog(child: ...))`。
- **何时用**: 桌面所有弹出层(表单、播放器、复合面板)。
- **别自己写**: 圆角 / X 按钮 / 阴影 / 底色 / 最大宽度这套壳,全部走它。

## showAppBottomDrawer&lt;T&gt;
- **路径**: `lib/widgets/base/overlays/app_bottom_drawer.dart`
- **签名**: `Future<T?> showAppBottomDrawer<T>({ required BuildContext context, required WidgetBuilder builder, Key? drawerKey, double heightFactor = 0.9, double? maxHeightFactor, bool isScrollControlled = true, bool useSafeArea = true, bool ignoreTopSafeArea = false, bool enableDrag = true, bool showHandle = true })`
- **用途**: 移动端底部抽屉,自动包 `AppBottomDrawerSurface`(顶部小把手、圆角、内容底)。
- **何时用**: 所有移动端"从下滑出"层——筛选、菜单、表单、图片操作、确认。
- **别自己写**: `showModalBottomSheet` + 圆角 clipper——统一走它。
- **对应桌面**: 同一交互在桌面通常是 `AppDesktopDialog` 或 `showMenu`;走 `showAppConfirmDialog(variant: auto)` 会替你分流。

## AppBottomDrawerSurface
- **路径**: `lib/widgets/base/overlays/app_bottom_drawer.dart`
- **用途**: **`showAppBottomDrawer` 内部包壳,已经帮你套好——你不用直接调**。只有极少数场景(在别处的 sliver 里嵌一个抽屉外观、组合到 `showModalBottomSheet` 之外的容器)才手动引。
- **required**: `child` · 可选 `heightFactor` / `maxHeightFactor` / `showHandle`

## AppBottomFormSheet
- **路径**: `lib/widgets/base/overlays/app_bottom_form_sheet.dart`
- **用途**: 移动端**表单专用底抽屉外壳**:承担 `AnimatedPadding(viewInsets)` → `SingleChildScrollView` → `Form` → 标题 + 副标题 + `body` slot + 底部 Cancel/Submit 双按钮。
- **required**: `formKey` · `title` · `subtitle` · `body`(调用方组装 FormFields) · `submitKey` · `isSubmitting` · `onSubmit`
- **可选**: `cancelLabel`(默认 "取消") · `submitLabel`(默认 "保存") · `submitDisabled`(独立门控,如"探针未通过"就不许提交)
- **何时用**: 所有移动端"填一堆字段然后提交"抽屉——添加下载器、添加索引器、添加媒体库、改密。
- **别自己写**: 键盘顶起 padding、外层 scroll、Form key、双按钮布局——它都做好了。
- **对应桌面**: 桌面等价形态是 `AppDesktopDialog` 内包 `Form + AppButton(primary)`;两端不共用同一份 sheet(移动端 SafeArea / keyboard 差异太大)。

## showAppCardContextMenu&lt;T&gt;(+ AppCardContextMenuItem)
- **路径**: `lib/widgets/base/overlays/app_card_context_menu.dart`
- **签名**: `Future<T?> showAppCardContextMenu<T>({ required BuildContext context, required Offset globalPosition, required List<AppCardContextMenuItem<T>> items })`
- **用途**: 卡片右键 / 长按上下文菜单。内部封装 root overlay 反解 globalPosition → RelativeRect 和 `showMenu(useRootNavigator: false, s14 Text)` 那套骨架。
- **AppCardContextMenuItem required**: `value` · `label`; **可选**: `tone`(不传默认 primary; 危险动作传 `AppTextTone.error`)。
- **何时用**: clip / collection 封面 / collection 成员 / video 卡片的右键 / 长按菜单。调用方**保留**自己的私有 enum、`items` 组装(含"回调为 null 则不加此项"逻辑)、`switch` 派发,只把弹菜单骨架换成本入口。
- **手势外壳仍在调用方**: `onSecondaryTapDown` / `onLongPressStart`。
- **别自己 `showMenu`**: 卡片场景一律走本入口。

## AppFilterPopover(+ AppFilterPanelFooter)
- **路径**: `lib/widgets/base/overlays/app_filter_popover.dart`
- **用途**: 「触发按钮 + 展开筛选面板」外壳——LayerLink / OverlayEntry / 遮罩 / CompositedTransformFollower / 面板容器一次封死。actor / movie / ranking 三个 filter toolbar 全走它。
- **AppFilterPopover required**: `triggerLabel` · `panelBuilder`(面板 body, 通常直接给 `*FilterSectionGroup`) · `panelKey`
- **可选**: `footer`(通常传 `AppFilterPanelFooter`,ranking 不传) · `labelKey` · `isSelected` · `highlightWhenOpen`(默认 true; movie 传 false, 语义是"默认或自定义时高亮,与开合无关") · `enabled`(ranking 传 `!isLoading`) · `panelExtraWidth`(actor 180 / movie 260 / ranking 520) · `scrollViewKey`(movie 传测试锚点) · `onOpened`(movie 用来预取年份) · `initialTriggerSize`
- **AppFilterPanelFooter required**: `isDefault` · `onReset`(为 null 时禁用)
- **可选**: `defaultLabel` / `activeLabel` / `resetLabel`
- **何时用**: 桌面「筛选按钮 → 弹出面板」的所有场景。移动端等价形态是 `showAppBottomDrawer` 挂 `*FilterSectionGroup`。
- **别自己写**: OverlayEntry + `_scheduleOverlayRebuild` + `CompositedTransformFollower` + panel Container 这套壳。

## AppMobileConfirmActions
- **路径**: `lib/widgets/base/overlays/app_mobile_confirm_actions.dart`
- **用途**: 底抽屉里"取消 / 确认"这一条 row(左右并排、可 danger 变红、loading 转圈)。
- **required**: `onCancel` · `onConfirm`
- **可选**: `cancelLabel`(默认 "取消") · `confirmLabel`(默认 "确认") · `isDangerous` · `isLoading` · `cancelKey` / `confirmKey`
- **何时用**: 手写自定义底抽屉里,底部要放这样一条按钮 row 时。
- **何时不用**: 简单"确认吗?"——走 `showAppConfirmDialog`,它内部已经用了这个。

---

## 相关约定

- 弹层里也走**四态**(骨架 / 错误 / 空 / 内容),别以为弹层就跳过。
- 弹层内触发提交后失败:恢复按钮 `isLoading` 状态、**不 pop**、toast。参见 `showAppConfirmDialog` 的 `onConfirm` 契约。
- 键盘遮挡:`AppBottomFormSheet` 已处理 `viewInsets`;自己拼抽屉要 `AnimatedPadding(padding: MediaQuery.viewInsetsOf(context))`。
