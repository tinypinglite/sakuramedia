# navigation —— Tab、列表头和筛选入口

## `AppTabBar`

路径：`lib/widgets/base/navigation/app_tab_bar.dart`

统一桌面、紧凑和移动顶部 Tab 的样式与选中态。Tab 的数据和切换行为由页面或路由负责。

## `AppSegmentedControl`

路径：`lib/widgets/base/forms/app_segmented_control.dart`

单选分段控件，内部由 `liquid_glass_widgets` 的 `GlassSegmentedControl.scrollable` 实现，保持自然宽度，空间不足时横向滚动。`AppSegmentedControl` 只负责泛型值、主题色和尺寸适配，不再外包 `AppGlassSurface`。`AppSegmentedItem.key` 作为分段身份传给 `GlassSegment.id`，不再作为可查找的 Widget key。它是页面内的筛选/切换控件，不要拿它替代页面级 `AppTabBar`。

## `AppListHeader`

路径：`app_list_header.dart`

列表页标题、筛选入口、结果信息和操作槽的统一容器。`AppListHeaderInfo` 用于显示总数、更新时间等辅助信息。

固定或吸顶由页面布局负责：普通列表用 `AppFixedHeaderLayout`，介绍区后的列表用 `AppPinnedListHeader`。`AppListHeader` 本身不控制滚动。多选时使用 `AppListHeader.selection` 在同一位置替换正常内容；移动批量操作放在结果区之外的底部操作条。

标签影片页用 `lib/features/tags/presentation/widgets/tag_selection_header.dart` 的 `TagSelectionHeader` 固定选择入口、横向已选摘要、匹配模式和常看标签；桌面把选择入口与常看标签并到一行，移动端上下两行。点入口打开自适应弹窗（移动全高底部弹层 / 桌面居中弹窗），弹窗内用 `TagSelectorPanel(scrollableTagCloud: true)` 滚动查看全部标签，选择即时生效。

## `AppSectionHeader`

路径：`app_section_header.dart`

内容区内的分区标题行：`标题（+可选数量）……右侧动作入口`。用于「发现」「概览」这类由多个预览分区拼成的页面，动作用 `AppTextButton`（默认「更多」+ chevron），跳转由调用方决定；没有落点页或窄布局时可只传标题。

## `AppFilterEntryButton`

路径：`app_filter_entry_button.dart`

列表页打开筛选浮层或抽屉的入口。当前筛选摘要由调用方提供。

## `AppSortMenuButton`

路径：`app_sort_menu_button.dart`

列表的独立排序入口。排序是视图偏好，不是筛选条件：它不进筛选面板，筛选摘要和「重置筛选」也不包含排序。桌面用 `AppFilterPopover` 锚定浮层，移动用底部抽屉；两端按钮外观和内容一致，选中即应用并关闭。

- 字段类型由调用方提供；方向使用跨 feature 共享的 `SortDirection`，不依赖具体业务域的排序枚举。
- 可空排序（`selectedField == null` 表示后端默认 / 手动顺序）通过 `allowDefaultOption` 提供「默认」chip；方向行由 `directionVisibleWhen` 控制。
- 字段很多的列表仍需要独立入口时，优先放 `AppListHeader.actionSlots` 第一项；移动端只显示图标。

feature 侧用 `MovieSortMenuButton`、`PlaylistSortMenuButton` 等 domain 适配器把状态映射到这个组件，不要在页面里重复拼接 chip 或抽屉。

二选一排序（切片、时刻的「最新 / 最早」）保留现有的内联按钮或筛选分节，不强制套用排序入口；多字段排序统一走上面的组件。

## `AppMobileFilterDrawerScaffold`

路径：`app_mobile_filter_drawer_scaffold.dart`

移动筛选抽屉的标题、内容和底部操作结构。筛选值和提交动作仍由 feature 管理。

新列表页优先组合 `AppListHeader` + 页面已有筛选容器，不要为每个 feature 重新实现顶栏布局。
