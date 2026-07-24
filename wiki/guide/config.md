# 配置说明
这是一份完整的配置文件说明， 配置文件在`sakuramedia-data/config/config.toml`

如果你还没有把服务跑起来，建议先看“快速开始”。这页更适合已经完成第一次部署、准备继续理解系统行为的用户。


### 路径都要写容器内路径

只要配置项里出现“路径”，默认都应该写容器内看到的路径，而不是宿主机路径。

例如：

- 正确：`/data/cache/assets`
- 正确：`/mnt/volume1/media/sakuramedia`
- 错误：`/Users/xxx/...`

## 配置总览

当前主要配置组有：

- 根级：`enable_docs`
- `[database]`
- `[auth]`
- `[media]`
- `[metadata]`（包含元数据代理）
- `[movie_info_translation]`
- `[plugins]`（可选插件，只能手改配置文件）
- `[scheduler]`
- `[downloads]`
- `[media_import]`
- `[logging]`
- `[image_search]`
- `[qdrant]`

下面按顺序说明。

## `enable_docs`

这个是根级配置，不在任何 section 里。

```toml
enable_docs = false
```

作用：

- 控制是否开启 Swagger / ReDoc 文档页面

建议：

- 普通使用场景保持 `false`
- 只有你需要直接访问后端 API 文档时再改成 `true`

## `[database]`

这一组决定 SakuraMedia 如何连接数据库。当前版本只支持 PostgreSQL。

```toml
[database]
engine = "postgres"
url = "postgresql://sakuramedia:sakuramedia@postgres:5432/sakuramedia"
```

字段说明：

| 字段 | 默认值 | 作用 |
|---|---|---|
| `engine` | `postgres` | 数据库类型，固定为 `postgres` |
| `url` | `postgresql://sakuramedia:sakuramedia@postgres:5432/sakuramedia` | PostgreSQL 连接串 |

### 绝大多数用户不需要动这一节

默认连接串和「快速开始」compose 里内置的 `postgres` 服务完全对齐（服务名、账号、密码、库名都一致），**照抄 compose 部署的话，这一节保持默认就能直接工作**。

内置 `postgres` 服务不对宿主机映射端口，只在 compose 内部网络可见，默认账号密码不会暴露到外部。

### 使用外部 PostgreSQL

只有当你想复用自己已有的 PostgreSQL（比如 NAS 上已经跑着一个 PG 实例）时，才需要改 `url`：

```toml
[database]
engine = "postgres"
url = "postgresql://用户名:密码@192.168.x.x:5432/sakuramedia"
```

注意：

- 数据库需要你自己提前建好（`CREATE DATABASE sakuramedia`），表结构会在容器启动时自动建
- 用外部 PG 后，compose 里内置的 `postgres` 服务可以整段删掉，同时删掉 `sakuramedia` 服务的 `depends_on`

::: warning 从老版本（SQLite / MySQL）升级
新版本已移除 SQLite 和 MySQL 支持。如果你的 `config.toml` 里还是 `engine = "sqlite"` 或 `engine = "mysql"`，服务会在启动时直接报配置错误。请按上面的说明把 `[database]` 改成 PostgreSQL，旧库数据无法迁移.
:::

## `[auth]`

这一组负责默认登录账号、JWT 签名和 token 有效期。

```toml
[auth]
username = "account"
password = "account"
secret_key = "replace-with-a-random-secret-key"
algorithm = "HS256"
access_token_expire_minutes = 43200
refresh_token_expire_minutes = 10080
```

字段说明：

| 字段 | 默认值 | 作用 |
|---|---|---|
| `username` | `account` | 默认登录用户名 |
| `password` | `account` | 默认登录密码 |
| `algorithm` | `HS256` | JWT 签名算法 |
| `access_token_expire_minutes` | `43200` | Access Token 过期时间，单位分钟 |
| `refresh_token_expire_minutes` | `10080` | Refresh Token 过期时间，单位分钟 |

说明：

- `username` 和 `password` 主要用于第一次登录
- 登录后建议在 app 里修改账号密码



## `[media]`

这一组控制媒体识别、标签判断、缩略图生成等和本地媒体处理相关的行为。

```toml
[media]
others_number_features = ["OFJE", "CJOB", "DVAJ", "REBD"]
inner_sub_tags = ["中字", "中文", "字幕组", "-UC", "-C"]
blueray_tags = ["蓝光", "4K", "4k"]
uncensored_tags = ["流出", "uncensored", "無码", "無修正", "UC", "无码", "破解", "UNCENSORED", "-UC", "-U"]
uncensored_prefix = ["PT-", "S2M", "BT", "LAF", "SMD", "SMBD", "SM3D2DBD", "SKY-", "SKYHD", "CWP", "CWDV", "CWBD", "CW3D2DBD", "MKD", "MKBD", "MXBD", "MK3D2DBD", "MCB3DBD", "MCBD", "RHJ", "MMDV"]
allowed_min_video_file_size = 268435456
import_image_root_path = "/data/cache/assets"
subtitle_root_path = "/data/cache/subtitles"
max_thumbnail_process_count = 4
media_clip_root_path = "/data/media-clips"
media_clip_max_duration_seconds = 900
media_clip_ffmpeg_timeout_seconds = 120
```

字段说明：

| 字段 | 作用 |
|---|---|
| `others_number_features` | 合集影片番号特征关键词。合集判定**只看这份番号前缀清单**，不再按影片时长判定 |
| `inner_sub_tags` | 识别“内嵌字幕”的标签关键词 |
| `blueray_tags` | 识别“蓝光 / 高清版本”的标签关键词 |
| `uncensored_tags` | 识别“无码资源”的标签关键词 |
| `uncensored_prefix` | 识别“无码资源”的番号前缀 |
| `allowed_min_video_file_size` | 允许导入的视频最小文件大小，单位**字节**。小于该值的文件会被判定为“文件太小”并跳过导入。默认 `268435456`（= 256 MB），即小于 256MB 的视频不会导入。常见换算：256MB = `268435456`、512MB = `536870912`、1GB = `1073741824`。若导入时提示“文件太小”，按需把该值调小即可。**不建议设为 `0` 或调得过低**：BT 种子常夹带大量垃圾小视频，阈值太低会把它们一并尝试导入，建议不要低于 256MB |
| `import_image_root_path` | 导入时缓存图片的目录 |
| `subtitle_root_path` | 字幕目录，用于整理导入时从影片资源同级目录识别到的字幕文件 |
| `max_thumbnail_process_count` | 缩略图生成任务的最大并发数 |
| `media_clip_root_path` | 用户切片（ffmpeg 切出的独立 mp4）的存储目录；与来源媒体解耦，删除媒体不会删除切片文件，建议单独挂卷持久化 |
| `media_clip_max_duration_seconds` | 用户可圈选的切片最大时长（秒），仅约束圈选区间长度 |
| `media_clip_ffmpeg_timeout_seconds` | 单次 ffmpeg 切片的墙钟超时（秒），坏文件 / 慢挂载卡死时杀进程回收 |

建议：

- 这组配置第一次部署通常不要动
- 只有当你明确知道自己的资源命名、字幕规则或缩略图性能瓶颈时，再调整

## `[metadata]`

这一组控制元数据抓取和 GFriends 头像相关行为。

```toml
[metadata]
javdb_host = "jdforrepam.com"
javdb_username = ""
javdb_password = ""
proxy = ""
gfriends_filetree_url = "https://cdn.jsdelivr.net/gh/xinxin8816/gfriends/Filetree.json"
gfriends_cdn_base_url = "https://cdn.jsdelivr.net/gh/xinxin8816/gfriends"
gfriends_filetree_cache_path = "/data/cache/gfriends/gfriends-filetree.json"
gfriends_filetree_cache_ttl_hours = 168
import_metadata_max_workers = 3
```

字段说明：

| 字段 | 作用 |
|---|---|
| `javdb_host` | JavDB API 域名，不带协议头 |
| `javdb_username` | JavDB 账号，用于抓取需登录的 TOP250 榜单（全部 / 有码 / 无码 / FC2 / 各年度）；留空则不抓 TOP250 |
| `javdb_password` | JavDB 账号密码，与 `javdb_username` 配套使用 |
| `proxy` | DMM 与 GFriends 共用的 HTTP 代理地址；JavDB 默认直连 |
| `gfriends_filetree_url` | GFriends 文件树索引地址 |
| `gfriends_cdn_base_url` | GFriends CDN 根地址 |
| `gfriends_filetree_cache_path` | GFriends 文件树本地缓存路径 |
| `gfriends_filetree_cache_ttl_hours` | 文件树缓存有效期，单位小时 |
| `import_metadata_max_workers` | 导入本地影片时抓取元数据的并发线程数 |

建议：

- 大多数元数据抓取场景只需要配置 `proxy`
- `proxy` 同时用于 DMM 描述抓取和 GFriends 头像资源访问，DMM 需要你自行分流到日本代理节点
- `javdb_host`、GFriends 相关地址通常不建议随便改
- `javdb_username` / `javdb_password` 是可选项，只在需要 JavDB TOP250 榜单时填写；两者都留空时 TOP250 不会被抓取，填错时会在通知中心收到一条登录失败提醒

## `[movie_info_translation]`

这一组控制影片信息翻译任务连接的外部 OpenAI 兼容大模型接口。
当前它由“影片简介翻译”和“影片标题翻译”共用。

```toml
[movie_info_translation]
enabled = false
base_url = "https://ollama.com"
api_key = "填入ollama的api key"
model = "gemma4:31b-cloud"
timeout_seconds = 300
connect_timeout_seconds = 3
```

字段说明：

| 字段 | 作用 |
|---|---|
| `enabled` | 是否启用影片信息翻译任务 |
| `base_url` | OpenAI 兼容大模型接口地址 |
| `api_key` | 大模型接口 API Key |
| `model` | 翻译使用的模型名称 |
| `timeout_seconds` | 翻译请求总超时秒数 |
| `connect_timeout_seconds` | 翻译请求建连超时秒数 |

建议：

- 如果你暂时不需要中文简介和中文标题，可以保持 `enabled = false`
- 真正启用前，先用 [常用命令](/guide/commands) 里的 `test-trans` 验证这个 OpenAI 格式接口是否可用
- 这组配置只影响影片信息翻译，不影响影片原文描述抓取
- 旧配置名 `[movie_desc_translation]` 目前仍兼容，但新配置建议统一写成 `[movie_info_translation]`
- 文档里的 `base_url` 示例当前统一写成 `https://ollama.com`，`model` 示例当前统一写成 `gemma4:31b-cloud`

## `[plugins]`

这一组控制「仓库内插件」的启用。插件是随后端代码一起分发的可选能力，启用后可以往调度器里注入额外的后台任务。

::: tip 绝大多数用户不用管这一节
当前发行版里没有内置可启用的插件，保持默认（不写这一节）即可。这里写出来只是让你知道它存在，以及为什么它在设置页里看不到。
:::

```toml
[plugins]
enabled = ["示例插件ID"]

[plugins.job_crons.示例插件ID]
示例任务名 = "0 5 * * 1"

[plugins.settings.示例插件ID]
# 由插件自己定义的配置
```

字段说明：

| 字段 | 作用 |
|---|---|
| `enabled` | 要启用的插件 ID 列表。**只有列在这里的插件才会被加载**，光有代码或光有配置都不会生效 |
| `job_crons` | 按插件 ID 分组，覆盖该插件所注册任务的 cron；不写就用插件自带的默认 cron |
| `settings` | 按插件 ID 分组的插件私有配置，具体字段由插件自己定义 |

要注意：

- **这一节不走设置页**。插件配置可能含凭据，而且 API 和调度器两个进程要加载同一份注册表，所以它既不能在网页上读、也不能在网页上改，只能手动改 `config.toml`。
- 改完（启用、停用、调 cron、改插件配置）都需要**重启整个 `sakuramedia` 服务**，只重启调度器不够。
- 停用插件不会删掉它已经产生的任务运行记录，历史在活动中心里仍然查得到。
- 插件注册的任务会和内置任务一起出现在任务列表里，运行规则完全一致。

## `[scheduler]`

这一组控制后台定时任务是否开启，以及每个任务的运行频率。

```toml
[scheduler]
enabled = true
log_dir = "/data/logs"
actor_subscription_sync_cron = "0 2 * * *"
subscribed_movie_auto_download_cron = "30 2 * * *"
download_task_sync_cron = "*/5 * * * *"
download_task_auto_import_cron = "*/10 * * * *"
download_small_file_cleanup_cron = "*/5 * * * *"
movie_collection_sync_cron = "0 1 * * *"
movie_heat_cron = "15 0 * * *"
movie_interaction_sync_cron = "0 5 * * *"
ranking_sync_cron = "45 1 * * *"
hot_review_sync_cron = "20 1 * * *"
media_file_scan_cron = "0 4 * * *"
movie_desc_sync_cron = "0 4 * * *"
movie_desc_translation_cron = "15 4 * * *"
movie_title_translation_cron = "20 4 * * *"
media_thumbnail_cron = "*/30 * * * *"
image_search_index_cron = "0 0 * * *"
image_search_optimize_cron = "0 3 * * *"
movie_similarity_recompute_cron = "30 3 * * *"
moment_recommendation_generate_cron = "0 4 * * *"
daily_recommendation_generate_cron = "0 5 * * *"
activity_cleanup_cron = "30 5 * * *"
activity_event_retention_days = 1
activity_task_run_retention_per_key = 200
activity_notification_read_retention_days = 3
```

字段说明：

| 字段 | 作用 |
|---|---|
| `enabled` | 是否启用后台定时任务 |
| `log_dir` | 后台任务日志目录 |
| `actor_subscription_sync_cron` | 订阅女优影片同步频率 |
| `subscribed_movie_auto_download_cron` | 已订阅缺失影片自动下载频率 |
| `download_task_sync_cron` | 下载任务状态同步频率 |
| `download_task_auto_import_cron` | 已完成下载自动导入频率 |
| `download_small_file_cleanup_cron` | 下载小文件清理频率 |
| `movie_collection_sync_cron` | 合集影片同步频率 |
| `movie_heat_cron` | 影片热度重算频率 |
| `movie_interaction_sync_cron` | 影片互动数同步频率；当前默认每天 05:00 执行一次，任务跑起来之后哪些影片真正进入候选，还要看[分层刷新规则](/guide/tasks#影片互动数同步) |
| `ranking_sync_cron` | 排行榜同步频率 |
| `hot_review_sync_cron` | JavDB 热评同步频率 |
| `media_file_scan_cron` | 媒体文件巡检频率 |
| `movie_desc_sync_cron` | 影片原文描述回填频率 |
| `movie_desc_translation_cron` | 影片中文简介翻译频率 |
| `movie_title_translation_cron` | 影片标题翻译频率 |
| `media_thumbnail_cron` | 缩略图生成频率 |
| `image_search_index_cron` | 图片搜索索引生成频率 |
| `image_search_optimize_cron` | 图片搜索索引优化频率 |
| `movie_similarity_recompute_cron` | 影片相似度离线重算频率 |
| `moment_recommendation_generate_cron` | 推荐时刻生成频率 |
| `daily_recommendation_generate_cron` | 每日推荐快照生成频率 |
| `activity_cleanup_cron` | 活动中心数据清理频率 |
| `activity_event_retention_days` | 活动事件保留天数 |
| `activity_task_run_retention_per_key` | 每个任务键保留的运行记录条数 |
| `activity_notification_read_retention_days` | 已读通知保留天数 |

这组配置已经单独拆成了[后台任务](/guide/tasks)页面。  
如果你想看“每个任务具体在做什么、哪些最关键、默认多久跑一次”，建议直接去那一页。

## `[downloads]`

这一组控制下载链路的公共行为：小文件清理、下载器偏好顺序，以及 115 离线下载相关的节流与放弃策略。

::: tip 走[轻量部署](/guide/lightweight-deploy)可以完全忽略这一节
你既没启用 qBittorrent 下载器、也没接 115 离线下载时，这里的所有字段都不会生效，保持默认即可。
:::

```toml
[downloads]
small_file_cleanup_threshold_mb = 256
progress_stream_poll_interval_seconds = 1.0
cloud115_progress_poll_interval_seconds = 8.0
preferred_client_kinds = ["qbittorrent", "cloud115"]
cloud115_offline_abandon_hours = 24
cloud115_rapid_upload_min_interval_seconds = 1.0
```

字段说明：

| 字段 | 默认值 | 作用 |
|---|---|---|
| `small_file_cleanup_threshold_mb` | `256` | 下载任务里小于该体积（MB）的文件会被当作无效文件清理，配合 `[scheduler].download_small_file_cleanup_cron` 定时执行 |
| `progress_stream_poll_interval_seconds` | `1.0` | 下载进度实时推送时，轮询 qBittorrent 的间隔（秒）。取值范围 `0.2`–`10`，调太低只会白白加重 qB Web API 负担 |
| `cloud115_progress_poll_interval_seconds` | `8.0` | 下载进度实时推送时，轮询 115 离线列表的间隔（秒）。取值范围 `2`–`60`，**不允许低于 2 秒**——这是公网 API 且有风控 |
| `preferred_client_kinds` | `["qbittorrent", "cloud115"]` | 下载器类型的全局偏好顺序。一条索引器同时绑了多个下载器时，按这个顺序挑；不在列表里的类型排最后。它只影响挑选顺序，不是白名单，选中的下载器执行失败也**不会**自动换下一个。**把 `cloud115` 提到第一位，还会切换「已订阅缺失影片自动下载」的选种策略**（见 [常见问题](/faq#auto-download-candidate-selection)） |
| `cloud115_offline_abandon_hours` | `24` | 115 离线任务超过这个小时数还没完成，本地就放弃：停止轮询并通知你，但**不会**去清理 115 那边的任务 |
| `cloud115_rapid_upload_min_interval_seconds` | `1.0` | 批量秒传时对 115 接口的全局限速，相邻请求最小间隔（秒）。取值范围 `0`–`10`，`0` 表示关闭限速。115 接口前面有 WAF，阈值大约 1–2 次/秒，默认值就是照这个来的，**不建议调低** |

::: warning 改完要重启 `aps` 进程
`[downloads]` 的生效档位是「重启调度器」。特别是改了 `preferred_client_kinds` 之后，后台自动下载任务要等 `aps` 进程重启才会用上新顺序。
:::

## `[media_import]`

这一组控制可视化导入历史媒体时，目录浏览允许进入的根目录白名单。

```toml
[media_import]
browse_roots = ["/mnt"]
```

字段说明：

| 字段 | 默认值 | 作用 |
|---|---|---|
| `browse_roots` | `["/mnt"]` | 导入已有媒体时，目录浏览 API 能访问的根目录白名单。这也是为什么媒体目录必须挂到容器内的 `/mnt` 下——挂到其他位置，在导入界面里就看不到、也选不到 |

## `[logging]`

这一组控制全局日志等级。

```toml
[logging]
level = "INFO"
```

字段说明：

| 字段 | 默认值 | 作用 |
|---|---|---|
| `level` | `INFO` | 全局日志等级，支持 `DEBUG`、`INFO`、`WARNING`、`ERROR`、`CRITICAL` |

建议：

- 平时保持 `INFO`
- 排查问题时再临时改成 `DEBUG`

## `[image_search]`

这一组控制 JoyTag 推理服务连接、搜索会话和索引任务行为。

```toml
[image_search]
inference_base_url = "http://joytag-infer:8001"
inference_timeout_seconds = 30
inference_connect_timeout_seconds = 3
inference_api_key = ""
inference_batch_size = 16
session_ttl_seconds = 600
default_page_size = 20
max_page_size = 100
search_scan_batch_size = 100
index_upsert_batch_size = 100
optimize_every_records = 5000
optimize_every_seconds = 1800
optimize_on_job_end = true
```

字段说明：

| 字段 | 作用 |
|---|---|
| `inference_base_url` | JoyTag 推理服务地址 |
| `inference_timeout_seconds` | 推理服务总超时秒数 |
| `inference_connect_timeout_seconds` | 推理服务建连超时秒数 |
| `inference_api_key` | 推理服务 Bearer Token |
| `inference_batch_size` | 索引任务调用远端推理时的批大小 |
| `session_ttl_seconds` | 搜索会话有效期 |
| `default_page_size` | 默认每页结果数 |
| `max_page_size` | 最大每页结果数 |
| `search_scan_batch_size` | 为凑满一页结果时的扫描批大小 |
| `index_upsert_batch_size` | 向 Qdrant 批量写入的条数 |
| `optimize_every_records` | 每处理多少条成功记录触发一次分段 optimize |
| `optimize_every_seconds` | 距离上次 optimize 超过多少秒后触发一次分段 optimize |
| `optimize_on_job_end` | 任务结束后是否再执行一次兜底 optimize |

建议：

- 第一次部署最需要关注的是 `inference_base_url`
- 只有在你修改了 `joytag-infer` 服务名、地址或鉴权方式时，才需要改 `inference_api_key`
- `inference_batch_size`、`search_scan_batch_size`、`index_upsert_batch_size`
- `optimize_every_records`、`optimize_every_seconds`、`optimize_on_job_end`
- 这类批量参数和优化参数默认就够用，通常不建议用户手动修改

## `[qdrant]`

这一组控制图片搜索向量库的连接信息，对应 compose 中部署的 Qdrant 服务。

```toml
[qdrant]
url = "http://qdrant:6333"
api_key = ""
```

字段说明：

| 字段 | 作用 |
|---|---|
| `url` | Qdrant HTTP API 地址；compose 部署时默认走容器内部服务名 `qdrant` |
| `api_key` | Qdrant API Key；未启用鉴权时留空 |

