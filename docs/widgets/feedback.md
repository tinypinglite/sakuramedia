# feedback —— 加载、错误、空态和确认

## 空态和错误

- `AppEmptyState`：路径 `lib/widgets/base/feedback/app_empty_state.dart`，用于无数据、无匹配结果或无可用功能。`variant` 分三档：`page`（页面级）、`section`（区块级）、`inline`（行内单行）；`retryStyle` 决定重试是实色按钮还是文字按钮。
- `AppErrorState`：路径 `lib/widgets/base/feedback/app_error_state.dart`，错误态的唯一入口。页面/区块用 `AppErrorState` + 重试，行内错误用 `AppErrorState.inline`。错误不得再用 `AppEmptyState` 渲染。
- `AppSectionError` / `AppMobileSectionError`：桌面/移动的 section 错误薄包装，保留“桌面无卡壳、移动有卡壳”的平台差异，内部统一 `AppErrorState`。
- `AppInlineErrorBanner`：表单、弹层或没有列表 Header 的页面使用的行内错误条。
- 刷新失败只保留一个通道：有 Header 的列表由 Header 内 `AppFilterUpdateBar` 负责；没有 Header 的页面用 `AppInlineErrorBanner`。同一失败不要同时 toast + bar。

## 骨架和加载

- `AppSkeletonizer`：**首屏骨架的统一入口**（`lib/widgets/base/feedback/app_skeletonizer.dart`）。
  loading 分支用占位数据渲染**同一份真实布局**，外包 `AppSkeletonizer(enabled: isLoading)`
  自动灰化：效果是 `ShimmerEffect` 微光扫过（底色取 `surfaceMuted`、高光取
  `surfaceCard`；系统开启「减少动态效果」时退化为静态 `SolidColorEffect`），
  加载态默认屏蔽子树指针事件、对屏幕阅读器隐藏占位内容；sliver 场景用
  `AppSkeletonizer.sliver`（sliver 子树无法包盒模型节点，不做语义隐藏）。
  容器实色绘制（底色 / 边框 / `BoxDecoration` 阴影，含品牌色与状态色）统一
  `containersColor` 中性化为 `surfaceCard`（不能用骨块底色 `surfaceMuted`，
  否则白底容器上的骨块会同色不可见），骨架内不出现真实颜色；渐变底与
  `Material` 高度阴影不受影响，需要额外灰化的特殊元素仍可用 `Skeleton.shade`。
- 占位数据约定：用真实 DTO 构造、文案取 `BoneMock`、封面 / 图片 URL 传 `null`
  不触发网络请求；每个 feature 的占位工厂放在 `presentation/<feature>_placeholders.dart`。
  加载态渲染真实组件后，`ignorePointers` 会屏蔽交互，回调不会被触发。
- 卡片级整卡收敛：共享卡片内部用 `AppSkeletonUnite`（`app_skeletonizer.dart`，
  **不要直接调用 `Skeleton.unite`**）包住封面 / 内容区，骨架态下整张卡被画成一块
  shimmer 圆角块，订阅心、热度、排名、信息按钮、标题行等细碎骨块不再单独透出；
  卡片的边框 / 圆角 / 阴影留在合并区外层（颜色随 `containersColor` 统一
  中性化为 `surfaceCard`），
  非骨架态下原样渲染。当前用于
  影片、女优、切片、视频、时刻、合集封面、合集成员卡、播放器缩略图 tile、
  播放列表横幅和下载任务卡。
  `borderRadius` 必传且取卡片外层同一个圆角 token：skeletonizer 合并骨块时取合并区
  内「最大后代」的圆角，卡内药丸角标用 `appRadius.pillBorder`（`circular(999)`），
  一旦它成为最大后代，整张卡会被画成椭圆（影片卡热度胶囊曾踩坑）；漏传由
  `test/widgets/base/feedback/skeleton_unite_guard_test.dart` 拦截。
- 纯图片卡（整卡即封面）的缺图 / 首帧占位统一为 `surfaceMuted` 纯色块，不带渐变与
  居中图标：skeletonizer 会把 `Icon` 按文本骨块画成实心方块，任何没被
  `AppSkeletonUnite` 覆盖的居中图标都会让骨架中间多出一块。`MaskedImage` 的
  首帧 / 缺图 / 加载失败占位同样是无图标纯块。
- 首屏骨架不再使用手写骨架组件；`SliverPagedAsyncSection.skeletonBuilder` 传
  「占位数据 + 真实卡片」并用 `AppSkeletonizer` 灰化。`AppSkeletonBlock` 仅作为
  无真实对应物的小面积占位原子（如加载态工具条的两条灰线）保留，必须包在
  `AppSkeletonizer` 内。卡片的内部加载能力（`isLoading` / `skeletonBuilder`）
  已从网格组件移除：加载由调用方用占位数据处理。
- `AppInlineSpinner`：按钮、卡片或局部异步操作中的小型 loading，随平台自适应。
- `AppFilterUpdateBar`：筛选请求更新中的行内反馈。

骨架只描述布局轮廓：占位数据是 `BoneMock` 文案而非真实业务数据；首屏骨架必须与数据到位后的布局同形，避免列表整片跳变。

## 胶囊和徽章

- `AppPill`：`lib/widgets/base/layout/cards/app_pill.dart`，纯展示的胶囊/徽章容器。统一 tone（neutral / muted / primary / info / warning / error / success / selected）、尺寸（compact / regular / prominent）、圆角、内边距和文字层级；业务侧不要再写 `Container + BoxDecoration + Border.all`。需要多段文字或图标时用 `AppPill.custom`。
- `AppPillButton`：同一文件的点击包装，内部走 `AppInteractiveSurface`，并补 button / selected 语义。
- `AppBadge`：`app_badge.dart`，短状态/计数徽章；API 保持 `label + tone + size`，渲染由 `AppPill` 承载。
- `AppStatusChip`：`app_status_chip.dart`，状态标签；业务只提供 `AppStatusChipPalette`（tone + icon），不要在自己那边配背景色/前景色。
- `AppMediaBadge`：`lib/widgets/base/layout/badges/app_media_badge.dart`，压在封面/视频上的无描边烟熏角标；4K/8K、热度、排名共用，只绘制深色渐变，不做背景模糊。
- 选择规则：只读状态用 `AppBadge` / `AppStatusChip`，可点标签用 `AppPillButton`，媒体图上的角标用 `AppMediaBadge`；纯文字说明不要套胶囊。

## 确认和状态

- `showAppConfirmDialog`：路径 `app_confirm_dialog.dart`，桌面/移动自适应确认弹窗；破坏性动作传 danger 语义。

异步确认动作应使用组件提供的 loading、取消禁用和错误反馈；API 请求仍由调用方或 Provider 负责。

## 中心 Toast

- `showToast` / `AppGlassToast`：路径 `lib/widgets/base/feedback/app_toast.dart` 和
  `app_glass_toast.dart`，全站轻量操作反馈的统一入口。保持页面中心展示，默认
  3000ms，短消息为 `overlay` role 的玻璃胶囊，长消息自动换行；不再使用 Toast
  独立的玻璃高光/描边 token。高对比度时回退为同尺寸实色表面。
- 语义明确时传 `tone: AppToastTone.success / warning / error / info`，分别显示
  对勾、警告、错误和信息图标；动态来源或无法判断语义的提示保持默认 `neutral`，
  不要根据文案字符串猜语义。
- 业务调用统一从 `app_toast.dart` 引入 `showToast`，不要直接使用 `oktoast` 的
  文本 Toast。`OKToast` 宿主位于 `MaterialApp.builder` 内，以便 Toast 读取主题、
  文字缩放和高对比度设置。

## 页面状态顺序

通常按“初始加载 → 错误/重试 → 空态 → 内容”表达状态。分页加载失败保留已有内容，在列表底部使用分页反馈，不要用整页错误覆盖已有结果。

异步确认窗的关闭按钮遵守请求中的返回限制；长内容可滚动，适配横屏和放大字体。
