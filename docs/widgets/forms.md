# forms —— 表单输入

统一走 `AppXxxField`,聚焦不变色(只有 error 变色),下拉是**自绘上下自适应**——别再套裸 `TextFormField` / `DropdownButton`。

## AppTextField
- **路径**: `lib/widgets/forms/app_text_field.dart`
- **用途**: 单/多行文本输入。
- **常用参数**: `controller` · `focusNode` · `hintText` · `label` · `helperText` · `prefix` / `suffix`(可传 widget,`tightSuffix: true` 贴边) · `obscureText` · `enabled` · `validator` · `keyboardType` · `textInputAction` · `onFieldSubmitted` · `onChanged` · `autovalidateMode` · `maxLines`(默认 1) · `minLines` · `isDense`(默认 true) · `fieldKey`(测试锚点)
- **何时用**: 任何文本输入。
- **备注**: 聚焦**不变色**;error 才变色。想要密码可见切换 → `AppPasswordField`,不要自己叠 suffix。

## AppPasswordField
- **路径**: `lib/widgets/forms/app_password_field.dart`
- **用途**: 密码输入 + 眼睛切换,内置可访问文案("显示密码 / 隐藏密码")。
- **常用参数**: `controller` · `focusNode` · `hintText` · `label` · `helperText` · `enabled` · `validator` · `onFieldSubmitted` · `onChanged` · `autovalidateMode` · `showLabel` / `hideLabel` · `iconButtonSize: AppIconButtonSize` · `isDense` · `fieldKey` · `visibilityButtonKey`
- **何时用**: 所有密码字段(登录、改密、机密 token)。
- **和 `AppTextField(obscureText: true)` 的边界**: 有眼睛切换 → 这个;单纯遮蔽 → 那个。

## AppSelectField&lt;T&gt;
- **路径**: `lib/widgets/forms/app_select_field.dart`
- **用途**: 泛型下拉;**自绘菜单**(不用 Material 默认),自动**上下方向判定**——底部空间不够就向上弹。
- **关键点**: `size: regular|compact|mini` · `value: T?` · `items: List<AppSelectItem<T>>` / builder · `onChanged` · 支持 hint / label / helper。
- **何时用**: 所有单选下拉(排序方向、类型、区域)。
- **何时不用**: 需要级联 / 多选 / 搜索 → 走域内 filter drawer(如 movies/actors 的筛选面板),不要在这个组件上叠功能。
- **注意**: 菜单向上还是向下由内部 `_AppSelectMenuPlacement` 决定,别硬 patch。

## AppInfoPill
- **路径**: `lib/widgets/forms/app_info_pill.dart`
- **用途**: 只读小 chip:`label: value`。
- **required**: `label` · `value`
- **何时用**: 表单页展示"只读且成对"的键值(如"已生效范围 / 全部")。
- **和 `AppInfoBlock` 的边界**: pill 是**行内 chip 感**(横向压缩);`AppInfoBlock` 是"卡片内的信息块"。见 [layout-shell.md](./layout-shell.md)。

---

## 相关约定

- 表单外壳一律用 `AppBottomFormSheet`(移动端底抽屉)或 `AppDesktopDialog`(桌面弹窗)包裹,自己不要再套一遍 `Form + SingleChildScrollView + AnimatedPadding`,参见 [sheets-dialogs.md](./sheets-dialogs.md)。
- 校验 `validator`:失败返回中文错误文案;成功返回 `null`。别用 assert / throw。
- 表单错误 toast:提交失败用 `apiErrorMessage(error, fallback: '保存失败')`。
