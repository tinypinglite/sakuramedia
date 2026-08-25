---
outline: [2, 3]
---

# 后台任务

SakuraMedia 宿主内置定时任务，插件也可以注册自己的任务。任务中心展示运行状态、进度、结果和错误信息。

## 内置任务总览

| 任务 | 作用 | 默认频率 |
|---|---|---|
| 订阅女优影片同步 | 抓取已订阅女优的最新影片 | 每天 02:00 |
| 已订阅缺失影片自动下载 | 搜索并提交符合条件的资源 | 每天 02:30 |
| 影片热度重算 | 更新影片热度 | 每天 00:15 |
| 影片互动数同步 | 同步评分、想看和评论等统计 | 每天 05:00 |
| JavDB 热评同步 | 同步热评和关联影片快照 | 每天 01:20 |
| 下载任务状态同步 | 同步各 provider 下载器的任务状态 | 每 5 分钟 |
| 已完成下载自动导入 | 使用 `completed_source_ref` 将完成任务交给导入流程 | 每 10 分钟 |
| 媒体缩略图生成 | 为可播放媒体生成缩略图 | 每 30 分钟 |
| 以图搜图索引 | 为媒体缩略图生成向量 | 每天 00:00 |
| 剧情图索引 | 为剧情图生成向量 | 每天 00:30 |
| 以图搜图索引优化 | 优化图片搜索向量索引 | 每天 03:00 |
| 影片相似度重算 | 计算影片相似结果 | 每天 03:30 |
| 推荐时刻生成 | 生成推荐时刻候选 | 每天 04:00 |
| 每日推荐生成 | 生成每日推荐快照 | 每天 05:00 |
| GFriends 头像缓存刷新 | 刷新 GFriends 文件树缓存 | 每周一 04:00 |
| 活动记录清理 | 清理任务运行记录和已读通知 | 每天 05:30 |

插件注册的任务会在同一任务中心显示，并使用插件自己的配置和 cron。

## 下载链路任务

### 已订阅缺失影片自动下载

系统为已订阅且还没有可播放媒体的影片查询索引器。候选按后端筛选规则选择后，交给该索引器绑定的第一个下载器；下载器由 provider 提供，具体能力由插件决定。

### 下载任务状态同步

按下载器 provider 的任务接口同步状态。任务记录保存宿主需要的状态和 provider 返回的来源引用。

### 已完成下载自动导入

下载器返回 `completed` 且包含 `completed_source_ref` 后，任务会进入导入队列。导入请求把 `source_ref` 原样交给目标媒体库 provider，由 provider 扫描来源并写入媒体库。

## 媒体与发现任务

- **媒体缩略图生成**：为可播放媒体准备时刻预览和以图搜图所需的缩略图。
- **以图搜图索引 / 剧情图索引**：将待处理图片交给 JoyTag，再写入 Qdrant。
- **以图搜图索引优化**：定期维护向量索引。
- **影片相似度重算**：离线计算详情页的相似影片结果。
- **推荐时刻生成 / 每日推荐生成**：准备发现页和推荐页数据。
- **影片热度重算、互动数同步、JavDB 热评同步**：更新影片的发现和排序数据。
- **GFriends 头像缓存刷新**：下载文件树索引并写入本地缓存。

## 默认 cron 配置

```toml
[scheduler]
enabled = true
log_dir = "/data/logs"

actor_subscription_sync_cron = "0 2 * * *"
subscribed_movie_auto_download_cron = "30 2 * * *"
download_task_sync_cron = "*/5 * * * *"
download_task_auto_import_cron = "*/10 * * * *"
movie_heat_cron = "15 0 * * *"
movie_interaction_sync_cron = "0 5 * * *"
hot_review_sync_cron = "20 1 * * *"
media_thumbnail_cron = "*/30 * * * *"
image_search_index_cron = "0 0 * * *"
plot_image_search_index_cron = "30 0 * * *"
image_search_optimize_cron = "0 3 * * *"
movie_similarity_recompute_cron = "30 3 * * *"
moment_recommendation_generate_cron = "0 4 * * *"
daily_recommendation_generate_cron = "0 5 * * *"
gfriends_filetree_refresh_cron = "0 4 * * 1"
activity_cleanup_cron = "30 5 * * *"

activity_task_run_retention_per_key = 200
activity_notification_read_retention_days = 3
```

## 任务运行规则

- 通过 `aps <job>` 或任务中心触发的任务会进入任务中心。
- 同一任务的手动执行和定时执行互斥，运行中不会重复入队。
- 服务重启会回收已中断的任务状态。
- 下载任务中心可以删除任务；删除时可以让 provider 同步删除远端任务及其文件，具体行为由 provider 决定。
- 任务记录删除只影响本地列表，不会替代媒体库或 provider 的存储管理。

任务 cron 和保留期见[配置说明](/guide/config#scheduler)，插件任务以插件设置为准。
