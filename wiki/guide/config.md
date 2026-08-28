# 配置说明

配置文件位于 `sakuramedia-data/config/config.toml`。配置中的路径均指容器内路径；provider 自己声明的路径字段按对应 provider 的部署说明填写。

## 配置总览

- 根级：`enable_docs`
- `[database]`
- `[auth]`
- `[media]`
- `[metadata]`
- `[plugins]`
- `[scheduler]`
- `[downloads]`
- `[logging]`
- `[image_search]`
- `[qdrant]`

## `enable_docs`

```toml
enable_docs = false
```

控制是否开启 Swagger / ReDoc 文档页面。普通使用保持 `false`，需要查看 API 文档时再改为 `true`。

## `[database]`

```toml
[database]
engine = "postgres"
url = "postgresql://sakuramedia:sakuramedia@postgres:5432/sakuramedia"
```

| 字段 | 默认值 | 作用 |
|---|---|---|
| `engine` | `postgres` | 数据库类型。当前使用 PostgreSQL。 |
| `url` | `postgresql://sakuramedia:sakuramedia@postgres:5432/sakuramedia` | PostgreSQL 连接串。 |

照抄快速开始中的 compose 时无需修改；使用外部 PostgreSQL 时填写可访问的连接串，并在启动前准备数据库。

## `[auth]`

```toml
[auth]
username = "account"
password = "account"
secret_key = ""
algorithm = "HS256"
access_token_expire_minutes = 43200
refresh_token_expire_minutes = 10080
file_signature_secret = ""
```

| 字段 | 作用 |
|---|---|
| `username` / `password` | 首次登录账号。登录后可在系统设置修改。 |
| `secret_key` | JWT 签名密钥。留空时首次启动自动生成并写入配置。 |
| `algorithm` | JWT 签名算法，默认 `HS256`。 |
| `access_token_expire_minutes` | Access Token 有效期（分钟）。 |
| `refresh_token_expire_minutes` | Refresh Token 有效期（分钟）。 |
| `file_signature_secret` | 媒体、图片和字幕文件签名密钥。留空时首次启动自动生成。 |

## `[media]`

```toml
[media]
allowed_min_video_file_size = 268435456
import_image_root_path = "/data/cache/assets"
max_thumbnail_process_count = 4
media_clip_root_path = "/data/media-clips"
media_clip_max_duration_seconds = 900
media_clip_ffmpeg_timeout_seconds = 120
```

| 字段 | 作用 |
|---|---|
| `allowed_min_video_file_size` | 媒体导入的最小视频体积（字节），默认 256 MB。 |
| `import_image_root_path` | 导入时缓存图片的目录。 |
| `max_thumbnail_process_count` | 缩略图生成的最大并发数。 |
| `media_clip_root_path` | 切片文件存储目录。 |
| `media_clip_max_duration_seconds` | 单个切片允许的最大时长，默认 900 秒。 |
| `media_clip_ffmpeg_timeout_seconds` | 单次 ffmpeg 切片超时，默认 120 秒。 |

影片合集判定由已安装插件负责。进入「系统设置 → 插件」安装、启用并配置对应插件。

## `[metadata]`

```toml
[metadata]
javdb_host = "jdforrepam.com"
gfriends_filetree_url = "https://cdn.jsdelivr.net/gh/xinxin8816/gfriends/Filetree.json"
gfriends_cdn_base_url = "https://cdn.jsdelivr.net/gh/xinxin8816/gfriends"
gfriends_filetree_cache_path = "/data/cache/gfriends/gfriends-filetree.json"
gfriends_filetree_cache_ttl_hours = 168
import_metadata_max_workers = 3
```

| 字段 | 作用 |
|---|---|
| `javdb_host` | JavDB API 域名，不带协议头。 |
| `gfriends_filetree_url` | GFriends 文件树索引地址。 |
| `gfriends_cdn_base_url` | GFriends CDN 根地址。 |
| `gfriends_filetree_cache_path` | 文件树本地缓存路径。 |
| `gfriends_filetree_cache_ttl_hours` | 文件树缓存有效期（小时）。 |
| `import_metadata_max_workers` | 导入影片时抓取元数据的并发线程数。 |

外部站点请求统一使用容器环境变量 `HTTP_PROXY`、`HTTPS_PROXY` 和 `NO_PROXY`。索引器、下载 provider 和媒体 provider 的连接由各自插件配置管理。

## `[plugins]`

```toml
[plugins]
root_dir = "/data/plugins"
enabled = []
job_crons = {}
settings = {}
```

| 字段 | 作用 |
|---|---|
| `root_dir` | 插件安装根目录。 |
| `enabled` | 已启用的插件 ID 列表。 |
| `job_crons` | 插件后台任务的 cron 覆盖值，按插件 ID 分组。 |
| `settings` | 插件私有配置，按插件 ID 分组。 |

插件安装、启用和配置入口是「系统设置 → 插件」；也可以使用[常用命令](/guide/commands)中的 `plugins` 命令。

## `[scheduler]`

这一组控制宿主定时任务。每项值都是 cron 表达式，默认值如下：

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
activity_cleanup_cron = "30 5 * * *"
gfriends_filetree_refresh_cron = "0 4 * * 1"
activity_task_run_retention_per_key = 200
activity_notification_read_retention_days = 3
```

| 字段 | 作用 |
|---|---|
| `enabled` | 是否启用后台定时任务。 |
| `log_dir` | 后台任务日志目录。 |
| `actor_subscription_sync_cron` | 订阅女优影片同步。 |
| `subscribed_movie_auto_download_cron` | 已订阅缺失影片自动下载。 |
| `download_task_sync_cron` | 同步 provider 下载任务状态。 |
| `download_task_auto_import_cron` | 将 provider 已完成任务交给导入流程。 |
| `movie_heat_cron` | 影片热度重算。 |
| `movie_interaction_sync_cron` | 影片互动数同步。 |
| `hot_review_sync_cron` | JavDB 热评同步。 |
| `media_thumbnail_cron` | 媒体缩略图生成。 |
| `image_search_index_cron` | 媒体缩略图向量索引。 |
| `plot_image_search_index_cron` | 剧情图向量索引。 |
| `image_search_optimize_cron` | 图片搜索索引优化。 |
| `movie_similarity_recompute_cron` | 影片相似度重算。 |
| `moment_recommendation_generate_cron` | 推荐时刻生成。 |
| `daily_recommendation_generate_cron` | 每日推荐快照生成。 |
| `activity_cleanup_cron` | 活动中心记录清理。 |
| `gfriends_filetree_refresh_cron` | GFriends 文件树缓存刷新。 |
| `activity_task_run_retention_per_key` | 每个任务键保留的运行记录条数。 |
| `activity_notification_read_retention_days` | 已读通知保留天数。 |

任务详情和手动触发方式见[后台任务](/guide/tasks)。

## `[downloads]`

```toml
[downloads]
subscription_search_fresh_days = 90
subscription_search_stale_attempt_limit = 3
```

| 字段 | 作用 |
|---|---|
| `subscription_search_fresh_days` | 订阅影片搜索结果保持新鲜的天数。 |
| `subscription_search_stale_attempt_limit` | 连续未找到结果后进入等待状态前的尝试次数。 |

索引器与下载器的选择通过索引器绑定关系决定；provider 自己的连接参数在媒体库或下载器配置中填写。

## `[logging]`

```toml
[logging]
level = "INFO"
```

支持 `DEBUG`、`INFO`、`WARNING`、`ERROR`、`CRITICAL`。平时使用 `INFO`，排查问题时临时改为 `DEBUG`。

## `[image_search]`

```toml
[image_search]
inference_base_url = "http://siglip2-embed:8080"
inference_timeout_seconds = 120.0
inference_connect_timeout_seconds = 3.0
inference_api_key = ""
inference_batch_size = 16
session_ttl_seconds = 600
default_page_size = 20
max_page_size = 100
search_scan_batch_size = 100
index_upsert_batch_size = 100
```

这些字段控制 SigLIP2 嵌入服务连接、搜索会话和 Qdrant 索引批处理。默认地址对应快速开始中的 `siglip2-embed` 服务名；只有把嵌入服务部署到其他主机、修改服务名或开启鉴权时，才需要改连接字段。

`index_upsert_batch_size` 控制索引任务每轮分别读取的待索引缩略图和剧情图数量。任务会持续处理，直到两类待索引队列为空；该参数只控制单轮读取量，不限制单次任务的总处理量。

## `[qdrant]`

```toml
[qdrant]
url = "http://qdrant:6333"
api_key = ""
```

`url` 是 Qdrant HTTP API 地址；compose 部署时使用容器内服务名 `qdrant`。启用 Qdrant 鉴权时填写 `api_key`。
