# forms —— 表单输入

## `AppTextField`

路径：`lib/widgets/base/forms/app_text_field.dart`

统一文本输入样式、标签、错误和辅助文案，内部使用玻璃层文本输入后端 + `FormField`。正常态使用 `input` role：浅色为低透明度中性玻璃井 + 上亮下暗的 1px rim，不再叠均匀 `borderSubtle` 外框，也不使用会发白的 `whitenStrength`；深色模式保持深玻璃。placeholder 使用 `secondary`，保证透光时仍可读。顶栏等已有玻璃容器上的输入传 `AppGlassTone.toolbar`，使用更轻的 `toolbarInput`；高对比度回退为实色输入面并用 `borderStrong` 描边。`fillColor` 覆盖输入面填充色，`borderRadius` 映射到玻璃形状。页面负责 controller、校验和提交时机；固定高度用 `height`，多行用 `minLines` / `maxLines`，不再提供 `expands`。label、helper 和 error 位于玻璃面外侧，错误文案继续参与表单校验并由 live region 播报。

## `AppGlassSearchField`

路径：`lib/widgets/base/forms/app_glass_search_field.dart`

页面级液态玻璃搜索框，使用玻璃层文本输入后端的 `input` role。固定 40 高、20 圆角，不开放尺寸参数；提供前置搜索图标、有内容时的清空按钮和 `onChanged` 透传，筛选策略仍由页面负责。与桌面顶栏搜索框共用 `app_glass_search_field_chrome.dart` 的输入面/字体配置；顶栏搜索传 `AppGlassTone.toolbar` 走更轻的 `toolbarInput`，但保留其“只有后缀图搜动作”的产品结构。适合玻璃桌面页的页内搜索，不要把顶栏全局搜索替换成它。

## `AppPasswordField`

路径：`lib/widgets/base/forms/app_password_field.dart`

密码输入和显示/隐藏切换。不要在业务页复制可见性按钮或输入框装饰。

## `AppSelectField<T>`

路径：`lib/widgets/base/forms/app_select_field.dart`

统一选择字段和下拉菜单，支持 regular、compact、mini 尺寸。触发器使用
`AppSurface` + `AppInteractiveSurface`，下拉菜单走 `AppGlassAnchoredMenu`，
与筛选/排序弹层共享玻璃与 flat 材质；菜单行不再使用 Material hover 底色。
选项数据由页面提供，组件不负责请求远端选项。

## `AppInfoPill`

路径：`lib/widgets/base/forms/app_info_pill.dart`

展示只读标签和值，适合表单说明、状态或实体元信息，不用于可编辑输入。

## `AppFilterChoiceSection` / `AppFilterChip`

路径：`lib/widgets/base/forms/app_filter_choice_section.dart`、`lib/widgets/base/forms/app_filter_chip.dart`

筛选面板正文的统一选择组件。`AppFilterChoiceSection<T>` 负责 `s12/medium/secondary` 分节标题、加载骨架和分段控件；分段控件自带中性平面轨道与选中胶囊，分节不再额外包一层轨道。`AppFilterOptionSection<T>` 是“选项 + 标签映射”的薄封装，供业务域复用同一分节；`AppFilterChip` 是轻量中性多选胶囊，不做背景模糊，选中态使用中性高亮面 + 边框 + 半粗体文字，适合年份、标签、杯数这类长列表。`optionKeyBuilder` 映射为分段节点的 Widget key。

## `AppFilterRangeSection`

路径：`lib/widgets/base/forms/app_filter_range_section.dart`

筛选面板里的双滑块分节。内部保留 Flutter `RangeSlider` 的手势、键盘和无障碍语义，统一 4px 轨道、白色圆 thumb + elevation、主色 active track 和 `borderSubtle` inactive track；拖动中只更新本地区间与值文案，松手才通过 `onChangeEnd` 应用筛选。不要再在业务页面单独写 `SliderTheme` + `RangeSlider`。

## `AppPickerHeader`

路径：`lib/widgets/base/forms/app_picker_header.dart`

选择器弹层头部按 iOS sheet 导航栏布局：左侧关闭、中间标题、右侧完成。可以同时传 `onClose` 与 `onDone`；不传 `onDone` 时右侧「完成」回退到 `onClose`，因此只关闭弹层的选择器不必重复传同一个回调。桌面弹窗和移动抽屉都把 `showCloseButton` / `showDesktopCloseButton` 关掉。标题下可选说明，再往下是带清空的 `AppGlassSearchField` 和横向筛选 chips。不需要搜索的简单选择器可以不传 `searchController`，防抖仍由调用方处理。

## `AppPickerIosSection` / `AppPickerIosRow`

路径：`lib/widgets/base/forms/app_picker_layout.dart`

`AppPickerIosSection` 是弹层正文里的 solid inset grouped list：外层仍是 Liquid Glass，内容行保持不透明，分隔线按前一行是否有 leading 自动对齐。`AppPickerIosRow` 是行级交互：整行可点、按压有反馈、选择态用尾部勾号表达，不画 Material checkbox 或卡片边框；支持 `leading`、`subtitleWidget`、`trailingText`、`busy` 和 `optionKey`。封面行用 `AppPickerIosCover`（默认 56×32）作为 leading。

新建、清空这类次级动作使用 `AppPickerIosActionRow`：默认添加图标 + 主色标签，外观和行高与普通选项行一致，不要在业务选择器里重复写主色行。`AppPickerIosStateWithAction` 把空态 / 错误态和这类动作组合成一个可滚动正文，供「没有数据时仍可新建」的选择器复用。

## `AppPickerListFrame` / `AppPickerIosState`

路径：`lib/widgets/base/forms/app_picker_layout.dart`

`AppPickerListFrame` 统一选择器列表的桌面限高与抽屉剩余高度：桌面固定最高 400，不再按页面单独传高度；抽屉内返回 `Expanded`。滚动视口底部会按 grouped card 圆角裁剪，避免长列表平切。`AppPickerIosState` 负责 loading / 空态 / 错误和可选主操作，不另铺通用空态卡片。

选中计数放在 `AppPickerIosSection.header`，用 `commonSelectedCount` 一类文案；新建/清空这类次级动作使用上面的 `AppPickerIosActionRow`，不再使用独立页脚。

## 共同约定

字段 label、错误、必填语义和 focus 行为应由调用页面明确提供。新增表单字段先查已有 token 和组件，不在业务页面写裸边框、圆角和字号。
