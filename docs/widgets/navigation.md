# navigation —— Tab、列表头和筛选入口

## `AppBackButton`

路径：`lib/widgets/base/navigation/app_back_button.dart`

全项目统一的返回按钮。`variant` 区分实色、玻璃和播放器 `mediaOverlay`，`size` 区分 `compact`（28/20）、`toolbar`（实色 28/20、玻璃 32/16）和 `touch`（44/20）。播放器返回固定 44/18、使用 `onMedia` 前景色。tooltip 和语义标签默认取 `shellBack`，调用方只在语义确实不同（如“返回失败列表”）时覆盖。步骤内“文字 + 返回”继续用 `AppTextButton`，图标取 `AppBackButton.icon`。

`AppBackGuardController` / `AppBackGuardScope`（`app_back_guard.dart`）负责离开前确认：桌面顶栏和移动子页返回都先 `await canLeave()`。页面在 `initState` 注册、`dispose` 注销；未保存修改的页面必须注册 guard，不能只拦截 Tab 切换。

## `AppTabBar`

路径：`lib/widgets/base/navigation/app_tab_bar.dart`

统一桌面、紧凑和移动顶部 Tab 的样式与选中态。Tab 的数据和切换行为由页面或路由负责。

## `AppSegmentedControl`

路径：`lib/widgets/base/forms/app_segmented_control.dart`

单选分段控件，内部由玻璃层的分段后端实现。`layout: auto` 在 2–6 项时使用等宽分段，7 项以上横向滚动；默认 `scrollable` 保持自然宽度。`enabled: false` 会把所有分段标记为不可选并屏蔽回调。`AppSegmentedControl` 只负责泛型值、主题色和尺寸适配，不再外包玻璃表面。`tone: neutral` 用于玻璃弹层：轨道透明，选中项只浮起中性胶囊；默认 `standard` 保留页面内的玻璃轨道。`AppSegmentedItem.key` 作为分段身份传给玻璃后端，不再作为可查找的 Widget key。它是页面内的筛选/切换控件，不要拿它替代页面级 `AppTabBar`。

## `AppMobileListHeader`

路径：`app_mobile_list_header.dart`

移动列表的透明控制行，不控制滚动。左侧由 `AppMobileHeaderText` 显示标题、计数和辅助信息，右侧最多四个独立 `AppGlassIconButton`。`AppGlassFilterIconButton` 统一筛选入口、当前筛选摘要的 tooltip/semantics 和激活主色；移动端不再把筛选摘要作为文字按钮塞进控制行。

固定或吸顶由页面布局负责：没有滚动前置内容的列表使用 `AppFixedHeaderLayout`；大标题、封面或标签摘要之后的结果列表使用 `AppPinnedSliverSection`，前置内容随滚动移出，控制行吸顶。一级 tab 的大标题使用 `AppMobilePageTitle`。

多选时使用 `AppMobileSelectionHeader` 原地替换正常控制行：关闭图标、已选计数、全选图标。批量动作仍放在 `AppSelectionBottomBar`，并保留文字。

标签影片页用 `TagBrowseSurface` 承载可搜索、可多选的标签墙；标签按热门分组或搜索结果内联铺开，由页面整体滚动，选择先写入草稿再点「查看影片」进入结果态。

## `AppGlassListHeader`

路径：`app_glass_list_header.dart`

桌面列表的液态玻璃控制条骨架。左右两组由页面组合：左侧通常是
`AppGlassFilterGroup`（筛选入口 + 总数），右侧通常是排序入口和选择入口；
筛选入口用 `AppGlassFilterPopover`，排序入口用 `AppSortMenuButton`，列表结果
更新反馈仍由 `AppFilterUpdateBar` 承担。

控制条在可用宽度内左右分组；内容超过宽度时整条横向滚动，尾部操作不会被裁切。
视频合集详情等以排序为主的桌面页把排序入口放在左侧、总数紧随其后，右侧只留选择；
切片、时刻和 PornBox 一级列表沿用同一骨架。

组件不持有业务筛选状态；`AppGlassHeaderButton`、`AppGlassHeaderText` 和
`AppGlassSelectionHeader` 只负责玻璃分组里的按钮、只读信息和多选操作。
`AppGlassFilterGroup` 的筛选入口始终可点，没有独立 `enabled` 参数；
`AppGlassSelectionAction` 以 `onTap == null` 表示禁用，退出多选固定使用通用的
「取消」文案，调用方不再单独传 `exitLabel`。
桌面列表页使用 `AppGlassListHeader`；移动列表页使用 `AppMobileListHeader`。两端保留各自底层抽屉 / 弹层，不为统一外观复制页面结构。移动端筛选、排序、搜索、刷新、选择、新建、同步、播放全部等头部操作只显示图标；标题、计数、多选计数和贴底批量动作保留文字。筛选和排序仍打开底部抽屉，抽屉内用 `AppFilterChoiceSection`、`AppGlassSortSection` 与 `AppGlassFilterFooter`。

## `AppSectionHeader`

路径：`app_section_header.dart`

内容区内的分区标题行：`标题（+可选数量）……右侧动作入口`。用于「发现」「概览」这类由多个预览分区拼成的页面，动作用 `AppTextButton`（默认「更多」+ chevron），跳转由调用方决定；没有落点页或窄布局时可只传标题。

## `AppSortMenuButton`

路径：`app_sort_menu_button.dart`

列表的独立排序入口。排序是视图偏好，不是筛选条件：它不进筛选面板，筛选摘要和「重置筛选」也不包含排序。桌面使用 `AppGlassPopover + AppGlassSortSection`，选中字段或方向后应用并关闭；移动使用底部抽屉，切换时即时应用并刷新选中态，不自动关闭，由用户点遮罩或下拉关闭。排序入口要放进调用方已有的 `AppGlassHeaderGroup` 时同时传 `glassGrouped: true`，避免再包一层玻璃分组。移动端传 `iconOnly: true`，由 tooltip / semantics 提供当前字段和方向。字段和方向控件可分别传 `fieldControlKey` / `directionControlKey`；桌面若需要保持面板打开可显式传 `closeOnSelect: false`。

- 字段类型由调用方提供；方向使用跨 feature 共享的 `SortDirection`，不依赖具体业务域的排序枚举。
- 可空排序（`selectedField == null` 表示后端默认 / 手动顺序）通过 `allowDefaultOption` 提供「默认」chip；方向行由 `directionVisibleWhen` 控制。
- 字段很多的列表仍需要独立入口时，优先放移动控制行的第一个图标动作。

排序面板的字段 + 方向分节统一用 `AppGlassSortSection<F>`（`app_glass_popover.dart`）：桌面弹层和移动抽屉共用，支持 `allowDefaultOption`、`directionVisibleWhen` 以及各 chip / 控件的测试 Key。不要在页面里重复拼 `AppFilterChoiceSection` + 「排序方向」两段。

feature 侧用 `MovieSortMenuButton`、`PlaylistSortMenuButton` 等 domain 适配器把状态映射到这个组件，不要在页面里重复拼接 chip 或抽屉。

二选一排序（切片、时刻的「最新 / 最早」）保留现有的内联按钮或筛选分节，不强制套用排序入口；多字段排序统一走上面的组件。

## `AppMobileFilterDrawerScaffold`

路径：`app_mobile_filter_drawer_scaffold.dart`

移动筛选抽屉的滚动内容与底部操作结构。标准筛选优先用 `AppMobileFilterDrawer<T>`：它持有本地副本、即时外发，默认显示 `AppGlassFilterFooter`，`showResetFooter: false` 用于没有重置语义的面板；需要额外控制器或滚动锚点时继续使用 `AppMobileFilterDrawerScaffold`。筛选值和提交动作仍由 feature 管理。

新列表页优先组合 `AppMobileListHeader` + 页面已有筛选容器，不要为每个 feature 重新实现顶栏布局。
