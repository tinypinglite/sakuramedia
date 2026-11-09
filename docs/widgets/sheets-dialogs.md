# sheets & dialogs —— 弹层和操作容器

## 桌面对话框

- `showAppDialog<T>`：`lib/widgets/base/overlays/app_dialog.dart`，桌面弹窗统一入口。转场使用 `250ms` 整树淡出，内容和玻璃一起退场。不要使用玻璃层的入场动画能力做弹窗转场，否则退场会先抽掉内容、只留下短暂的空玻璃骨架。业务弹窗必须走这个入口，不再直接调用 `showDialog`。
- 资源导入弹窗在桌面端于打开时确定高度：媒体库和目录列表异步加载时，玻璃面不会在入场动画中改变尺寸；移动端仍由底部抽屉的固定高度承载。
- `AppDesktopDialog`：`lib/widgets/base/overlays/app_desktop_dialog.dart`，统一桌面弹窗宽度、标题区、内容区和动作区。默认整块使用全站统一的液态玻璃，正文直接铺在玻璃上，输入框和按钮各自负责局部可读性；显式传 `backgroundColor` 或 `shape` 时保留实色弹窗，供图片预览等特殊内容使用。
- `showAppAdaptiveModal<T>`：`app_adaptive_modal.dart`，需要按平台选择弹层形态时使用；`dialogKey` / `drawerKey` 可分别指定两端测试锚点，`builder` 会被 `AppAdaptiveModalShellScope` 包住，body 可用 `maybeIsDrawer(context)` 感知壳体。

## 移动抽屉和表单

- `showAppBottomDrawer<T>` / `AppBottomDrawerSurface`：`app_bottom_drawer.dart`，移动筛选、动作和详情抽屉。抽屉是 8px 浮起的中性玻璃面，正文直接铺在玻璃上；输入框、按钮等控件不要透明化。
- `showMobileVideoActionsSheet`：PornBox 视频动作抽屉。封面、标题与元信息之后是整行主色「播放」按钮；缩略图、加入/移出合集和删除走三列动作格，所属合集 chips 保持可跳转。
- `AppBottomFormSheet`：`app_bottom_form_sheet.dart`，带表单布局和提交区域的底部 sheet。
- `AppMobileConfirmActions`：`app_mobile_confirm_actions.dart`，移动确认操作区。
- 所有移动筛选抽屉统一使用 `AppMobileFilterDrawerScaffold`（特殊滚动 / 锚点场景）或 `AppMobileFilterDrawer<T>`（标准筛选）承载平面分段控件和可选的 `AppGlassFilterFooter`；抽屉内不另铺一层实色卡片，正文直接落在 `AppModalGlassSurface` 上。

模态玻璃统一走 `AppModalGlassSurface`（内部是 `AppSurface` 的 `popover` role）：材质和边缘光使用与全站相同的玻璃，正文直接使用玻璃表面。高对比度或模糊不可用时，`AppSurface` 会切换到更实的 fallback；业务弹层不要再自绘另一套半透明底或高光。

模态玻璃不再提供强度变体；`AppDesktopDialog`、`showAppBottomDrawer` 和 `showAppAdaptiveModal` 都直接使用统一的 `popover` 材质。Toast 走 `overlay` role，不再维护独立的 glassHighlight/glassBorder 配方。

玻璃弹窗内的正文不要整块铺 `surfaceCard`：选择器使用 `AppPickerIosSection` 的不透明 inset grouped list，外层玻璃只承担 modal chrome；输入框和按钮各自提供局部可读表面。`AppPickerHeader` 按 iOS sheet 导航栏接管关闭/完成、搜索和筛选，调用外壳时关闭 `showCloseButton` / `showDesktopCloseButton`。选中计数放在 grouped section header，新建/清空动作优先做成列表行。

## 菜单和筛选

- `showAppActionMenu<T>` / `AppMenuItem<T>`：`app_action_menu.dart`，全应用唯一的右键 / 长按菜单壳；负责定位、统一表面样式与项渲染、底部操作表（可选标题 + 独立「取消」行）、全屏图片下的抽屉宿主。调用方只组装 items 并派发返回值，不要另写菜单壳。
  - `AppMenuPresentation` 由**触发方式**决定，不按平台：长按 / 右键用 `popup`（默认，锚定按压点），「更多」按钮的动作列表用 `bottomDrawer`。
  - 锚定弹层使用 `AppSurface` 的自绘玻璃 platter，宽度按内容测量：桌面 160–240、移动 180–260；桌面行高 30（副标题 44）、图标 16、圆角 18、外层留白 4、行内左右 10；移动行高 38（副标题 50）、图标 18、圆角 24、外层留白 6、行内左右 12。标题 `s14`，副标题 `s12`。操作表仍为行高 52、图标 18、正文 `s12`。
  - 锚定弹层只显示玻璃动作 platter，保留图标、hover、危险色和禁用态；透明 barrier、无背景压暗和源内容预览，点击外部或返回键得到 `null`。不要退回 `showMenu` 或 `PopupMenuItem`。
- `AppGlassAnchoredMenu`：`app_glass_anchored_menu.dart`，紧凑下拉/选择菜单的统一锚定壳。支持动态宽度、上下翻转、限高滚动、点击外部/Esc 关闭和 `AppGlassAnchoredMenuController`；面板使用 `AppSurface`，行使用 `AppGlassMenuRow`。侧栏主题色/版本、登录协议/语言和 `AppSelectField` 都走它，不要再使用 `PopupMenuButton`。
- `AppGlassMenuRow`：锚定菜单里的标准行，支持 leading/title/subtitle/trailing、选中勾选和禁用态；点击反馈由 `AppInteractiveSurface` 负责，不写 hover 底色。
- `AppGlassFilterPopover`：`app_glass_filter_popover.dart`，桌面筛选的唯一高层入口。标准入口负责触发器、计数信息、滚动区和 `AppGlassFilterFooter`；图片搜索、演员标签等特殊入口通过 `triggerBuilder` / `footerBuilder` 复用同一弹层与关闭语义。
- `AppGlassPopover` / `AppGlassSortSection` / `AppGlassFilterFooter`：`app_glass_popover.dart`，玻璃弹层低层壳与共享分节。`AppGlassPopover` 固定 468 宽、圆角 24，内容按固有高度布局并自动避让屏幕边缘；复杂面板传 `scrollable: true`，内容区限高并独立滚动，footer 固定。`AppGlassSortSection` 只负责字段 + 方向分节；`AppGlassFilterFooter` 统一「即时生效 + 重置」底栏。筛选正文使用 `AppFilterChoiceSection`，不再有第二套玻璃选择分节。
- `AppFilterChoiceSection` / `AppFilterChip` / `AppFilterRangeSection`：筛选面板正文统一使用这三个组件。单选分节用分段控件（2–6 项等宽、更多项滚动）；多选胶囊用轻量中性 `AppFilterChip`；双滑块用原生 `RangeSlider` 换 Apple 皮肤。不要再在业务页面拼 `AppTextButton` chip、`RangeSlider` 主题或分节标题。
- `AppSortMenuButton`：排序入口复用同一套桌面锚定浮层与移动底部抽屉外壳；排序内容见 `navigation.md`。

合集成员选择器（添加切片 / 添加时刻）在弹层头部收口「搜索 + 仅看未加入 + 类型筛选 + 计数」，加入后即时出池；具体实现见各 feature 的 `add_*_to_collection_dialog.dart`。

「加入合集」目标选择器（切片 / 时刻 / 视频）共用 `lib/widgets/domain/collections/collection_target_picker.dart` 的 `showCollectionTargetPicker`：桌面弹窗 / 移动抽屉由调用方的 presentation 决定，列表数据监听各域 overview provider，只负责选中一个目标合集并返回，实际写入由调用方批量执行。

弹层关闭、导航和 API 操作的顺序由调用页面决定。弹层组件不要直接承担 feature 数据加载，除非该组件本身就是明确的跨域媒体预览组件。
