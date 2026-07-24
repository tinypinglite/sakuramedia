# navigation —— Tab / 移动筛选抽屉

三个原子件,足够覆盖"横向切分 + 移动筛选进入"两种交互。

## AppTabBar
- **路径**: `lib/widgets/base/navigation/app_tab_bar.dart`
- **用途**: 通用 tab 条,`PreferredSizeWidget`。**四种 variant 自动分流**。
- **required**: `tabs`
- **可选**: `controller` · `onTap` · `variant: auto|desktop|compact|mobileTop`(默认 auto) · `tabHeight` · `indicatorSize`
- **`variant: auto`**: 读 `Provider<AppPlatform?>`——移动 → `mobileTop` 样式;桌面/web → `desktop` 样式。参考 `feedback/app_confirm_dialog.dart` 的分流风格。
- **何时用**: 任何 tab 场景——列表 tab、详情 tab、批量任务 tab。**不要**用 Material `TabBar`。
- **注意**: 指示器是自绘 `_ThinTabIndicator`。改样式改这里,别在业务侧覆盖。

## AppListHeader(+ `AppListHeaderInfo`)
- **路径**: `lib/widgets/base/navigation/app_list_header.dart`
- **用途**: 列表/分区顶栏,**桌面与移动共用同一条**。固定三段:左「筛选入口」/ 中「只读信息槽」/ 右「操作槽」。
- **筛选入口二选一**(有 assert 守卫):
  - 桌面 → `filterPanelBuilder`(+`filterPanelFooter`),点击**就地展开浮层**;
  - 移动 → `onFilterTap`,点击**弹底部抽屉**。
  两端按钮外观、面板内容、即时生效行为完全一致,只有容器不同。
- **可选**: `filterLabel`(当前筛选摘要,长在入口里) · `filterIcon` · `filterTooltip` · `filterButtonKey` · `informationSlots` · `actionSlots`
- **多选态**: 用命名构造 `AppListHeader.selection(selectionLabel:, onExitSelection:, actionSlots:)` **原地改写整条**——只放退出 / 计数 / 全选,批量动作走 `AppSelectionBottomBar`。
- **注意**: 筛选入口外观**恒定**,不随「当前有没有筛选生效」变色;当前值由 `filterLabel` 表达。`filterLabel` 一律只报**一个主维度**(见各 `XxxFilterState.triggerLabel`)。

## AppFilterEntryButton
- **路径**: `lib/widgets/base/navigation/app_filter_entry_button.dart`
- **用途**: 上面那条顶栏的筛选入口按钮本体:实底胶囊 + 摘要 + 下拉箭头。也用作 `AppFilterPopover.triggerBuilder` 让桌面 trigger 与移动一致。
- **注意**: 视觉胶囊只有 `buttonHeightXs` 高,但**手势区撑满父级高度**(顶栏 44)以满足 iOS HIG 44×44。别把手势挪进胶囊内部。

## AppMobileFilterDrawerScaffold
- **路径**: `lib/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart`
- **用途**: 移动筛选抽屉外壳,**与桌面 `AppFilterPopover` 面板逐行同构**:`Flexible(SingleChildScrollView)` + 滚动区外的 footer。
- **required**: `child`
- **可选**: `footer`(通常是 `AppFilterPanelFooter`,重置在这里) · `scrollViewKey`
- **注意**: **没有标题行、没有确定按钮**——筛选即时生效,关闭靠下拉/点遮罩(对应桌面点面板外部)。

---

## 相关约定

- 路由 tab(切页) → `AppTabBar`;列表顶栏(筛选 / 信息 / 操作) → `AppListHeader`(双端同一条)。
- 平台判定:统一读 `context.watch<AppPlatform?>()`。`AppTabBar(variant: auto)` 已经内部读了,不要在业务侧再判一次。
- 筛选抽屉里的具体筛选控件(Choice / Sort / Chips)由各业务域自建(见 movies / actors / rankings 的 `filter_sections.dart` / `filter_toolbar.dart`),本目录只管外壳。
