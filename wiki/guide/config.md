# 配置说明

这页按当前后端代码实现，整理 `config.toml` 中所有主要配置组的作用和常见使用方式。

如果你还没有把服务跑起来，建议先看“快速开始”。这页更适合已经完成第一次部署、准备继续理解系统行为的用户。

## 先知道这几件事

### 配置文件放在哪里

在 Docker 部署场景下，SakuraMedia 读取的是容器内的：

```bash
/data/config/config.toml
```

通常它对应宿主机上的：

```bash
./docker-data/config/config.toml
```

### 路径都要写容器内路径

只要配置项里出现“路径”，默认都应该写容器内看到的路径，而不是宿主机路径。

例如：

- 正确：`/data/db/sakuramedia.db`
- 正确：`/mnt/volume1/media/sakuramedia`
- 错误：`/Users/xxx/...`

### 哪些配置第一次最值得关心

第一次部署时，通常优先关注这几组：

- `enable_docs`
- `database`
- `auth`
- `metadata`
- `movie_desc_translation`（如果你准备启用简介翻译）
- `image_search`
- `scheduler`

其他配置组大多偏进阶，不建议一上来就改。

## 配置总览

当前主要配置组有：

- 根级：`enable_docs`
- `[database]`
- `[auth]`
- `[media]`
- `[metadata]`
- `[movie_desc_translation]`
- `[scheduler]`
- `[logging]`
- `[indexer_settings]`
- `[image_search]`
- `[lancedb]`

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

这一组决定 SakuraMedia 使用什么数据库，以及如何连接数据库。

```toml
[database]
engine = "sqlite"
path = "/data/db/sakuramedia.db"
charset = "utf8mb4"
url = ""
```

字段说明：

| 字段 | 默认值 | 作用 |
|---|---|---|
| `engine` | `sqlite` | 数据库类型，支持 `sqlite`、`mysql`、`postgres` |
| `path` | `/data/db/sakuramedia.db` | SQLite 数据库文件路径，仅 `sqlite` 生效 |
| `charset` | `utf8mb4` | MySQL 字符集，仅 `mysql` 生效 |
| `url` | `""` | MySQL / PostgreSQL 连接串 |

### `database.pragmas`

这是 SQLite 专用的附加配置。

```toml
[database.pragmas]
foreign_keys = 1
```

当前默认只用了：

- `foreign_keys = 1`
  开启 SQLite 外键约束

### 数据库怎么选

建议：

- 临时试跑：`sqlite`
- 长期使用：`postgres`
- 已经有稳定的 MySQL 环境：`mysql`

不建议把 `sqlite` 作为正式长期方案，尤其是你准备长期积累数据时，更推荐 PostgreSQL。

示例：

SQLite：

```toml
[database]
engine = "sqlite"
path = "/data/db/sakuramedia.db"
charset = "utf8mb4"
url = ""
```

MySQL：

```toml
[database]
engine = "mysql"
path = "/data/db/sakuramedia.db"
charset = "utf8mb4"
url = "mysql://sakuramedia:change-me@mysql:3306/sakuramedia"
```

PostgreSQL：

```toml
[database]
engine = "postgres"
path = "/data/db/sakuramedia.db"
charset = "utf8mb4"
url = "postgresql://sakuramedia:change-me@postgres:5432/sakuramedia"
```

## `[auth]`

这一组负责默认登录账号、JWT 签名和资源签名行为。

```toml
[auth]
username = "account"
password = "account"
secret_key = "replace-with-a-random-secret-key"
algorithm = "HS256"
access_token_expire_minutes = 43200
refresh_token_expire_minutes = 10080
file_signature_expire_seconds = 900
```

字段说明：

| 字段 | 默认值 | 作用 |
|---|---|---|
| `username` | `account` | 默认登录用户名 |
| `password` | `account` | 默认登录密码 |
| `secret_key` | 内置默认值 | JWT 签名密钥，必须改 |
| `algorithm` | `HS256` | JWT 签名算法 |
| `access_token_expire_minutes` | `43200` | Access Token 过期时间，单位分钟 |
| `refresh_token_expire_minutes` | `10080` | Refresh Token 过期时间，单位分钟 |
| `file_signature_expire_seconds` | `900` | 资源文件签名链接有效期，单位秒 |

说明：

- `username` 和 `password` 主要用于第一次登录
- 登录后建议在 app 里修改账号密码
- `secret_key` 一定要换成自己的随机字符串，建议至少 32 位
- `algorithm`、token 过期时间一般不需要第一次就改

补充：

- 代码里还有一个 `file_signature_secret`
- 这个值默认由系统自动生成，通常不需要手动配置
- app 内更新设置时，这个字段也不会按普通配置项一样写回 `config.toml`

## `[media]`

这一组控制媒体识别、标签判断、缩略图生成等和本地媒体处理相关的行为。

```toml
[media]
others_number_features = ["OFJE", "CJOB", "DVAJ", "REBD"]
inner_sub_tags = ["中字", "中文", "字幕组", "-UC", "-C"]
blueray_tags = ["蓝光", "4K", "4k"]
uncensored_tags = ["流出", "uncensored", "無码", "無修正", "UC", "无码", "破解", "UNCENSORED", "-UC", "-U"]
uncensored_prefix = ["PT-", "S2M", "BT", "LAF", "SMD", "SMBD", "SM3D2DBD", "SKY-", "SKYHD", "CWP", "CWDV", "CWBD", "CW3D2DBD", "MKD", "MKBD", "MXBD", "MK3D2DBD", "MCB3DBD", "MCBD", "RHJ", "MMDV"]
allowed_min_video_file_size = 1073741824
import_image_root_path = "/data/cache/assets"
subtitle_root_path = "/data/cache/subtitles"
max_thumbnail_process_count = 4
```

字段说明：

| 字段 | 作用 |
|---|---|
| `others_number_features` | 合集影片番号特征关键词 |
| `inner_sub_tags` | 识别“内嵌字幕”的标签关键词 |
| `blueray_tags` | 识别“蓝光 / 高清版本”的标签关键词 |
| `uncensored_tags` | 识别“无码资源”的标签关键词 |
| `uncensored_prefix` | 识别“无码资源”的番号前缀 |
| `allowed_min_video_file_size` | 允许导入的视频最小文件大小，单位字节 |
| `import_image_root_path` | 导入时缓存图片的目录 |
| `subtitle_root_path` | 字幕文件存储目录 |
| `max_thumbnail_process_count` | 缩略图生成任务的最大并发数 |

建议：

- 这组配置第一次部署通常不要动
- 只有当你明确知道自己的资源命名、字幕规则或缩略图性能瓶颈时，再调整

## `[metadata]`

这一组控制元数据抓取和 GFriends 头像相关行为。

```toml
[metadata]
javdb_host = "apidd.btyjscl.com"
proxy = ""
dmm_proxy = ""
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
| `proxy` | GFriends 使用的 HTTP 代理地址 |
| `dmm_proxy` | DMM 描述抓取使用的 HTTP 代理地址 |
| `gfriends_filetree_url` | GFriends 文件树索引地址 |
| `gfriends_cdn_base_url` | GFriends CDN 根地址 |
| `gfriends_filetree_cache_path` | GFriends 文件树本地缓存路径 |
| `gfriends_filetree_cache_ttl_hours` | 文件树缓存有效期，单位小时 |
| `import_metadata_max_workers` | 导入本地影片时抓取元数据的并发线程数 |

建议：

- 大多数场景只会关心 `proxy`
- `dmm_proxy` 只用于 DMM 描述抓取链路，应该配置可访问 DMM 的日本 IP 代理
- 如果 `dmm_proxy` 不是日本 IP，影片原文描述抓取可能失败或结果不稳定
- 如果头像下载正常，`proxy` 可以保持空
- `javdb_host`、GFriends 相关地址通常不建议随便改

## `[movie_desc_translation]`

这一组控制影片简介翻译任务连接的外部 OpenAI 兼容大模型接口。

```toml
[movie_desc_translation]
enabled = false
base_url = "http://localhost:8000"
api_key = ""
model = "gpt-4o-mini"
timeout_seconds = 300
connect_timeout_seconds = 3
```

字段说明：

| 字段 | 作用 |
|---|---|
| `enabled` | 是否启用影片简介翻译任务 |
| `base_url` | OpenAI 兼容大模型接口地址 |
| `api_key` | 大模型接口 API Key |
| `model` | 翻译使用的模型名称 |
| `timeout_seconds` | 翻译请求总超时秒数 |
| `connect_timeout_seconds` | 翻译请求建连超时秒数 |

建议：

- 如果你暂时不需要中文简介，可以保持 `enabled = false`
- 真正启用前，先用 [常用命令](/guide/commands) 里的 `test-trans` 验证这个 OpenAI 格式接口是否可用
- 这组配置只影响简介翻译，不影响影片原文描述抓取

## `[scheduler]`

这一组控制后台定时任务是否开启，以及每个任务的运行频率。

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
movie_interaction_sync_cron = "0 5 * * *"
ranking_sync_cron = "45 1 * * *"
hot_review_sync_cron = "20 1 * * *"
media_file_scan_cron = "0 */6 * * *"
movie_desc_sync_cron = "0 4 * * *"
movie_desc_translation_cron = "15 4 * * *"
movie_subtitle_fetch_cron = "30 */6 * * *"
media_thumbnail_cron = "*/5 * * * *"
image_search_index_cron = "0 0 * * *"
image_search_optimize_cron = "0 3 * * *"
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
| `movie_collection_sync_cron` | 合集影片同步频率 |
| `movie_heat_cron` | 影片热度重算频率 |
| `movie_interaction_sync_cron` | 影片互动数同步频率 |
| `ranking_sync_cron` | 排行榜同步频率 |
| `hot_review_sync_cron` | JavDB 热评同步频率 |
| `media_file_scan_cron` | 媒体文件巡检频率 |
| `movie_desc_sync_cron` | 影片原文描述回填频率 |
| `movie_desc_translation_cron` | 影片中文简介翻译频率 |
| `movie_subtitle_fetch_cron` | 字幕抓取频率 |
| `media_thumbnail_cron` | 缩略图生成频率 |
| `image_search_index_cron` | 图片搜索索引生成频率 |
| `image_search_optimize_cron` | 图片搜索索引优化频率 |

这组配置已经单独拆成了[后台任务](/guide/tasks)页面。  
如果你想看“每个任务具体在做什么、哪些最关键、默认多久跑一次”，建议直接去那一页。

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

## `[indexer_settings]`

这一组控制当前使用的索引器类型和 Jackett API Key。

```toml
[indexer_settings]
type = "jackett"
api_key = "change-me"
```

字段说明：

| 字段 | 默认值 | 作用 |
|---|---|---|
| `type` | `jackett` | 索引器类型，当前只支持 `jackett` |
| `api_key` | `change-me` | Jackett API Key |

需要注意：

- `type` 和 `api_key` 持久化在 `config.toml`
- `indexers` 明细本身主要存储在数据库里
- 这组配置可以在 app 里修改，修改后会覆盖掉 `config.toml` 中的对应内容

完整示例里可能还会看到：

```toml
[[indexer_settings.indexers]]
name = "mteam"
url = "http://127.0.0.1:9117/api/v2.0/indexers/mteam/results/torznab/"
kind = "pt"
```

这些属于具体 indexer 列表，不是第一次部署阶段必须手写的内容，通常更适合在 app 里维护。

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
| `index_upsert_batch_size` | 向 LanceDB 批量写入的条数 |
| `optimize_every_records` | 每处理多少条成功记录触发一次分段 optimize |
| `optimize_every_seconds` | 距离上次 optimize 超过多少秒后触发一次分段 optimize |
| `optimize_on_job_end` | 任务结束后是否再执行一次兜底 optimize |

建议：

- 第一次部署最需要关注的是 `inference_base_url`
- 只有在你修改了 `joytag-infer` 服务名、地址或鉴权方式时，才需要改 `inference_api_key`
- `inference_batch_size`、`search_scan_batch_size`、`index_upsert_batch_size`
- `optimize_every_records`、`optimize_every_seconds`、`optimize_on_job_end`
- 这类批量参数和优化参数默认就够用，通常不建议用户手动修改

## `[lancedb]`

这一组控制图片搜索使用的 LanceDB 本地索引。

```toml
[lancedb]
uri = "/data/indexes/image-search"
table_name = "media_thumbnail_vectors"
vector_dtype = "float16"
distance_metric = "cosine"
vector_index_type = "ivf_rq"
vector_index_num_partitions = 512
vector_index_num_bits = 1
vector_index_num_sub_vectors = 96
scalar_index_columns = ["movie_id"]
```

字段说明：

| 字段 | 作用 |
|---|---|
| `uri` | LanceDB 本地目录 |
| `table_name` | LanceDB 表名 |
| `vector_dtype` | 向量数据类型 |
| `distance_metric` | 距离度量方式 |
| `vector_index_type` | 向量索引类型 |
| `vector_index_num_partitions` | 向量索引分区数 |
| `vector_index_num_bits` | RQ / PQ 相关索引参数 |
| `vector_index_num_sub_vectors` | 子向量数量 |
| `scalar_index_columns` | 标量索引字段列表 |

建议：

- 这组配置属于图片搜索底层索引参数，默认就按内置值使用即可
- 普通部署场景下不建议用户手动修改
- 即使你在排查图片搜索问题，也通常应先检查数据、任务和推理服务，再考虑动这组配置

## 哪些配置第一次先别动

如果你现在还处于“刚跑通”的阶段，通常不建议一上来就改：

- `[media]`
- `[lancedb]`
- `[image_search]` 里的批量参数和优化参数
- `[scheduler]` 里的 cron
- `[auth]` 里的 token 过期时间和签名算法
- `[logging]` 以外的大部分高级项

更稳的节奏是：

1. 先把服务跑起来
2. 先确认登录、搜索、下载器配置、在线搜索都正常
3. 再按实际问题去改配置

## 完整配置示例

下面这份示例按当前后端代码默认值整理，适合拿来做完整参考模板。

```toml
# !!!! 注意配置文件中所有涉及到路径的配置项都应该是用容器内的实际路径，不是宿主机的路径 !!!!

# 是否启 Swagger / ReDoc 文档页面。
enable_docs = false

[database]
# 数据库类型，可选值：sqlite、mysql、postgres。
engine = "sqlite"
# SQLite 数据库文件路径；仅当 engine=sqlite 时生效。
path = "/data/db/sakuramedia.db"
# MySQL 连接字符集；仅当 engine=mysql 时生效。
charset = "utf8mb4"
# MySQL / Postgres 连接串；仅当 engine=mysql 或 postgres 时生效。
# 示例：
# mysql://user:password@127.0.0.1:3306/sakuramedia
# postgresql://user:password@127.0.0.1:5432/sakuramedia
url = ""

[auth]
# 默认登录用户名。
username = "account"
# 默认登录密码。
password = "account"
# JWT 签名密钥，必须改成你自己的随机字符串。
secret_key = "replace-with-a-random-secret-key"
# JWT 签名算法。
algorithm = "HS256"
# Access Token 过期时间，单位：分钟。
access_token_expire_minutes = 43200
# Refresh Token 过期时间，单位：分钟。
refresh_token_expire_minutes = 10080
# 资源文件签名链接有效期，单位：秒。
file_signature_expire_seconds = 900

[media]
# 合集影片的“番号特征”的关键词列表，比如 OFJE 等。
others_number_features = ["OFJE", "CJOB", "DVAJ", "REBD"]
# 识别为“内嵌字幕”的标签关键词。
inner_sub_tags = ["中字", "-C", "-UC", "字幕组", "中文"]
# 识别为“蓝光 / 高清版本”的标签关键词。
blueray_tags = ["4K", "4k", "蓝光"]
# 识别为“无码资源”的标签关键词。
uncensored_tags = [
  "無修正",
  "UC",
  "-UC",
  "UNCENSORED",
  "-U",
  "流出",
  "uncensored",
  "无码",
  "無码",
  "破解",
]
# 识别为“无码资源”的番号前缀。
uncensored_prefix = [
  "CWDV",
  "MK3D2DBD",
  "RHJ",
  "CWP",
  "MMDV",
  "LAF",
  "SMD",
  "SMBD",
  "MKD",
  "MCB3DBD",
  "MKBD",
  "CWBD",
  "S2M",
  "CW3D2DBD",
  "MXBD",
  "SM3D2DBD",
  "PT-",
  "BT",
  "SKYHD",
  "SKY-",
  "MCBD",
]
# 允许导入的视频最小文件大小，单位：字节；设为 0 表示不限制。
allowed_min_video_file_size = 1073741824
# 导入时缓存图片的目录。
import_image_root_path = "/data/cache/assets"
# 字幕文件存储目录。
subtitle_root_path = "/data/cache/subtitles"
# 媒体缩略图生成任务的最大并发数。
max_thumbnail_process_count = 4

[metadata]
# JavDB API 域名，不带协议头。
javdb_host = "apidd.btyjscl.com"
# 仅 GFriends 使用的代理地址；JavDB 固定直连。不需要代理时留空。
# 示例：http://192.168.1.1:7890
proxy = ""
# DMM 页面抓取代理地址。不需要代理时留空；这里应配置可访问 DMM 的日本 IP 代理。
dmm_proxy = ""
# GFriends 文件树索引地址。
gfriends_filetree_url = "https://cdn.jsdelivr.net/gh/xinxin8816/gfriends/Filetree.json"
# GFriends CDN 根地址，用于拼接演员图片资源链接。
gfriends_cdn_base_url = "https://cdn.jsdelivr.net/gh/xinxin8816/gfriends"
# GFriends 文件树本地缓存路径。
gfriends_filetree_cache_path = "/data/cache/gfriends/gfriends-filetree.json"
# GFriends 文件树缓存有效期，单位：小时。
gfriends_filetree_cache_ttl_hours = 168
# 导入本地影片时，按番号抓取 JavDB 元数据的并发线程数。
import_metadata_max_workers = 3

[scheduler]
# 是否启用定时任务。
enabled = true
# 定时任务日志目录。
log_dir = "/data/logs"
# 订阅女优影片同步任务 cron 表达式。
actor_subscription_sync_cron = "0 2 * * *"
# 已订阅缺失影片自动下载 cron 表达式。
subscribed_movie_auto_download_cron = "30 2 * * *"
# 下载任务状态同步 cron 表达式。
download_task_sync_cron = "* * * * *"
# 已完成下载自动导入 cron 表达式。
download_task_auto_import_cron = "*/3 * * * *"
# 合集影片同步 cron 表达式。
movie_collection_sync_cron = "0 1 * * *"
# 影片热度重算 cron 表达式。
movie_heat_cron = "15 0 * * *"
# 影片互动数同步 cron 表达式。
movie_interaction_sync_cron = "0 5 * * *"
# 榜单同步 cron 表达式。
ranking_sync_cron = "45 1 * * *"
# JavDB 热评同步 cron 表达式。
hot_review_sync_cron = "20 1 * * *"
# 巡检 media 记录对应文件并补视频信息。
media_file_scan_cron = "0 */6 * * *"
# 回填历史影片 DMM 原文描述。
movie_desc_sync_cron = "0 4 * * *"
# 翻译影片简介为中文。
movie_desc_translation_cron = "15 4 * * *"
# 抓取已订阅影片字幕。
movie_subtitle_fetch_cron = "30 */6 * * *"
# 生成媒体资源缩略图。
media_thumbnail_cron = "*/5 * * * *"
# 生成以图搜图缩略图向量。
image_search_index_cron = "0 0 * * *"
# 优化以图搜图索引。
image_search_optimize_cron = "0 3 * * *"

[movie_desc_translation]
# 是否启用影片简介翻译任务。
enabled = false
# OpenAI 兼容服务地址。
base_url = "http://localhost:8000"
# OpenAI 兼容服务 API Key；未启用时可留空。
api_key = ""
# 翻译使用的模型名称。
model = "gpt-4o-mini"
# 翻译请求总超时秒数。
timeout_seconds = 300
# 翻译请求建连超时秒数。
connect_timeout_seconds = 3

[image_search]
# JoyTag 独立推理服务地址。
inference_base_url = "http://joytag-infer:8001"
# 推理服务总超时秒数。
inference_timeout_seconds = 30
# 推理服务建连超时秒数。
inference_connect_timeout_seconds = 3
# 推理服务 Bearer Token；未启用时留空。
inference_api_key = ""
# 索引任务调用远端推理时的批大小。
inference_batch_size = 16
# 搜索会话有效期，单位：秒。
session_ttl_seconds = 600
# 默认每页结果数。
default_page_size = 20
# 最大每页结果数。
max_page_size = 100
# 为凑满一页结果时，每次向量库扫描的批大小。
search_scan_batch_size = 100
# JoyTag 索引任务每次批量写入 LanceDB 的条数。
index_upsert_batch_size = 100
# JoyTag 索引任务每处理多少条成功记录后触发一次分段 optimize。
optimize_every_records = 5000
# JoyTag 索引任务距离上次 optimize 超过多少秒后触发一次分段 optimize。
optimize_every_seconds = 1800
# JoyTag 索引任务结束后是否再执行一次兜底 optimize。
optimize_on_job_end = true

[lancedb]
# LanceDB 本地目录。
uri = "/data/indexes/image-search"
# LanceDB 表名。
table_name = "media_thumbnail_vectors"
# 标量索引字段列表。
scalar_index_columns = ["movie_id"]

[logging]
# 全局日志等级。可选值：DEBUG、INFO、WARNING、ERROR、CRITICAL。
level = "INFO"

[indexer_settings]
# 索引器类型，目前仅支持 jackett。这里的配置可以在 app 修改。
type = "jackett"
# Jackett API Key。
api_key = "change-me"

[[indexer_settings.indexers]]
# 索引器显示名称，需保持唯一。
name = "mteam"
# Jackett Torznab 接口地址。
url = "http://127.0.0.1:9117/api/v2.0/indexers/mteam/results/torznab/"
# 索引器资源类型，可选值：pt、bt。
kind = "pt"

[database.pragmas]
# SQLite 外键约束开关；仅当 engine=sqlite 时生效。
foreign_keys = 1
```
