# 共享组件索引

这组文档回答三个问题：组件在哪里、适合解决什么问题、什么时候不应该复用它。完整参数和实现以源码为准。

## 目录边界

| 目录 | 职责 | 依赖边界 |
|---|---|---|
| `lib/widgets/base/` | 通用 UI、布局、反馈、媒体和交互原子 | 不依赖 feature 页面和 routes |
| `lib/widgets/shell/` | 桌面、移动和窗口壳层 | 负责应用编排，不承载具体业务流程 |
| `lib/widgets/domain/` | 跨 feature 复用的业务展示件 | 可以依赖必要的 DTO、Provider 数据快照和回调 |

只被一个 feature 使用的组件优先留在该 feature 的 `presentation/widgets/`。共享层的组件需要有真实复用场景，不为未来需求预先抽象。

## 按用途查找

| 文档 | 组件范围 |
|---|---|
| [actions.md](actions.md) | 按钮、文字按钮、图标按钮、行内操作、开关 |
| [forms.md](forms.md) | 文本框、密码框、选择框、只读信息块 |
| [feedback.md](feedback.md) | 空态、错误、骨架、加载、状态徽标、确认 |
| [sheets-dialogs.md](sheets-dialogs.md) | 对话框、底部抽屉、表单 sheet、上下文菜单、筛选浮层 |
| [layout-shell.md](layout-shell.md) | 页面壳层、导航、内容卡、设置分组、统计块 |
| [navigation.md](navigation.md) | Tab、列表头、筛选入口、移动筛选容器 |
| [data-loading.md](data-loading.md) | 刷新、分页、总数、自适应网格、多选 |
| [media-images.md](media-images.md) | 远端图片、全屏、图片操作菜单、媒体预览 |
| [media-player.md](media-player.md) | 视频播放器、缩略图、合集连播和播放器控制 |
| [domain-widgets.md](domain-widgets.md) | 影片、女优、切片、合集、时刻、播放列表、搜索等业务展示件 |

## 使用规则

- 新页面先查本索引，再查对应源码和测试。
- 基础组件的 token、颜色、间距和尺寸来自 `lib/theme.dart`。
- 组件文档只记录当前存在的组件；删除、移动或重命名组件时同步更新对应分册。
- 文档不记录迁移批次、历史 bug、旧类名或未来规划。
