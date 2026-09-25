# feedback —— 加载、错误、空态和确认

## 空态和错误

- `AppEmptyState`：路径 `lib/widgets/base/feedback/app_empty_state.dart`，用于无数据、无匹配结果或无可用功能。
- `AppSectionError`：路径 `lib/widgets/base/feedback/app_section_error.dart`，桌面内容区的错误和重试。
- `AppMobileSectionError`：路径 `lib/widgets/base/feedback/app_mobile_section_error.dart`，移动内容区的错误和重试。

错误态要提供用户能执行的重试或返回动作；没有旧内容时才用整块错误态。

## 骨架和加载

- `AppSkeletonizer`：**首屏骨架的统一入口**（`lib/widgets/base/feedback/app_skeletonizer.dart`）。
  loading 分支用占位数据渲染**同一份真实布局**，外包 `AppSkeletonizer(enabled: isLoading)`
  自动灰化：效果是 `ShimmerEffect` 微光扫过（底色取 `surfaceMuted`、高光取
  `surfaceCard`；系统开启「减少动态效果」时退化为静态 `SolidColorEffect`），
  加载态默认屏蔽子树指针事件、对屏幕阅读器隐藏占位内容；sliver 场景用
  `AppSkeletonizer.sliver`（sliver 子树无法包盒模型节点，不做语义隐藏）。
  品牌底色主行动（如「播放全部」「安装插件」）用 `Skeleton.shade` 随骨架一起灰化。
- 占位数据约定：用真实 DTO 构造、文案取 `BoneMock`、封面 / 图片 URL 传 `null`
  不触发网络请求；每个 feature 的占位工厂放在 `presentation/<feature>_placeholders.dart`。
  加载态渲染真实组件后，`ignorePointers` 会屏蔽交互，回调不会被触发。
- 卡片级整卡收敛：共享卡片内部用 `Skeleton.unite` 包住封面 / 内容区，骨架态下整张卡
  被画成一块 shimmer 圆角块，订阅心、热度、排名、信息按钮、标题行等细碎骨块不再单独
  透出；卡片的边框 / 圆角 / 阴影留在 unite 外层保持可见，非骨架态下 `Skeleton.unite`
  原样渲染。当前用于影片、女优、切片、视频、时刻、合集封面、播放列表横幅和下载任务卡。
  下载任务卡这类自带品牌色进度条的卡片在 unite 外层补 `borderRadius`，避免块变直角。
- 首屏骨架不再使用手写骨架组件；`SliverPagedAsyncSection.skeletonBuilder` 传
  「占位数据 + 真实卡片」并用 `AppSkeletonizer` 灰化。`AppSkeletonBlock` 仅作为
  无真实对应物的小面积占位原子（如加载态工具条的两条灰线）保留，必须包在
  `AppSkeletonizer` 内。卡片的内部加载能力（`isLoading` / `skeletonBuilder`）
  已从网格组件移除：加载由调用方用占位数据处理。
- `AppInlineSpinner`：按钮、卡片或局部异步操作中的小型 loading，随平台自适应。
- `AppFilterUpdateBar`：筛选请求更新中的行内反馈。

骨架只描述布局轮廓：占位数据是 `BoneMock` 文案而非真实业务数据；首屏骨架必须与数据到位后的布局同形，避免列表整片跳变。

## 确认和状态

- `showAppConfirmDialog`：路径 `app_confirm_dialog.dart`，桌面/移动自适应确认弹窗；破坏性动作传 danger 语义。
- `AppStatusChip`：路径 `app_status_chip.dart`，展示有限集合的状态标签。

异步确认动作应使用组件提供的 loading、取消禁用和错误反馈；API 请求仍由调用方或 Provider 负责。

## 页面状态顺序

通常按“初始加载 → 错误/重试 → 空态 → 内容”表达状态。分页加载失败保留已有内容，在列表底部使用分页反馈，不要用整页错误覆盖已有结果。

异步确认窗的关闭按钮遵守请求中的返回限制；长内容可滚动，适配横屏和放大字体。
