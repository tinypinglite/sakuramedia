---
outline: [2, 3]
---

# 后台任务

SakuraMedia 宿主内置后台定时任务的作用和默认频率。

## 任务总览

| 任务 | 作用 | 默认频率 |
|---|---|---|
| 订阅女优影片同步 | 抓取已订阅女优的最新影片 | 每天 02:00 |
| 已订阅缺失影片自动下载 | 搜索并提交符合条件的影片资源 | 每天 02:30 |
| 影片热度重算 | 更新影片热度字段 | 每天 00:15 |
| 影片互动数同步 | 回刷评分、想看、评论等互动统计，并联动热度 | 每天 05:00 |
| JavDB 热评同步 | 同步热评和关联影片快照 | 每天 01:20 |
| 合集影片同步 | 同步合集标记 | 每天 01:00 |
| 下载任务状态同步 | 同步所有下载客户端的任务状态到本地 | 每 5 分钟 |
| 已完成下载自动导入 | 把已完成下载交给导入流程 | 每 10 分钟 |
| 115 离线任务对账 | 115 离线任务进度回写、完成导入、超时放弃 | 每 1 分钟 |
| 下载小文件清理 | 把种子里的小文件设为不下载并物理删除 | 每 5 分钟 |
| 媒体文件巡检 | 检查文件是否存在并补视频信息 | 每天 04:00 |
| 媒体缩略图生成 | 为媒体生成缩略图 | 每 30 分钟 |
| 以图搜图索引 | 为待处理缩略图生成向量并入索引 | 每天 00:00 |
| 影片相似度重算 | 离线重算影片相似结果 | 每天 03:30 |
| 以图搜图索引优化 | 维护向量索引并触发后台优化 | 每天 03:00 |
| 推荐时刻生成 | 生成推荐时刻候选列表 | 每天 04:00 |
| 每日推荐生成 | 生成每日推荐快照 | 每天 05:00 |
| GFriends 头像缓存刷新 | 拉取 GFriends 文件树索引到本地缓存 | 每周一 04:00 |
| 活动记录清理 | 清理任务运行记录和已读通知 | 每天 05:30 |
| 115 Cookies 保活 | 探活 115 媒体库 cookies，凭据失效时发通知 | 每 20 分钟 |

## 按任务说明

### 订阅女优影片同步

抓取已订阅女优的最新影片并补进本地库。

默认频率：每天 `02:00`

### 已订阅缺失影片自动下载

为"已订阅但本地还没有媒体"的影片搜索可用资源并提交下载。依赖索引器、下载器和路径映射已正确配置。选种策略随 `[downloads].preferred_client_kinds` 的**首项**切换，详见[常见问题 → 自动下载时，系统怎么选资源？](/faq#auto-download-candidate-selection)

默认频率：每天 `02:30`

### 影片热度重算

更新影片热度字段，被排行榜、排序和部分推荐场景复用。

默认频率：每天 `00:15`

### 影片互动数同步

回刷影片评分、想看数、评论数等互动统计。互动数据变化时联动刷新热度。按影片状态分层挑选候选，不是所有影片按同一节奏同步。

默认频率：每天 `05:00`

分层规则：

- 从未同步过的影片：先同步一次
- 在榜影片（排行榜里还会变动的榜单）：`1` 天间隔
- 上映时间在最近 `60` 天内：每 `2` 天
- 上映时间在 `60` 到 `180` 天之间：每 `7` 天
- 更早或缺少上映日期的影片：不再周期性回刷
- 重新订阅影片时额外触发一次补刷

老片评分和评论基本不动了，跟着每天刷浪费抓取额度。需要更新时重新订阅一次即可。


### JavDB 热评同步

同步热评和关联影片快照。

默认频率：每天 `01:20`

### 合集影片同步

同步合集标记。判定只看番号特征前缀（`[media].others_number_features`），不按影片时长判定。

默认频率：每天 `01:00`

### 下载任务状态同步

同步所有下载客户端（qBittorrent、115 等）的任务状态到本地任务表。

默认频率：每 `5` 分钟

### 已完成下载自动导入

把已完成下载交给导入流程，让文件进入媒体识别、入库和后续增强链路。

默认频率：每 `10` 分钟

### 115 离线任务对账

对账 115 离线下载任务：把远端进度回写本地、完成后触发导入、超时后放弃。没有活跃任务时空转不产生请求。

默认频率：每 `1` 分钟

### 下载小文件清理

有些种子会夹带 sample 预览片、说明图、广告等小文件，做种者少时这些文件可能长期没有上传源，导致种子进度卡在 99%、无法触发自动导入。

任务只处理由本系统添加（带 `sakuramedia` 标签）且未完成的种子。对小于阈值的文件先在 qBittorrent 里设为"不下载"，再物理删除下载暂存目录里的残留文件。

阈值由 `[downloads].small_file_cleanup_threshold_mb` 控制，默认 `256`（MB）。如果正片本身就小于阈值，请调小该值避免误删。

默认频率：每 `5` 分钟

### 媒体文件巡检

检查已有媒体文件是否存在并补视频信息（编码、码率等）。文件不存在时标为无效，信息缺失时补齐。

默认频率：每天 `04:00`

### 媒体缩略图生成

为媒体生成缩略图，是时刻预览和以图搜图的前置数据。

默认频率：每 `30` 分钟

### 以图搜图索引

为待处理缩略图生成向量并入索引。没有这一步，以图搜图拿不到有效结果。

默认频率：每天 `00:00`

### 影片相似度重算

基于影片演员、标签和热度离线预计算相似影片结果。详情页的相似影片列表依赖这一步。

默认频率：每天 `03:30`

### 以图搜图索引优化

压缩或优化向量索引，适合大量缩略图完成索引后整理搜索性能。

默认频率：每天 `03:00`

### 推荐时刻生成

生成"推荐时刻"候选列表（视觉相似、内容相似、热门候选）。

默认频率：每天 `04:00`

### 每日推荐生成

生成每日推荐快照，供发现页展示。

默认频率：每天 `05:00`

### GFriends 头像缓存刷新

拉取 GFriends 文件树索引 JSON 并写入本地磁盘缓存，用于女优头像匹配。

默认频率：每周一 `04:00`

### 活动记录清理

清理活动中心的任务运行记录和已读通知：每个任务保留最近 `activity_task_run_retention_per_key` 条运行记录，已读通知保留最近 `activity_notification_read_retention_days` 天。

默认频率：每天 `05:30`

### 115 Cookies 保活

定期探活 115 媒体库的 cookies（acw_tc WAF token 30 分钟过期），把最新快照回写库配置。长效凭据失效时发通知引导重新扫码。

默认频率：每 `20` 分钟

## 默认 cron 配置

```toml
[scheduler]
enabled = true
log_dir = "/data/logs"

actor_subscription_sync_cron = "0 2 * * *"
subscribed_movie_auto_download_cron = "30 2 * * *"
download_task_sync_cron = "*/5 * * * *"
download_task_auto_import_cron = "*/10 * * * *"
download_small_file_cleanup_cron = "*/5 * * * *"
cloud115_offline_sync_cron = "* * * * *"
movie_collection_sync_cron = "0 1 * * *"
movie_heat_cron = "15 0 * * *"
movie_interaction_sync_cron = "0 5 * * *"
hot_review_sync_cron = "20 1 * * *"
media_file_scan_cron = "0 4 * * *"
media_thumbnail_cron = "*/30 * * * *"
image_search_index_cron = "0 0 * * *"
image_search_optimize_cron = "0 3 * * *"
movie_similarity_recompute_cron = "30 3 * * *"
moment_recommendation_generate_cron = "0 4 * * *"
daily_recommendation_generate_cron = "0 5 * * *"
gfriends_filetree_refresh_cron = "0 4 * * 1"
activity_cleanup_cron = "30 5 * * *"
cloud115_keepalive_cron = "*/20 * * * *"

activity_task_run_retention_per_key = 200
activity_notification_read_retention_days = 3
```

在 `config.toml` 里改过 `[scheduler]` 后以你的配置为准。

## 哪些任务最关键

### 下载链路相关

- `download_task_sync_cron` — 同步下载客户端当前任务状态
- `download_task_auto_import_cron` — 已完成下载自动进入导入流程
- `subscribed_movie_auto_download_cron` — 已订阅且缺资源的影片自动找资源
- `download_small_file_cleanup_cron` — 清理种子夹带的小文件，避免下载卡住
- `cloud115_offline_sync_cron` — 115 离线任务进度回写和完成导入
- `cloud115_keepalive_cron` — 115 cookies 保活，防止凭据过期

### 数据同步相关

- `actor_subscription_sync_cron` — 已订阅女优的影片持续补进来
- `movie_collection_sync_cron` — 合集标记持续同步
- `movie_interaction_sync_cron` — 影片互动统计持续回刷
- `hot_review_sync_cron` — 热评数据更新

### 媒体增强相关

- `media_thumbnail_cron` — 为时刻和图片搜索提供基础数据
- `image_search_index_cron` — 缩略图送进图片搜索索引
- `image_search_optimize_cron` — 索引压缩和优化

### 推荐相关

- `moment_recommendation_generate_cron` — 推荐时刻候选列表
- `daily_recommendation_generate_cron` — 每日推荐快照
- `movie_similarity_recompute_cron` — 详情页相似影片依赖此任务

### 系统维护相关

- `activity_cleanup_cron` — 活动中心任务运行记录和已读通知清理
- `gfriends_filetree_refresh_cron` — GFriends 头像缓存定期刷新

## 任务运行规则

- 通过 `aps <job>` 触发的任务会进入任务中心，可看进度和结果
- 同一任务的手动执行和定时执行互斥，已在跑的任务会拒绝新触发
- 服务重启时回收已中断的任务状态
- 离线计算任务（如影片相似度重算）的结果依赖后台任务跑完，不是请求时即时刷新

## 和配置说明的关系

配置项详见[配置说明](/guide/config)。
