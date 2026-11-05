---
outline: [2, 3]
---

# 插件开发

SakuraMedia 插件是运行在后端进程内的 Python 包。本文对应当前后端的 **Host API 17**，宿主接受 API **4–17** 的插件。插件的 `manifest.json` 与 `register()` 返回值中的 `plugin_id`、插件 `version` 必须一致；Host API 的声明规则见[版本兼容](#版本兼容)。

插件不是前端扩展机制。当前不能注册页面、UI 组件、HTTP 路由、事件钩子或中间件，也不应直接访问宿主数据库。请只使用本文列出的公开契约；绑定 `src.model`、`src.service` 等内部实现会使插件随宿主重构失效。

## 选择插件类型

| 目标 | 实现方式 |
|---|---|
| 定时抓取、手动处理、字幕或影片数据处理 | 注册后台任务 |
| 定时浏览媒体库内容、自动导入或整理合集 | 注册后台任务，调用 `context.imports`、`context.videos` 与 `context.collections` |
| 按媒体库判断缺片、分辨率或文件大小并自动下载 | 注册后台任务，调用 `context.media` 与 `context.downloads` |
| JavDB 未收录时提供影片元数据 | 注册 `catalog.metadata_source` 扩展点（需要 Host API 6） |
| 提供排行榜来源 | 注册 `discovery.ranking_source` 扩展点，并自行注册同步任务 |
| 接入一种新的媒体存储或下载平台 | 注册 `media.provider` 扩展点 |

多数插件只需要后台任务。只有宿主需要统一枚举、编排插件能力时，才应使用扩展点。

## 最小插件

插件根目录名必须等于 `plugin_id`，并包含 `manifest.json` 与 `__init__.py`：

```text
example_plugin/
├── manifest.json
├── __init__.py
├── plugin.py
└── settings.py
```

其中 `settings.py` 仅在 manifest 声明 `settings_model` 时需要。

`manifest.json`：

```json
{
  "plugin_id": "example_plugin",
  "display_name": "示例插件",
  "display_name_i18n": {
    "zh-CN": "示例插件",
    "en": "Example plugin"
  },
  "description": "一句话说明插件用途，不超过 200 字。",
  "description_i18n": {
    "zh-CN": "一句话说明插件用途，不超过 200 字。",
    "en": "One sentence about what the plugin does, at most 200 characters."
  },
  "version": "1.0.0",
  "host_api_version": 17,
  "settings_model": "Settings",
  "requires_python": ">=3.10,<3.11",
  "dependencies": []
}
```

`plugin_id` 只能使用小写字母、数字和下划线，且以字母开头。`settings_model` 是可选字段；声明后，宿主会从插件包根目录读取同名的 Pydantic `BaseModel`，用于生成配置 schema、默认值并校验配置更新。`dependencies` 是可选的 PEP 508 依赖列表；声明依赖后，宿主会在完整容器启动前同步它们。manifest 还可填写 `author`、`homepage`、`release_api_url`，其中 `release_api_url` 用于声明检查更新的 Release API 地址；未知字段会被拒绝。

`__init__.py` 至少暴露 `register`；如果声明了 `settings_model`，还必须从包根目录暴露对应模型：

```python
from .plugin import register
from .settings import Settings

__all__ = ["Settings", "register"]
```

`settings.py` 的最小示例：

```python
from pydantic import BaseModel


class Settings(BaseModel):
    enabled: bool = True
```

不需要结构化配置时，删除 manifest 的 `settings_model`，并只暴露 `register` 即可。

下面是一个最小的定时任务插件：

```python
from src.plugins import HOST_API_VERSION, PluginContext, PluginRegistration
from src.scheduler.contracts import JobDefinition


def run_example(reporter, params):
    reporter.emit(current=1, total=1, text="已完成")
    return {"processed": 1}


def register(context: PluginContext) -> PluginRegistration:
    return PluginRegistration(
        plugin_id="example_plugin",
        display_name="示例插件",
        version="1.0.0",
        host_api_version=HOST_API_VERSION,
        jobs=(
            JobDefinition(
                task_key="example_plugin_daily",
                log_name="example-plugin-daily",
                cli_name="example-plugin-daily",
                cli_help="运行示例任务",
                default_cron="0 3 * * *",
                handler=run_example,
            ),
        ),
    )
```

`task_key`、`log_name` 和 `cli_name` 必须在全部内建任务和插件任务中唯一。需要手动带参任务时，设置 `manual_only=True`，并提供 Pydantic `params_schema`；任务处理函数始终接收 `(reporter, params)`。

## 注册与宿主能力

宿主在 API 和任务服务启动时 import 插件并调用 `register(context)`。注册阶段只应构造声明和校验本地配置：不要联网、校验 Cookie、创建外部目录或启动后台线程。

`PluginContext` 主要提供以下稳定能力：

- `settings`：`plugins.settings.<plugin_id>` 对应的只读配置；声明 `settings_model` 时，宿主的插件设置接口同时提供 schema 和默认值，并在配置保存时按模型校验。
- `data_dir`：插件专属运行数据目录，重新安装时会保留。运行状态写在这里，不要写进插件代码目录。
- `movies`：查询影片及关联演员、标签快照，分页遍历并更新受保护字段。
- `actors`：读取演员身份与资料快照，分页遍历并更新资料字段。
- `subscriptions`：读取订阅状态、订阅或取消订阅，以及重置订阅搜索状态。
- `notifications`：创建、幂等创建和解决插件通知，并按通知 ID 升序增量读取宿主通知。
- `collections`：按插件自己的 key 管理 playlist、moment 和 clip 合集。
- `subtitles`：列出影片已登记的字幕，读取原始字节及 SHA256。
- `media`：按影片、媒体库读取媒体快照，判断是否存在媒体或可播放媒体。
- `downloads`：列出下载目标，按宿主默认路由或指定 `download_client_id` 搜索候选并提交。
- `imports`：列出媒体库、浏览 provider 存储，按 provider 引用发起媒体库导入，并查询自己任务的结果（Host API 9）。
- `videos`：读取普通视频快照；合集成员管理见 `context.collections`（Host API 9）。
- `import_movie_by_number(movie_number, *, force_subscribed=False)`：复用本地影片，或按 JavDB 优先、元数据插件兜底的顺序导入，返回 `MovieSnapshot`。
- `list_existing_movie_numbers()`：读取全库影片番号的大写集合。
- `import_subtitle(movie_number, content, filename, language=None)`：交由宿主校验、去重、落盘并登记字幕。
- `sync_ranking_sources(progress_callback=None)`、`sync_ranking_board()`：同步当前插件声明的排行榜来源。
- `get_task_logger(name)`：取得任务日志 logger。

影片、演员、查询结果、订阅、通知、合集、下载、导入受理和字幕类型从 `src.plugins.types` 导入；元数据来源模型从 `src.plugins` 导入。公开入口是 `src.plugins`、`src.plugins.types`、`src.scheduler.contracts`，以及媒体 Provider 所用的 `src.plugins.provider_protocol`。

### 插件配置模型

声明 `settings_model` 后，宿主的插件设置接口会返回当前 `settings`、`schema` 和 `defaults`。保存配置时，宿主使用该模型校验并按模型别名写回配置；校验失败返回字段级错误。配置更新后需要重启 API 和任务服务时，接口会返回 `pending_restart`。模型未声明时保持旧的自由 JSON 配置行为。

## 影片与演员资料

### 快照与分页

`context.movies` 提供 `get(movie_id)`、`find_by_numbers(numbers)`、`list_page(after_id=0, limit=500)` 和 `query(filters=None, after_id=0, limit=500)`；`context.actors` 提供 `get(actor_id)` 和相同参数的 `list_page()`。`get()` 找不到时返回 `None`；批量番号查询按输入顺序去重并跳过不存在的影片。分页上限是 1000，将 `next_cursor` 作为下一页的 `after_id`，为 `None` 时结束。

快照通过 `values` 读取字段，通过 `owners` 查看归属，通过 `revision` 做并发更新检查。可读字段分别以 `MOVIE_SNAPSHOT_FIELDS`、`ACTOR_SNAPSHOT_FIELDS` 为准：

- 影片新增可读的 `series_name`、`is_blacklisted`，并通过 `actors`、`tags` 返回关联快照元组。
- 演员快照包含 `actor_id`、身份与订阅信息，以及生日、身高、三围等资料。`TagSnapshot` 只包含 `tag_id` 和 `name`。
- 影片的 `revision` 不覆盖关联演员、标签；更新演员时必须使用该演员自己的快照版本。

### 影片筛选查询

`context.movies.query()` 接受 `MovieQueryFilters` 或同结构的 mapping。可用筛选包括 `search`（番号或标题）、`actor_id`、`tag_ids`、`tag_match`、`year`、`subscribed`、`playable`、`status`、`collection_type`、`series_id`、`director_name`、`maker_name`、`number_source`、`heat_min`、`heat_max` 和 `blacklisted`。`status` 不能与 `subscribed` 或 `playable` 同时使用；结果按影片内部 id 稳定排序并使用 `after_id` 游标。

```python
from src.plugins.types import MovieQueryFilters


page = context.movies.query(
    MovieQueryFilters(subscribed=True, playable=False),
    limit=100,
)
for movie in page.items:
    print(movie.values["movie_number"])
```

### 受保护字段更新

两个入口均使用 `patch(id, fields, expected_revision) -> bool`，只允许以下字段：

| 入口 | 可写字段 | 值要求 |
|---|---|---|
| `context.movies.patch()` | `title`、`summary`、`maker_name`、`director_name` | 字符串，不接受 `None` |
| `context.movies.patch()` | `is_collection`、`is_blacklisted` | 布尔值 |
| `context.actors.patch()` | `birthday` | `datetime.date` 或 `YYYY-MM-DD` 字符串 |
| `context.actors.patch()` | `height_cm`、`bust_cm`、`waist_cm`、`hips_cm` | 1–2147483647 的整数厘米值，不接受布尔值 |
| `context.actors.patch()` | `cup`、`birthplace`、`blood_type` | 1–255 字符的非空文本 |

演员资料字段可传 `None` 显式清空，但仍保留插件归属。演员姓名、别名、JavDB 身份、头像和订阅状态不在写入白名单内。

字段未被接管时，`owners` 中没有对应键；插件写入成功后归属为 `plugin:<plugin_id>`，人工修改的归属为 `host:manual`。插件只能写未被接管或由自己持有的字段。记录不存在、版本不匹配或任一字段归属冲突时，`patch()` 返回 `False`，整次零修改；字段或值非法则抛出 `ValueError`。收到 `False` 后应重新读取并决定是否还需要更新，不要盲目循环重试。

```python
def mark_collection(context, movie_id: int) -> bool:
    movie = context.movies.get(movie_id)
    if movie is None:
        return False
    return context.movies.patch(
        movie.movie_id,
        {"is_collection": True},
        expected_revision=movie.revision,
    )


def update_actor_height(context, actor_id: int, height_cm: int) -> bool:
    actor = context.actors.get(actor_id)
    if actor is None:
        return False
    return context.actors.patch(
        actor.actor_id,
        {"height_cm": height_cm},
        expected_revision=actor.revision,
    )
```

`is_blacklisted=True` 不能用于已订阅影片，否则整次 patch 返回 `False`。`import_movie_by_number()` 也不会覆盖已存在影片的字段；需要更改时单独读取快照并 patch。

## 订阅、通知与合集

`context.subscriptions` 提供 `list()`、`count_by_status()`、`get(movie_id)`、`subscribe(movie_number)`、`unsubscribe(movie_number)` 和 `reset_search(movie_ids=None)`。订阅列表使用页码分页；`reset_search(None)` 重置全部订阅的搜索状态，传入影片 id 集合时只重置指定影片。

`context.notifications` 提供 `create()`、`create_once()` 和 `resolve(dedupe_key)`。幂等键会自动带上当前插件命名空间，插件之间不会互相覆盖；创建结果中的 key 和 `resolve()` 都使用插件自己的原始 key。

`list(after_id=0, limit=100)` 按通知 ID 升序返回 `PluginNotification` 快照，只读且不改变通知的已读状态；`limit` 上限 100。推送类插件应以最后成功处理的通知 ID 作为下次的 `after_id`，进度落在 `data_dir`，宿主不维护投递状态和重试。

`context.collections` 提供 `ensure_playlist()` / `set_playlist_movies()`、`ensure_moment()` / `set_moment_points()` 和 `ensure_clip()` / `set_clip_clips()`。合集通过插件自己的 `key` 管理，设置成员时会替换该合集的全部成员，不能修改其他插件拥有的 key。

`ensure_video_collection(name, description=None)` 按名称获取或创建视频合集（Host API 9），用于把导入的视频加入指定合集。同名合集原样复用，插件不会覆盖用户设置的名字和描述；合集没有插件 key，`PluginCollection.key` 为空字符串。

`add_video_items(collection, video_ids)` / `remove_video_items(collection, video_ids)` 按 id 或名称定位视频合集并增删成员（Host API 9）：添加幂等、任一视频不存在报 404；移除幂等、不存在的视频 id 静默跳过，合集不存在报 404。

## 字幕读取与导入

`context.subtitles.list(movie_id)` 返回 `tuple[SubtitleAsset, ...]`，每项包含 `subtitle_id`、`file_name`、`format`、`size_bytes`、`created_at`。它只列出已登记且仍可访问的字幕，跳过失效文件，不扫描或清理目录。

`context.subtitles.read(movie_id, subtitle_id)` 返回 `SubtitleContent`：`content` 是原始 `bytes`，`sha256` 是本次读取内容的指纹。读取上限为 **10 MiB**，不提供宿主文件路径或可写句柄。失败抛出从 `src.plugins.types` 导入的 `SubtitleReadError`，通过 `code` 区分：

| code | 含义 |
|---|---|
| `movie_not_found` | 影片不存在（列表与读取均可能返回） |
| `subtitle_not_found` | 字幕不存在或不属于该影片 |
| `subtitle_path_invalid` | 字幕路径非法 |
| `subtitle_unavailable` | 文件不存在或不可访问 |
| `subtitle_too_large` | 字幕超过读取上限 |

写入仍使用 `context.import_subtitle()`，返回 `SubtitleImportResult`。应检查 `status`，其值为 `imported`、`duplicate`、`movie_not_found` 或 `invalid_format`；不要把重复或无效格式当成新导入成功。

## 媒体查询与下载

`context.media.list_for_movie(movie_id, library_id=None)` 返回该影片的媒体快照。每项包含 `media_id`、`movie_id`、`movie_number`、`library_id`、`library_name`、`provider_key`、`file_name`、`resolution`、`file_size_bytes`、`duration_seconds`、`valid` 和可选的 `video_info`。不返回 Provider 的 `storage_ref`、真实文件路径或可写句柄。

`context.media.presence_for_movies(movie_ids, library_id=None)` 用一次批量查询返回每部影片的 `PluginMediaPresence`：

- `has_any`：存在任意 Media 记录，包括 `valid=False` 的失效记录；
- `has_playable`：至少存在一条 `valid=True` 的媒体；
- `items`：按媒体入库顺序返回媒体快照。

多媒体库场景必须传入目标 `library_id`；不传时表示跨所有媒体库聚合，不能用来判断某个下载目标是否缺片。目标下载器对应的媒体库可通过 `context.downloads.get_target(download_client_id).library_id` 获取。

下载目标可以由宿主自动路由，也可以由插件显式指定。未指定 `download_client_id` 时，宿主按照索引器与下载器的绑定关系选择目标，并把解析出的目标写入每个候选：

```python
candidates = context.downloads.search_candidates(
    movie_number="ABC-001",
    indexer_kind="pt",
)

candidate = choose_best(candidates)
result = context.downloads.submit(
    movie_number="ABC-001",
    candidate=candidate,
)
```

`context.downloads.list_targets()` 可读取当前下载目标，返回值不包含凭据；没有目标时返回空元组。默认路由时，每个索引器使用其绑定顺序中的第一个下载器，目标列表的返回顺序不代表默认优先级。显式传入 `download_client_id` 时，只搜索绑定该下载器的索引器。候选会携带宿主解析出的 `download_client_id`、`library_id`、`library_name` 和 `provider_key`；插件不能把一个候选改投到另一个媒体库。目标下载器被删除、解绑或媒体库提供方发生变化时，提交会失败，不会在提交阶段自动改选其他目标。

同一影片要提交到多个媒体库时，插件必须针对每个目标下载器分别搜索并提交。下载完成后的导入仍进入该下载器关联的媒体库，不能在普通插件中组合一个下载 Provider 和另一个存储 Provider。

对于批量补缺，建议先读取影片分页，再调用 `presence_for_movies()`，只对目标库中 `has_playable=False` 的影片搜索和提交。当前门面只提供搜索与提交，不提供下载任务状态、重试、删除或导入控制。

## 媒体库浏览与导入

`context.imports`（Host API 9）让插件像前端手动导入一样浏览媒体库 provider 存储并发起导入：文件字节始终由目标媒体库的 Provider 流转，插件只处理不透明引用。

- `list_libraries()`：返回全部媒体库的 `PluginLibrary`（`library_id`、`name`、`provider_key`），不包含 provider 配置与凭据；
- `browse(library=..., parent_ref=None, cursor=None, limit=50)`：浏览目标媒体库的 provider 存储，返回 `PluginBrowsePage`；每项 `PluginBrowseEntry` 包含 provider 私有的 `source_ref`、`name`、`entry_type`、`size_bytes`、`modified_at` 和宿主判定的 `is_video`（`limit` 上限 200）；`next_cursor` 为 `None` 时结束；
- `enqueue(media_kind, library, source_ref, collection_id=None, source_disposition="keep")`：按 provider 引用发起导入，返回 `PluginImportBatch`（`task_run_id`、`task_key`、`state`）；
- `get(task_run_id)`：读取本插件发起的导入任务状态与结果摘要，返回 `PluginImportStatus`；任务不存在或不属于本插件时返回 `None`。

`library` 支持媒体库 id 或名称（名称唯一）。`source_ref` 必须来自 `browse()` 的条目，由该媒体库的 provider 解释；插件不要自行构造引用，也不能把引用用到另一个媒体库。`entry_type="directory"` 的引用在导入时由 provider 展开为其中的文件。

```python
libraries = context.imports.list_libraries()
page = context.imports.browse(library="本地媒体库", limit=100)
collection = context.collections.ensure_video_collection("推特视频")

for entry in page.entries:
    if entry.entry_type != "file" or not entry.is_video:
        continue
    context.imports.enqueue(
        media_kind="video",
        library="本地媒体库",
        source_ref=entry.source_ref,
        collection_id=collection.collection_id,
    )
```

导入规则与前端手动导入一致：

- `media_kind="video"`：按文件名建立普通视频，可选加入 `collection_id`；
- `media_kind="jav"`：从文件名解析番号，走 JavDB 优先、元数据插件兜底的元数据导入并自动订阅；番号缺失、文件小于最小视频体积或元数据获取失败会记录为失败项，可在任务中心人工处理；JAV 不支持 `collection_id`；
- `source_disposition="delete_after_commit"` 时，导入成功后由 provider 删除来源文件；默认 `keep`；
- `source_disposition="in_place"` 时，不复制也不移动文件，媒体直接引用源文件当前位置；只有声明了该能力的 provider（bundle 的 `supports_in_place_import = True`）可用，其余 provider 会返回 `422 in_place_import_unsupported`；
- 同一媒体库同一时间只允许一个导入任务；冲突时抛出 `409 import_task_conflict`，应等待当前导入结束后再重试；
- `keep` 与 `in_place` 时，宿主按 provider 提供的来源身份去重，重复导入同一来源会被跳过。

浏览或导入失败会抛出带 `status_code` 和 `code` 的错误（例如库不存在 `404 media_library_not_found`、provider 未安装 `503 provider_not_installed`、认证失败 `401 provider_authentication_failed`）。导入是异步任务，`enqueue()` 返回后可用 `get(task_run_id)` 轮询：`pending` / `running` 期间计数为零，结束后包含 imported / skipped / failed 计数、新建视频与影片 id 和 `error_message`；同一任务也可以在任务中心人工查看。插件可以浏览所有已配置媒体库的 provider 列表，这是宿主对仓库内可信插件的既定信任模型。

## 普通视频（PornBox）

`context.videos`（Host API 9）提供普通视频条目的只读快照，用于对账、策展和整理类插件：

- `get(video_id)`：读取单个 `PluginVideoSnapshot`；不存在返回 `None`；
- `list_page(after_id=0, limit=500)`：按 `VideoItem.id` 游标分页遍历全部视频（`limit` 上限 1000），`next_cursor` 为 `None` 时结束。

快照包含 `title`、`summary`、`release_date`、`media_count`、`has_playable`、`collection_ids` 与时间戳；`duration_seconds`、`file_size_bytes`、`resolution`、`file_name` 取「第一条有效媒体」，没有有效媒体时分别为 `0`、`0`、`None`、`None`。

```python
# 把还没有合集归属、且有可播放媒体的视频加入“待整理”合集。
collection = context.collections.ensure_video_collection("待整理")
page = context.videos.list_page(limit=200)
pending_ids = [
    item.video_id
    for item in page.items
    if item.has_playable and not item.collection_ids
]
if pending_ids:
    context.collections.add_video_items(collection.collection_id, pending_ids)
```

插件不能改写视频的标题、描述或封面，也没有删除入口；这些操作只在宿主界面进行。

## 影片元数据来源

### 注册与调用顺序

通过 `PluginExtension(key="catalog.metadata_source", data=PluginMetadataSource(...))` 注册同步回调 `fetch_movie(movie_number) -> PluginMovieMetadata | None`。`PluginMetadataSource`、`PluginMovieMetadata`、`PluginMetadataActor` 和 `METADATA_SOURCE_EXTENSION_KEY` 均可从 `src.plugins` 导入。

下面是可加载的注册骨架；实际插件需将 `fetch_movie()` 的占位返回替换为站点查询、图片下载及结果构造，manifest 的 `host_api_version` 至少声明为 `6`：

```python
from src.plugins import (
    HOST_API_VERSION,
    METADATA_SOURCE_EXTENSION_KEY,
    PluginContext,
    PluginExtension,
    PluginMetadataSource,
    PluginMovieMetadata,
    PluginRegistration,
)


def register(context: PluginContext) -> PluginRegistration:
    def fetch_movie(movie_number: str) -> PluginMovieMetadata | None:
        # 在调用时查询站点；找到后交付元数据和图片，未找到返回 None。
        return None

    return PluginRegistration(
        plugin_id="example_plugin",
        display_name="示例插件",
        version="1.0.0",
        host_api_version=HOST_API_VERSION,
        extensions=(
            PluginExtension(
                key=METADATA_SOURCE_EXTENSION_KEY,
                data=PluginMetadataSource(fetch_movie=fetch_movie),
            ),
        ),
    )
```

宿主先查询 JavDB，只有明确“未找到影片”才按 `plugins.enabled` 的顺序调用已启用的元数据来源。JavDB 的网络、认证等错误不会触发兜底。插件返回 `None` 时继续下一个来源；抛异常或交付校验失败时记录错误并继续，首个合法结果被采用。全部来源均未找到则按未找到处理；存在失败且没有来源成功时，返回元数据来源错误。

回调只负责交付结果，不要在其中调用 `context.import_movie_by_number()`，否则会重新进入相同的兜底链路。

### 结果与图片交付

`PluginMovieMetadata` 要求以下字段：

| 字段 | 要求 |
|---|---|
| `movie_number` | 非空，规范化后必须与请求番号一致 |
| `title` | 非空标题 |
| `release_date` | `datetime.date` 或严格的 `YYYY-MM-DD` 字符串，不接受时间戳或 datetime |
| `duration_minutes` | 正整数，不接受字符串、浮点数或布尔值 |
| `cover_image_path` | 已下载封面图片的本地文件路径，不能是 URL |

可选字段为 `summary`、`maker_name`、`director_name`、`series_name`、`actors`、`tags`、`plot_image_paths`、`source_url`、`source_id`。演员以 `PluginMetadataActor(name=..., alias_names=[...])` 表达；剧情图同样交付本地文件路径。此契约不接收伪造的 JavDB ID、评分或外站演员 ID。

图片交付遵守以下约定：

1. 在回调执行时，为每次请求创建唯一的 `context.data_dir / "metadata-tmp" / <请求目录>`，将封面和剧情图下载到该目录。注册阶段不创建目录。
2. 同一结果的所有图片必须属于同一个请求目录；解析后的路径必须仍在该插件的 `data/metadata-tmp/` 内，且为实际存在、可完整解码的图片文件。
3. 返回后让文件继续存在，交由宿主校验、复制并入库。宿主在消费结束后清理已接管的交付文件；不要在回调返回前通过临时目录上下文自动删掉图片。
4. 插件自行清理下载失败、返回 `None` 或未通过路径交付校验时遗留的文件。不要将长期缓存文件直接作为交付文件，因为它们可能被宿主删除。

宿主保存来源信息，并将匹配到唯一 JavDB 身份的演员关联到影片；无法唯一匹配的演员会被过滤，不会创建虚假身份。插件导入的影片可暂时没有 JavDB ID，宿主的 `movie_javdb_backfill` 任务会后续补录，来源插件停用或卸载后仍可执行。补录保留同一影片记录，已有人工或插件接管的受保护字段不会被覆盖；元数据来源交付本身不会自动取得字段归属。

## 排行榜来源

排行榜插件在 `extensions` 中声明 `PluginExtension(key="discovery.ranking_source", data=...)`。`PluginRankingSource` 包含全局唯一的 `source_key` 和一个或多个 `PluginRankingBoard`；每个榜单的 `fetch_numbers(period)` 返回番号列表，顺序即排名。

插件负责访问外部站点并注册自己的同步任务；宿主负责榜单存储、影片详情导入和对外 API。可参考 [JavDB 排行榜插件](https://github.com/tinypinglite/sakuramedia_javdb_ranking)。

## 媒体 Provider

Provider 用于接入一种完整的媒体存储边界，而不只是新增下载器。它通过 `PluginExtension(key="media.provider", data=bundle)` 注册；每个 `provider_key` 全局唯一。

bundle 必须声明：

- `provider_key`、`display_name`；
- `library_config_fields`：由 `ConfigField` 组成的元组，输入类型只有 `text`、`secret`、`path`；
- `playback_deliveries`：非空且不重复的播放方式元组，必须包含 `proxy`，可额外支持 `redirect`；**首项是默认方式**，例如 `("redirect", "proxy")` 默认重定向；
- `prepare_library()`：校验和规范化媒体库配置；
- `build_storage()`：为一个媒体库创建存储实现；
- `downloads`：没有下载能力时设为 `None`，有下载能力时提供下载组件。

存储实现必须覆盖以下能力：

| 能力 | 必需方法 |
|---|---|
| 浏览与导入来源 | `browse`、`scan_import_source`、`read_import_file`、`delete_import_file` |
| 导入事务 | `stage_import_file`、`finalize_import`、`abort_import` |
| 媒体处理 | `delete_media`、`compute_file_hash`、`handle_playback`、`generate_thumbnails`、`create_clip` |

`scan_import_source(source_ref=..., progress_callback=None)` 可接收 JSON 进度回调；只有按 Host API 7 注册的 Provider 才会收到该参数，旧 Provider 仍按不带回调的旧签名调用。`generate_thumbnails(media=..., workspace=..., progress_callback=None)` 的进度回调是可选的，宿主会兼容尚未声明该参数的旧实现。

`source_ref`、`storage_ref`、导入回执和 `provider_config` 都是不透明 JSON：宿主只保存并原样传回，Provider 自己负责解释。`stage_import_file` 必须按 `operation_key` 幂等；`finalize_import` 和 `abort_import` 必须可安全重试。

若实现下载组件，还需声明 `config_fields`，实现配置准备与诊断（`prepare_client`、`test_client`、`build`），以及远端任务的提交、列举和删除（`submit`、`list_tasks`、`delete_task`）。下载完成的来源只能交给同一个 Provider 导入。

下载组件通过 `supported_source_kinds` 声明支持的来源类型：`magnet`、`torrent`、`ed2k`、`http`。未声明时宿主按 `magnet`/`torrent` 处理。`DownloadSubmission` 携带 `source_kind`、`resource_key` 和 `source_size_bytes`；Provider 应把 `resource_key` 当作不透明标识，不要自行假设它一定是 BTIH。HTTP 直链由云下载 Provider 接收，宿主不会为它抓取内容。

### 可选存储能力

以下能力按方法是否存在进行检测，不是基础存储实现的必需方法：

| 能力 | 声明或方法 | 约定 |
|---|---|---|
| 合并播放 | bundle 的 `merged_playback_format`，storage 的 `handle_merged_playback()` | 格式为 `mp4` 或 `hls`，按 `medias` 顺序提供合并流 |
| 合并播放预检 | `preflight_merged_playback(medias=...)` | 在宿主签发合并播放 URL 前校验，失败应抛出操作错误 |
| 跳过未变化的导入来源 | `get_import_source_identity(source=...)` | 返回字符串或 `None`；同一标识必须代表同一位置、未变化的来源，改名或移动必须改变标识 |
| 扫描媒体引用 | `scan_media_refs(source_ref=...)` | 枚举 Provider 原生引用 |
| 核对已管理媒体 | `scan_managed_media_ref_keys()`、`managed_media_ref_key(media_ref=...)` | 返回当前媒体库文件的键集合，并能用同一规则计算已登记媒体的键 |
| 原地导入 | bundle 的 `supports_in_place_import = True`；`stage_import_file(..., source_disposition="in_place")` | 直接把媒体指向导入来源、不复制或移动文件；`finalize_import`/`abort_import` 必须处理该处置方式的回执；`delete_media` 与有效性巡检按 provider 自己的引用规则处理 |
| 普通视频封面 | `open_cover_source(media=...)` | 以上下文管理器提供封面生成使用的视频来源 |
| 补充时长与分辨率 | `probe_duration_seconds(media=...)`、`probe_resolution(media=...)` | 分别返回整数秒和 `"WxH"` 字符串（或 `None`）；导入时也可通过 `StagedMedia.resolution` 提供分辨率 |
| 探测原始视频信息 | `probe_video_info(media=...)` | 返回 JSON 对象或 `None`，用于补充原始文件技术信息 |

### 媒体存储转存

转存能力按源端与目标端分别实现：

- 源端 `open_transfer_source(media=...)` 返回 `MediaTransferSource` 上下文管理器。会话提供 `info`（文件名与大小）、`open_reader()`（支持 `read`/`seek`）及 `assert_unchanged()`，不向目标 Provider 暴露自身引用或凭据。
- 当前迁移流程还要求源端实现 `cleanup_transfer_source(media=..., source=...)`，仅删除当前会话对应且未变化的源文件。
- 目标端实现 `stage_transfer(source=..., placement=..., operation_key=...)`、`finalize_transfer(receipt=...)`、`abort_transfer(receipt=...)`。暂存按操作键幂等，完成与回滚应可安全重试。

目标端返回 `StagedMediaTransfer(status="staged", ...)` 时，必须提供 `storage_ref`、`receipt`、`file_name`、`size_bytes`，文件名和大小应与源一致。优化转存不可用时返回 `StagedMediaTransfer(status="not_available")`，其余字段必须为 `None`；宿主会跳过该项，不会自动退回普通下载再上传。

宿主在暂存后检查源未变化，再切换媒体存储记录、完成目标校验，最后清理源文件。Provider 不应在 `stage_transfer()` 阶段删除源文件。

### 下载与错误处理

`RemoteDownloadTask.progress` 为 0–1；`state="completed"` 时必须携带非空的 `completed_source_ref`，其余状态必须为 `None`。状态取值为 `queued`、`downloading`、`completed`、`failed`。

可预期的 Provider 失败使用 `ProviderOperationError(provider_key, operation, code, safe_message, retryable)`。`code` 支持 `invalid_config`、`authentication_failed`、`source_not_found`、`task_not_managed`、`source_blacklisted`、`unsupported`、`unavailable`。例如拒绝删除不归该下载器管理的任务时使用 `task_not_managed`；`safe_message` 会对外展示，不应包含 Cookie、密码或内部路径。

完整类型签名以 [后端 Provider 协议源码](https://github.com/tinypinglite/sakuramediabe/blob/main/src/plugins/provider_protocol.py) 为准。可参考 [本地存储与 qBittorrent Provider](https://github.com/tinypinglite/sakuramedia_local_provider) 和 [115 Provider](https://github.com/tinypinglite/sakuramedia_115_provider)。

## 开发、安装与排错

在 SakuraMediaBE 仓库根目录检查插件目录：

```bash
uv run python -m src.start.commands plugins check /path/to/example_plugin
```

发布 zip 时，`manifest.json` 和 `__init__.py` 必须位于 zip 根目录，不能额外包一层目录。安装后，无依赖插件重启 API 和任务服务即可；声明了 `dependencies` 的插件必须完整重启容器。

运行时加载器会记录并隔离单个插件的加载错误；但容器启动前的依赖同步或预装校验仍可能阻止启动，应同时检查容器启动日志。进入「系统设置 → 插件」或执行 `plugins list` 查看 `load_error`；常见原因是目录名与 `plugin_id` 不一致、manifest 与 `register()` 的插件 `version` 不一致、Host API 声明不兼容，或任务和扩展点标识冲突。`plugins check` 只验证导入、注册及契约，不代表联网行为、图片交付或任务执行已经通过验收。

## 多语言（zh-CN / en）

插件可以向宿主声明中英两种文案，宿主按当前语言渲染。只提供中文仍然可用，但用户可见文案应尽量给出英文。

### 语言包

语言包放在插件包根目录：

```text
example_plugin/
├── manifest.json
├── __init__.py
└── i18n/
    ├── zh-CN.json
    └── en.json
```

- 两个文件的 key 集合必须完全一致；key 是非空的平铺点分字符串（如 `jobs.sync.cli_help`），不要写成嵌套对象。
- 值为字符串；需要复数时写成 `{"one": ..., "other": ...}`，调用 `t()` 时传 `count=`。
- 占位符统一使用 `{name}`，两种语言的占位符必须一致。
- 语言包缺失或缺少 key 都是合法的：静态字段回退插件原文，运行时文本回退 `default`。`plugins check` 与安装前校验会严格检查语言包结构（JSON、key 形式、值类型），运行时加载保持宽松，坏语言包不会阻断已启用插件。

多语言文案分两条路径：静态文案在**读取时**由宿主解析，运行时文本在**写入时**由插件生成。不要把两种文案混用。

### 静态文案：`*_i18n` 字典

这类字段是「原文字段 + 可选 `*_i18n` 字典」。宿主在读取时按当前语言取值，缺失时依次回退 `zh-CN`、插件原文：

| 位置 | 字段 |
|---|---|
| `manifest.json`、`PluginRegistration` | `display_name_i18n`（两处给任一即可，同时提供时以 `register()` 为准）；`manifest.json` 另可声明 `description` / `description_i18n`，供插件市场展示简介 |
| `JobDefinition` | `cli_help_i18n` |
| 任务参数、设置项的 JSON Schema | 任意层级的 `title_i18n`、`description_i18n`，含 `oneOf` 等组合选项的 `title_i18n` |
| Provider `ConfigField` | `label_i18n`、`description_i18n`、`hint_i18n` |
| 媒体 Provider bundle | `display_name_i18n` |
| 排行榜 `PluginRankingSource`、`PluginRankingBoard` | `name_i18n` |

`manifest.json` 的 `description` / `description_i18n` 只被插件市场使用：市场索引仓库每天从各插件的最新
Release 里读取 manifest，把展示名与简介（含多语言版本）同步进 `index.json`，客户端按
「当前语言 → `zh-CN` → 原文」取值。这两个字段都是可选的，不声明时市场沿用自己的文案，英文界面下会显示原文；
声明后要发一版插件，市场索引才会同步到新文案。

Pydantic 模型通过 `json_schema_extra` 携带字典，字典在导入期由插件自己的语言包读取器生成：

```python
from pydantic import BaseModel, Field

from .translations import text_map


class Settings(BaseModel):
    username: str = Field(
        default="",
        json_schema_extra={"title_i18n": text_map("settings.username.title")},
    )
```

语言包读取方式可直接参考样板插件 `sakuramedia_javdb_ranking` 的 `translations.py`：`text_map(key)` 返回 `{locale: text}`，`text(key, locale, default)` 返回源文案；文件或 key 缺失时返回空字典或兜底值，不会在导入期失败。

### 运行时文本：`context.i18n.t()`

进度、诊断与错误文本在写入时生成，语言取决于当时的请求或任务，必须调用 `context.i18n.t()`：

```python
reporter.emit(
    current=done,
    total=total,
    text=context.i18n.t(
        "sync.progress",
        default="已同步 {done}/{total} 个榜单",
        done=done,
        total=total,
    ),
)
```

- `t(key, default=None, **params)` 按当前语言查插件语言包，缺失时回退 `zh-CN`；**缺 key 且未提供 `default` 时返回 key 本身**，所以每个调用都要给中文 `default` 兜底。
- 语言包文件按路径缓存，可以在循环里直接调用。
- 适用场景：任务进度文本、`ProviderDiagnosticCheck.message`、`ProviderOperationError.safe_message`、任务失败原因、通知正文和元数据错误。

### 声明与语言选择

新插件把 manifest 的 `host_api_version` 声明为 `17`（宿主当前版本，`4`–`16` 仍兼容），`register()` 继续使用 `HOST_API_VERSION` 常量；不要因为多语言改动插件自身的 `version`。

请求路径上，宿主按 `Accept-Language`、其次用户的 `User.language` 偏好、最后默认 `zh-CN` 决定当前语言；后台任务没有请求上下文，执行时读取单账号的 `User.language`。插件不需要自己解析请求头。

以 `sakuramedia_javdb_ranking` 为样板：manifest 与 `plugin.py` 声明展示名，`boards.py` 声明榜单名，`settings.py` 与 `sync_jobs.py` 声明字段标题，同步任务里用 `t()` 生成进度文本。

## 版本兼容

当前宿主常量为 `HOST_API_VERSION = 17`、`MIN_SUPPORTED_HOST_API_VERSION = 4`，加载规则如下：

- manifest 的 `host_api_version` 必须在 **4–17** 内。
- `register()` 的 `host_api_version` 必须等于 manifest 声明的版本，或当前宿主版本 `17`。例如 manifest 为 `4` 时，注册返回 `4` 或导入宿主常量得到的 `17` 均可，返回 `5` 则不兼容。
- `catalog.metadata_source` 额外要求 manifest 声明 **6**；只把 `register()` 改为宿主常量不能绕过这一限制。
- `context.media` 和 `context.downloads` 需要 Host API **7**；旧宿主能加载旧声明，不意味着旧宿主能提供这两个接口。
- `context.imports`、`context.videos`、`context.collections.ensure_video_collection()` 与视频合集成员管理需要 Host API **9**。
- 下载来源类型能力声明与 `source_kind`/`resource_key` 契约需要 Host API **17**。
- Provider 的扫描进度回调只对按 Host API **7** 注册的实现启用；旧 Provider 仍按不带回调的旧签名调用。

升级前应核对实际宿主版本、公开类型与所用能力，再运行插件检查。插件自身的 `version` 与 Host API 版本是两个概念，manifest 与 `register()` 的插件 `version` 仍须严格一致。
