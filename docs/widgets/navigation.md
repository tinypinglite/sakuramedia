# navigation —— Tab、列表头和筛选入口

## `AppTabBar`

路径：`lib/widgets/base/navigation/app_tab_bar.dart`

统一桌面、紧凑和移动顶部 Tab 的样式与选中态。Tab 的数据和切换行为由页面或路由负责。

## `AppListHeader`

路径：`app_list_header.dart`

列表页标题、筛选入口、结果信息和操作槽的统一容器。`AppListHeaderInfo` 用于显示总数、更新时间等辅助信息。

## `AppFilterEntryButton`

路径：`app_filter_entry_button.dart`

列表页打开筛选浮层或抽屉的入口。当前筛选摘要由调用方提供。

## `AppMobileFilterDrawerScaffold`

路径：`app_mobile_filter_drawer_scaffold.dart`

移动筛选抽屉的标题、内容和底部操作结构。筛选值和提交动作仍由 feature 管理。

新列表页优先组合 `AppListHeader` + 页面已有筛选容器，不要为每个 feature 重新实现顶栏布局。
