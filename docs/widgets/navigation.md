# navigation —— Tab / 移动筛选抽屉

三个原子件,足够覆盖"横向切分 + 移动筛选进入"两种交互。

## AppTabBar
- **路径**: `lib/widgets/navigation/app_tab_bar.dart`
- **用途**: 通用 tab 条,`PreferredSizeWidget`。**四种 variant 自动分流**。
- **required**: `tabs`
- **可选**: `controller` · `onTap` · `variant: auto|desktop|compact|mobileTop`(默认 auto) · `tabHeight` · `indicatorSize`
- **`variant: auto`**: 读 `Provider<AppPlatform?>`——移动 → `mobileTop` 样式;桌面/web → `desktop` 样式。参考 `feedback/app_confirm_dialog.dart` 的分流风格。
- **何时用**: 任何 tab 场景——列表 tab、详情 tab、批量任务 tab。**不要**用 Material `TabBar`。
- **注意**: 指示器是自绘 `_ThinTabIndicator`。改样式改这里,别在业务侧覆盖。

## AppMobileTabHeader(+ `AppMobileTabChip`)
- **路径**: `lib/widgets/navigation/app_mobile_tab_header.dart`
- **用途**: 移动端"chip 组 + 右侧筛选按钮"顶部条。跟 `AppTabBar(mobileTop)` **不是同一种**——它是**并列 chips 直接切数据**(不是路由 tab),右侧可点开筛选抽屉。
- **required**: `chips: List<AppMobileTabChip>`(每个 chip 有 `label` / `isActive` / `onTap` / `key`)
- **可选**: `onFilterTap` · `filterIcon`(默认 `Icons.tune_rounded`) · `filterTooltip` · `filterButtonKey` · `trailing`
- **何时用**: 移动"这一屏内切几组数据 + 需要筛选"——比如 overview 移动版下的女优 / 影片 tab 切换。

## AppMobileFilterDrawerScaffold
- **路径**: `lib/widgets/navigation/app_mobile_filter_drawer_scaffold.dart`
- **用途**: 移动**筛选抽屉的通用外壳**:标题 + 内容 + 底部"重置 / 确定"按钮。
- **required**: `title` · `onReset` · `onConfirm` · `child`
- **可选**: `confirmLabel`(默认 "确定") · `resetLabel`(默认 "重置") · `resetButtonKey` / `confirmButtonKey`
- **何时用**: 移动筛选抽屉 body(点 `AppMobileTabHeader` 的筛选按钮弹出的那个)。**别自己写外壳**,只写 body 内容。

---

## 相关约定

- 路由 tab(切页) → `AppTabBar`;数据切换 tab(不切页) → `AppMobileTabHeader`(移动)或直接 `AppTabBar(desktop)`(桌面)。
- 平台判定:统一读 `context.watch<AppPlatform?>()`。`AppTabBar(variant: auto)` 已经内部读了,不要在业务侧再判一次。
- 筛选抽屉里的具体筛选控件(Choice / Sort / Chips)由各业务域自建(见 movies / actors / rankings 的 `filter_sections.dart` / `filter_toolbar.dart`),本目录只管外壳。
