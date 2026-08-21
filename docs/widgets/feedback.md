# feedback —— 加载、错误、空态和确认

## 空态和错误

- `AppEmptyState`：路径 `lib/widgets/base/feedback/app_empty_state.dart`，用于无数据、无匹配结果或无可用功能。
- `AppSectionError`：路径 `lib/widgets/base/feedback/app_section_error.dart`，桌面内容区的错误和重试。
- `AppMobileSectionError`：路径 `lib/widgets/base/feedback/app_mobile_section_error.dart`，移动内容区的错误和重试。

错误态要提供用户能执行的重试或返回动作；没有旧内容时才用整块错误态。

## 骨架和加载

- `AppSectionSkeleton`：桌面 section 骨架。
- `AppSkeletonBlock`、`AppMobileSkeletonCard`、`AppMobileSkeletonList`：移动页面和局部占位。
- `AppCoverCardSkeleton`：封面网格占位。
- `AppInlineSpinner`：按钮、卡片或局部异步操作中的小型 loading。
- `AppFilterUpdateBar`：筛选请求更新中的行内反馈。

文件均位于 `lib/widgets/base/feedback/`。骨架只描述布局轮廓，不应把真实业务数据写进组件。

## 确认和状态

- `showAppConfirmDialog`：路径 `app_confirm_dialog.dart`，桌面/移动自适应确认弹窗；破坏性动作传 danger 语义。
- `AppStatusChip`：路径 `app_status_chip.dart`，展示有限集合的状态标签。

异步确认动作应使用组件提供的 loading、取消禁用和错误反馈；API 请求仍由调用方或 Provider 负责。

## 页面状态顺序

通常按“初始加载 → 错误/重试 → 空态 → 内容”表达状态。分页加载失败保留已有内容，在列表底部使用分页反馈，不要用整页错误覆盖已有结果。
