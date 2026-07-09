# layout & shell —— 页面壳层与容器

从整页壳层到卡片、说明块、迷你数据卡、设置项……所有"页面结构级容器"都在这里。

## 一、整页壳层

### AppDesktopShell
- **路径**: `lib/widgets/app_shell/app_desktop_shell.dart`
- **用途**: 桌面主壳:左 Sidebar + 顶 TopBar + body。
- **required**: `currentPath` · `layout` · `topBarConfig` · `shellNavigatorKey` · `navGroups` · `child`
- **何时用**: 桌面路由树顶层,通常由 `routes/` 里的 shell route 装配,业务代码基本不直接 new 它。

### AppMobileShell
- **路径**: `lib/widgets/app_shell/app_mobile_shell.dart`
- **用途**: 移动主壳:底部导航栏 + drawer(可选) + body。
- **required**: `currentPath` · `navGroups` · `child`
- **可选**: `currentIndex` · `onDestinationSelected` · `drawer` · `drawerEnableOpenDragGesture`
- **何时用**: 移动路由树顶层,由 `routes/` 装配。

### AppMobileSubpageShell
- **路径**: `lib/widgets/app_shell/app_mobile_subpage_shell.dart`
- **用途**: 移动**子页**壳(有 AppBar + 返回按钮 + 标题 + `defaultLocation` 回退)。
- **required**: `title` · `child` · (`defaultLocation` 或 `fallbackPath` 二选一,后者已 deprecated)
- **可选**: `currentPath` · `bodyPadding`(默认 `AppPageInsets.compactStandard`)
- **何时用**: 所有移动"从主页面进的二级页"——设置详情、影片详情、切片列表等。**别自己拼 AppBar**。

### AppSidebar / AppSidebarGroup / AppSidebarItem
- **路径**: `lib/widgets/app_shell/app_sidebar.dart`
- **用途**: 桌面左侧导航栏。`AppSidebar` 是整栏,`AppSidebarGroup` 分组,`AppSidebarItem` 是单个 item(支持 `badgeCount` 未读数)。
- **AppSidebar required**: `currentPath` · `navGroups`
- **AppSidebarItem required**: `icon` · `label` · `onTap` · `selected` · `collapsed`;可选 `badgeCount`
- **何时用**: 只有 shell 自己用;新增导航项去改 `routes/nav_groups.dart` 之类的数据源,别直接 new item。

### AppTopBar
- **路径**: `lib/widgets/app_shell/app_top_bar.dart`
- **用途**: 桌面顶部条(标题 + 右侧动作 + 平台窗口拖拽区)。
- **required**: `currentPath` · `config`
- **何时用**: shell 内部使用;业务代码通常通过 `topBarConfig` 声明右侧动作,不 new 它。

### AppWindowDragArea
- **路径**: `lib/widgets/app_shell/app_window_drag_area.dart` (条件导出:desktop / web stub)
- **用途**: 桌面 window_manager 拖拽热区,web 上是空 stub。
- **何时用**: 只在自定义窗口条时用,平台特有,业务侧一般不碰。

## 二、页面容器

### AppPageFrame
- **路径**: `lib/widgets/app_shell/app_page_frame.dart`
- **用途**: 桌面页统一"标题 + eyebrow + description + 滚动 body"框架。
- **required**: `title` · `child`
- **可选**: `eyebrow` · `description` · `scrollController`
- **何时用**: 新增桌面主页时首选。别自己套 `SingleChildScrollView + Padding + Column(标题, 描述, body)`。

### AppContentCard
- **路径**: `lib/widgets/app_shell/app_content_card.dart`
- **用途**: 卡壳容器(标题 + 内容 + 可选 header trailing)。
- **required**: `title` · `child`
- **可选**: `padding` · `titleStyle` · `headerBottomSpacing` · `headerTrailing`
- **何时用**: 页内"分块显示信息"的通用容器(设置项组的父容器、详情页某个 section)。

## 三、设置类容器

### AppSettingsGroup / AppSettingCell / AppSettingIconBox / AppSettingCellChevron
- **路径**: `lib/widgets/app_shell/app_settings_group.dart`
- **用途**: 国内 App 风"设置项组"。`AppSettingsGroup` 是分组(可 header/footer),`AppSettingCell` 是行(左 icon + 标题/副标题 + 右 trailing / chevron),`AppSettingIconBox` 是标题左侧那个圆角图标框,`AppSettingCellChevron` 是右侧">"。
- **AppSettingsGroup required**: `children`;可选 `header` · `footer` · `dividerIndent`
- **AppSettingCell required**: `title`;可选 `icon` · `iconColor` · `subtitle` · `trailing` · `onTap`
- **何时用**: 所有"设置类"页面。桌面 configuration 聚合页、移动 configuration 独立子页,都走它。

### AppSettingsRail
- **路径**: `lib/widgets/app_shell/app_settings_rail.dart`
- **用途**: 桌面设置聚合页左侧那条**分类导航**(垂直 tab)。
- **required**: `items: List<AppSettingsRailItem>` · `selectedIndex` · `onSelected`
- **可选**: `width`(默认 188)
- **何时用**: 只有 configuration 聚合页 shell 用。别用来做别的地方的垂直 tab——那属于 `AppTabBar` 或 sidebar。

## 四、页面顶部说明 / 数据展示

### AppNoticeCard(+ `AppNoticeStat`)
- **路径**: `lib/widgets/app_shell/app_notice_card.dart`
- **用途**: 页面顶部"说明卡 / 概览卡"。
- **required**: `description`
- **可选**: `leadingIcon` · `title` · `stats: List<AppNoticeStat>`(每项 `label` / `value` / `valueSize`)
- **内部规则**:
  - **有 `title` 或非空 `stats` → `lgBorder`**(overview 系);否则 → `mdBorder`(account 提示条系)。
  - **`stats.length >= 4` → 自动 2×2 grid**;1–3 项单排横列。
  - 背景恒 `noticeSurface`。
- **何时用**: 页面顶第一屏"给用户看一眼这里是什么 / 关键数字"。移动 + 桌面都在用。
- **AppNoticeStat**: 数据模型,内部由 `AppStatTile` 渲染。

### AppStatTile
- **路径**: `lib/widgets/app_shell/app_stat_tile.dart`
- **用途**: **迷你数据卡**:数字大字上 / label 小字下(`surfaceCard` + `mdBorder`)。
- **required**: `label` · `value`
- **可选**: `valueSize`(默认 `AppTextSize.s16`,下载器等场景传 s18)
- **何时用**: `AppNoticeCard.stats` 内部即用它;也可以直接摆一排。**强调数字**。
- **和 `AppInfoBlock` 的差异**: **StatTile 强调数字、InfoBlock 强调标签**——语义完全不同,**不合并成 orientation 参数**。

### AppInfoBlock
- **路径**: `lib/widgets/app_shell/app_info_block.dart`
- **用途**: label 小字上 / value 正常下的**只读字段展示**(`surfaceMuted` + `mdBorder`)。
- **required**: `label` · `value`
- **何时用**: 展示"配置项当前值"、"详情键值对"这类"以标签为主"的信息。
- **和 `AppStatTile` 的差异**: 见上一条。

### AppBadge
- **路径**: `lib/widgets/app_shell/app_badge.dart`
- **用途**: 小徽标(6 种 tone × 2 种 size)。
- **required**: `label`
- **可选**: `tone: neutral(默认)|primary|info|warning|error|success` · `size: compact|regular(默认)`
- **何时用**: 卡片右上角状态、行内 tag、列表 item 的 badge。别自己染色 chip。

---

## 相关约定

- Shell / TopBar / Sidebar 是**路由层装配的东西**;业务代码通常不直接 new,而是在 `routes/` 里配 `topBarConfig` / `navGroups`。
- 页面顶部有说明数据 → 首选 `AppNoticeCard`;单纯统计一排 → `AppStatTile` × N 自己 Row;详情区键值对 → `AppInfoBlock`。
- 设置类页面**必须**走 `AppSettingsGroup + AppSettingCell`,别用 `ListTile` / 手写行。
