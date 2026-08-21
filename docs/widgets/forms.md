# forms —— 表单输入

## `AppTextField`

路径：`lib/widgets/base/forms/app_text_field.dart`

统一文本输入样式、标签、错误和辅助文案。页面负责 controller、校验和提交时机。

## `AppPasswordField`

路径：`lib/widgets/base/forms/app_password_field.dart`

密码输入和显示/隐藏切换。不要在业务页复制可见性按钮或输入框装饰。

## `AppSelectField<T>`

路径：`lib/widgets/base/forms/app_select_field.dart`

统一选择字段和下拉菜单，支持 regular、compact、mini 尺寸。选项数据由页面提供，组件不负责请求远端选项。

## `AppInfoPill`

路径：`lib/widgets/base/forms/app_info_pill.dart`

展示只读标签和值，适合表单说明、状态或实体元信息，不用于可编辑输入。

## 共同约定

字段 label、错误、必填语义和 focus 行为应由调用页面明确提供。新增表单字段先查已有 token 和组件，不在业务页面写裸边框、圆角和字号。
