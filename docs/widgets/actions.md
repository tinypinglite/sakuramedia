# actions —— 按钮系

四件套,**别再自己 wrap `ElevatedButton`/`TextButton`/`IconButton`**。选一个填就完事。

## AppButton
- **路径**: `lib/widgets/actions/app_button.dart`
- **用途**: 实心 / 边框按钮,4 种 variant × 5 种 size。
- **required**: `label`
- **关键可选**: `onPressed` · `icon` · `trailingIcon` · `labelKey` · `variant: primary|secondary(默认)|ghost|danger` · `size: medium|small|xSmall|xxSmall|xxxSmall` · `isLoading` · `isSelected`
- **何时用**: 页面主行动、表单提交、危险操作(danger)、次要操作(ghost)。
- **何时不用**: 纯文字链接 → `AppTextButton`;仅一个图标(工具栏、卡片右上角) → `AppIconButton`。

## AppTextButton
- **路径**: `lib/widgets/actions/app_text_button.dart`
- **用途**: 纯文字按钮(可带图标),支持透明 / muted 背景与 accent 强调色。
- **required**: `label`
- **关键可选**: `onPressed` · `icon` · `trailingIcon` · `size: medium|small|xSmall|xxSmall|xxxSmall` · `isSelected` · `emphasis: normal|accent` · `backgroundStyle: transparent(默认)|muted`
- **何时用**: 卡片内嵌操作、行尾"编辑 / 删除"、`AppSettingsGroup` 尾部"更多"。
- **和 `AppButton` 的边界**: 有背景块 → `AppButton`;纯文字或"文字气泡"感 → `AppTextButton`。

## AppIconButton
- **路径**: `lib/widgets/actions/app_icon_button.dart`
- **用途**: 单图标按钮,统一 hover / selected 态与命中区。
- **required**: `icon`
- **关键可选**: `onPressed` · `tooltip` · `isSelected` · `size: mini|compact(默认)|regular` · `iconColor` / `selectedIconColor` / `backgroundColor` / `selectedBackgroundColor` / `borderColor` / `selectedBorderColor` · `padding` · `borderRadius` · `semanticLabel`
- **何时用**: 工具栏、`AppTopBar` 右侧、卡片右上角、播放器控制条按钮外壳。
- **备注**: 传入的 `Key` 会挂到内部按钮上,方便测试锚定。

## AppInlineActionButton
- **路径**: `lib/widgets/actions/app_inline_action_button.dart`
- **用途**: 极简"嵌行小图标按钮"(hover 态自绘,无背景块),常见在卡片信息条里紧贴文字。
- **required**: `icon` · `onTap`
- **何时用**: `MoviePlayerPlaybackInfo` / 详情页正文中间那种"删除 / 复制"极小图标。
- **和 `AppIconButton` 的边界**: 前者有 hover 背景 / tooltip / size 系统;这个更轻,只在**紧凑排版**中用。别当默认 IconButton 用。

---

## 相关约定

- 按钮上的 `Key` 用 `labelKey` / `fieldKey` / 自己传的 `key`——**改 Key = 破测试**,详见 `lib/widgets/CLAUDE.md` "Widget Key 约定"。
- 危险动作按钮:`AppButton(variant: danger)` 或 `showAppConfirmDialog(danger: true)` 双端一致,别自己染色。
- toast 一律走 `oktoast` + `apiErrorMessage(error, fallback: ...)`,不要用 SnackBar。
