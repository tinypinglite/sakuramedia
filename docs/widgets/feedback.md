# feedback —— 空态 / 错误 / 骨架 / 确认框

列表"四态"(骨架 → 错误 → 空 → 内容)一律走这里的原子件。**不要自己拼**。

## AppEmptyState
- **路径**: `lib/widgets/base/feedback/app_empty_state.dart`
- **用途**: 空态卡:message + 可选 icon + 可选重试按钮。
- **required**: `message`
- **可选**: `icon` · `onRetry` · `retryLabel`(默认 "重试") · `retryKey`
- **何时用**: 列表 / 网格空态。四态容器里"内容为空"这一态永远走它。
- **注意**: 只是**展示**;错误态用 `AppSectionError`(有区分)。

## AppSectionError(桌面)
- **路径**: `lib/widgets/base/feedback/app_section_error.dart`
- **用途**: 桌面端"区块加载失败"提示(无卡壳、左对齐、重试按钮靠左)。
- **required**: `title` · `message` · `onRetry`
- **何时用**: 桌面页里某个 section / grid 加载失败。
- **和移动版的关系**: 是姊妹关系,**不要合并成自适应组件**——见下一条。

## AppMobileSectionError(移动)
- **路径**: `lib/widgets/base/feedback/app_mobile_section_error.dart`
- **用途**: 移动端"区块加载失败":卡壳 + `AppEmptyState(title)` + 居中消息 + 全宽重试按钮。
- **required**: `title` · `message` · `onRetry`
- **可选**: `retryButtonKey`
- **和 `AppSectionError` 的差异**: 桌面无卡壳 / 左对齐;移动有卡壳 / 居中 / 全宽按钮。**共享 `{title, message, onRetry}` 参数命名方便文案复用**,但**不合并成自适应组件**(视觉与交互两端要求不同)。

## AppSectionSkeleton
- **路径**: `lib/widgets/base/feedback/app_section_skeleton.dart`
- **用途**: 桌面通用"多行骨架条"。
- **required**: `lineCount`
- **何时用**: 桌面页 section 加载中态。

## AppSkeletonBlock
- **路径**: `lib/widgets/base/feedback/app_mobile_skeleton.dart`
- **用途**: 基础骨架块(可配 width / height / radius)。默认 `smBorder`,传 `mdBorder` 用于头像块。
- **required**: `height`
- **何时用**: 拼自定义骨架布局的最小积木。

## AppMobileSkeletonCard
- **路径**: `lib/widgets/base/feedback/app_mobile_skeleton.dart`
- **用途**: 移动页"标题 + 副标题 + 一行元数据"骨架卡。
- **何时用**: 直接充列表骨架 item。

## AppMobileSkeletonList
- **路径**: `lib/widgets/base/feedback/app_mobile_skeleton.dart`
- **用途**: 上面那个 Card 的 List 版(默认 3 个 item,可传 `itemBuilder`)。
- **可选**: `itemCount`(默认 3) · `itemBuilder` · `padding`
- **何时用**: 移动列表骨架直接用它,别循环写 `AppSkeletonBlock`。

## showAppConfirmDialog
- **路径**: `lib/widgets/base/feedback/app_confirm_dialog.dart`
- **用途**: **自适应**确认框——一套 API 双端通用。
- **签名**: `Future<bool> showAppConfirmDialog(BuildContext context, { required String title, required String message, String confirmLabel = '确认', String cancelLabel = '取消', bool danger = false, AppConfirmVariant variant = AppConfirmVariant.auto, Future<void> Function()? onConfirm, String failureFallback = '操作失败', Key? dialogKey, Key? cancelKey, Key? confirmKey })`
- **variant**:
  - `auto`(默认): 读 `Provider<AppPlatform?>` → `mobile` = `showAppBottomDrawer`;桌面/web/null = `showDialog + AppDesktopDialog`。
  - `dialog` / `drawer`:显式覆盖。
- **返回类型**: `Future<bool>` **恒非空**(drawer 分支 `?? false`),契约不变。
- **`onConfirm` slot**(推荐):传了 → 点确认时内部把确认按钮置 `isLoading`、禁用取消,`await onConfirm()` 成功后 pop(true);抛异常 → toast(`apiErrorMessage(error, fallback: failureFallback)`) + 恢复按钮 + **不 pop**。
- **何时用**: 任何"确认吗?"弹窗。删除、退出、断开、放弃编辑。**别再手写抽屉+双按钮**。
- **相关**: `AppMobileConfirmActions` 是抽屉里"取消 / 确认"这一条 row 的原子件,通常已由本函数包好了不用你直接调;真要在自定义抽屉里放这条 row 时才用它——见 [sheets-dialogs.md](./sheets-dialogs.md)。

---

## 相关约定

- **四态顺序**: **骨架 → 错误 → 空态(`AppEmptyState`)→ 内容**,顺序固定。见 `lib/widgets/CLAUDE.md` "网格四态容器"段。
- 错误文案统一走 `apiErrorMessage(error, fallback: ...)`,`fallback` 用具体动词(如 "删除下载器失败"),不要 "操作失败" 一把梭。
- 轻量反馈用 `oktoast`(顶层已 wrap `OKToast`),别用 SnackBar。
