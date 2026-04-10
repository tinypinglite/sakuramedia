# 后台任务

这页专门解释 SakuraMedia 后台定时任务的作用、默认频率，以及哪些任务最值得优先关注。

如果你只是第一次部署并确认服务能跑起来，这页不一定要马上细看；但只要你开始关心“为什么系统会自动抓影片、自动导入、自动生成缩略图”，这页就会很有用。

## 后台任务都做什么

当前版本默认启用了后台调度器。下面这张表按当前代码实现整理了每个任务的作用和默认频率：

| 任务 | 作用 | 默认频率 |
|---|---|---|
| 订阅女优影片同步 | 抓取已订阅女优的最新影片 | 每天 02:00 |
| 已订阅缺失影片自动下载 | 搜索并提交符合条件的影片资源 | 每天 02:30 |
| 影片热度重算 | 更新影片热度字段 | 每天 00:15 |
| 排行榜同步 | 同步排行榜数据 | 每天 01:45 |
| JavDB 热评同步 | 同步热评和关联影片快照 | 每天 01:20 |
| 合集影片同步 | 同步合集标记 | 每天 01:00 |
| 下载任务状态同步 | 同步 qBittorrent 任务到本地任务表 | 每 1 分钟 |
| 已完成下载自动导入 | 把已完成下载交给导入流程 | 每 3 分钟 |
| 媒体文件巡检 | 检查文件是否存在并补视频信息 | 每 6 小时 |
| 影片字幕抓取 | 为已订阅影片抓取字幕 | 每 6 小时的第 30 分钟 |
| 媒体缩略图生成 | 为媒体生成缩略图 | 每 5 分钟 |
| 以图搜图索引 | 为待处理缩略图生成向量并入索引 | 每天 00:00 |
| 以图搜图索引优化 | 压缩或优化向量索引 | 每天 03:00 |

## 默认 cron 配置

如果你更习惯直接看 cron，当前默认值如下：

```toml
[scheduler]
enabled = true
log_dir = "/data/logs"

actor_subscription_sync_cron = "0 2 * * *"
subscribed_movie_auto_download_cron = "30 2 * * *"
download_task_sync_cron = "* * * * *"
download_task_auto_import_cron = "*/3 * * * *"
movie_collection_sync_cron = "0 1 * * *"
movie_heat_cron = "15 0 * * *"
ranking_sync_cron = "45 1 * * *"
hot_review_sync_cron = "20 1 * * *"
media_file_scan_cron = "0 */6 * * *"
movie_subtitle_fetch_cron = "30 */6 * * *"
media_thumbnail_cron = "*/5 * * * *"
image_search_index_cron = "0 0 * * *"
image_search_optimize_cron = "0 3 * * *"
```

这些值是当前版本代码里的默认值。只要你在自己的 `config.toml` 里改过 `[scheduler]`，实际频率就应该以你的配置为准。

## 哪些任务最关键

如果你只想先理解系统能不能自动运转，优先看下面这几类任务：

### 下载链路相关

- `download_task_sync_cron`
  保证 SakuraMedia 知道 qBittorrent 当前任务状态
- `download_task_auto_import_cron`
  保证已完成下载能自动进入导入流程
- `subscribed_movie_auto_download_cron`
  保证已订阅且缺资源的影片会自动去找资源

### 数据同步相关

- `actor_subscription_sync_cron`
  保证已订阅女优的影片会持续补进来
- `movie_collection_sync_cron`
  保证合集标记持续同步
- `ranking_sync_cron`
  保证排行榜数据有更新
- `hot_review_sync_cron`
  保证热评数据有更新

### 媒体增强相关

- `media_thumbnail_cron`
  为时刻和图片搜索提供基础数据
- `image_search_index_cron`
  把缩略图真正送进图片搜索索引
- `image_search_optimize_cron`
  负责后续索引压缩和优化

如果这些任务长期不跑，系统虽然还能登录和浏览，但自动化能力会明显打折。

## 什么时候需要改任务频率

默认频率适合先跑通，不建议第一次部署就大改。通常只有下面这些情况，才值得考虑调整：

- NAS 性能比较弱，任务一跑就明显拖慢系统
- 媒体量很大，缩略图和图片索引积压太久
- 下载器任务很多，1 分钟一次同步对你来说太频繁
- 你只想把重任务放到夜间执行

更稳的调整方式是：

1. 先观察几天
2. 一次只改一类任务
3. 优先改缩略图、图片索引这类重任务
4. 下载任务同步和自动导入不要改得太慢

## 哪些任务第一次先别动

如果你现在还处于“刚跑通”的阶段，通常不建议一上来就改：

- 所有 `scheduler` cron
- `media_thumbnail_cron`
- `image_search_index_cron`
- `download_task_sync_cron`
- `download_task_auto_import_cron`

更好的节奏是：

- 先确认任务能正常跑
- 再根据机器性能和数据规模决定是否调整

## 和配置说明的关系

如果你想看：

- 哪些配置项最常改
- `auth`、`metadata`、`image_search` 这些配置组应该怎么理解

可以继续看[配置说明](/guide/config)。
