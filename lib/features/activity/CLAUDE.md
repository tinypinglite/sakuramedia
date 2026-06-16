# lib/features/activity/ — 通知中心 + 任务中心

通知中心、任务中心(任务运行历史)、资源任务中心。三者共用一套 SSE/bootstrap 基础设施但控制器分离。先读 `lib/features/CLAUDE.md`。

## 三个控制器,生命周期不同

- **`NotificationCenterController`**:**全局常驻**,在 `lib/app/app.dart` 注册为 app 级 `ChangeNotifierProvider`,构造即 `bindSessionStore`(登出 `_teardown` 清空断流,登录自动 `initialize`)。侧边栏未读角标读它(`AppSidebar` `context.watch<NotificationCenterController>().unreadCount`,缺 Provider 防御式返回 null)。**页面只 `context.read/watch`,不要再 new。**
- **`ActivityCenterController`** / **`ResourceTaskCenterController`**:**页面级**,由 `DesktopActivityPage.initState` 创建/销毁。

> "通知"与"活动"是两个独立路由/菜单项(通知独立成菜单)。

## 双 SSE = 两条独立连接,同一端点

`NotificationCenterController` 与 `ActivityCenterController` **各自** `activityApi.streamEvents()` 连 `GET /system/events/stream?after_event_id=N`(**同端点开两条流**),各自只 dispatch 自己关心的事件:通知 controller 只处理 `notification_*`/`notifications_read*`,活动 controller 只处理 `task_run_*`/heartbeat。**改 SSE 行为要同步两个 controller(逻辑近乎复制)。**

- 平台分流(条件导入):IO/桌面走 `ApiClient.getSse`;**Web 走 `_web.dart` 的 `fetch`+`ReadableStream`**(dio 在 Web 不支持流式)。
- 连接状态机 `connecting/live/reconnecting/polling`;重连退避 `[1,2,4,8,16,30]s`;`ActivityEventStreamUnsupportedException`(主要 Web)→ 切 30s 轮询;断线 >2min 重连前先 bootstrap 补齐;heartbeat 维持 live。SSE 批量用 `scheduleMicrotask` 合并避免整页重建。
- **bootstrap**:`GET /system/activity/bootstrap` 一次返回 `latest_event_id` + 通知分页 + `unread_count` + 任务运行,`latestEventId` 作 SSE 的 `after_event_id` 起点(避免漏/重事件)。

## ⚠️ 无感自动已读(展示即已读)——别破坏

- UI 在通知卡片**被渲染**时(`addPostFrameCallback` 里)调 `onNotificationDisplayed(id)` → 进 `_pendingReadIds` → **400ms 去抖**后批量 `POST /system/notifications/read`。**乐观本地先置已读**,未读数以服务端 `unread_count` 为准,失败回滚。**无手动"已读"按钮**(仅"全部已读" `markAllRead`)。
- **`DesktopNotificationsPage` 的 `CustomScrollView` 设 `cacheExtent: 0` 不能删**——否则视口外通知被预构建、未展示就被标已读。
- `onNotificationDisplayed` 必须在 post-frame 回调里调(不能在 build 中改状态)。
- 未读数幂等:`_applyNotificationSnapshot` 按"前后是否未读"增减,防 `notification_created` 把角标加爆。

## 状态字符串是后端契约(注意不一致)

任务用 `running/completed/failed/pending`、触发 `scheduled/manual/startup/internal`、通知 `info/warning/error/reminder`、**资源任务用 `succeeded`(不是 `completed`)**。label 映射散落在 `desktop_activity_page.dart`/`resource_task_pane.dart`/`notification_card.dart`。资源任务按 task_key 分桶缓存(`_buckets`),切 tab 不丢分页。

DTO 用 `_sentinel` 哨兵 copyWith(传 `null`=显式置空,不传=保持)。`buildResourceTaskSlivers`/`buildResourceTaskDetailOverlay` 是**纯 sliver 构建函数**(非 Widget 类),由页面拼进外层 `CustomScrollView`/`Stack`。

## 与测试的关系

`test/features/activity/`:controller 态机、`notification_center_controller`(自动已读去抖/回滚)、stream client、通知/任务卡片 widget。大量稳定 `Key`(`activity-notification-{id}`、`resource-task-record-{recordKey}`、`activity-task-{id}`)是测试锚点,勿轻改。改 token 刷新/会话相关旁路查 `test/core/`。
