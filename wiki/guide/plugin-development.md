---
outline: [2, 3]
---

# 插件开发

SakuraMedia 插件是运行在后端进程内的 Python 包。本文对应 **Host API 4**：插件的 `manifest.json` 和 `register()` 返回值必须使用相同版本，否则宿主会拒绝加载。

插件不是前端扩展机制。当前不能注册页面、UI 组件、HTTP 路由、事件钩子或中间件，也不应直接访问宿主数据库。请只使用本文列出的公开契约；绑定 `src.model`、`src.service` 等内部实现会使插件随宿主重构失效。

## 选择插件类型

| 目标 | 实现方式 |
|---|---|
| 定时抓取、手动处理、字幕或影片数据处理 | 注册后台任务 |
| 提供排行榜来源 | 注册 `discovery.ranking_source` 扩展点，并自行注册同步任务 |
| 接入一种新的媒体存储或下载平台 | 注册 `media.provider` 扩展点 |

多数插件只需要后台任务。只有宿主需要统一枚举、编排插件能力时，才应使用扩展点。

## 最小插件

插件根目录名必须等于 `plugin_id`，并包含 `manifest.json` 与 `__init__.py`：

```text
example_plugin/
├── manifest.json
├── __init__.py
└── plugin.py
```

`manifest.json`：

```json
{
  "plugin_id": "example_plugin",
  "display_name": "示例插件",
  "version": "1.0.0",
  "host_api_version": 4,
  "requires_python": ">=3.10,<3.11",
  "dependencies": []
}
```

`plugin_id` 只能使用小写字母、数字和下划线，且以字母开头。`dependencies` 是可选的 PEP 508 依赖列表；声明依赖后，宿主会在完整容器启动前同步它们。

`__init__.py` 只需暴露 `register`：

```python
from .plugin import register

__all__ = ["register"]
```

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

`PluginContext` 提供以下稳定能力：

- `settings`：`plugins.settings.<plugin_id>` 对应的只读配置；插件自行定义和校验字段。
- `data_dir`：插件专属运行数据目录，重新安装时会保留。运行状态写在这里，不要写进插件代码目录。
- `movies`：读取影片快照、分页遍历和受保护字段更新入口。
- `import_movie_by_number()`、`import_subtitle()`：使用宿主的影片或字幕写入能力。
- `sync_ranking_sources()`、`sync_ranking_board()`：同步当前插件声明的排行榜来源。
- `get_task_logger()`：取得任务日志 logger。

影片快照、字幕结果和元数据模型从 `src.plugins.types` 导入。公开入口是 `src.plugins`、`src.plugins.types`、`src.scheduler.contracts`，以及媒体 Provider 所用的 `src.plugins.provider_protocol`。

## 排行榜来源

排行榜插件在 `extensions` 中声明 `PluginExtension(key="discovery.ranking_source", data=...)`。`PluginRankingSource` 包含全局唯一的 `source_key` 和一个或多个 `PluginRankingBoard`；每个榜单的 `fetch_numbers(period)` 返回番号列表，顺序即排名。

插件负责访问外部站点并注册自己的同步任务；宿主负责榜单存储、影片详情导入和对外 API。可参考 [JavDB 排行榜插件](https://github.com/tinypinglite/sakuramedia_javdb_ranking)。

## 媒体 Provider

Provider 用于接入一种完整的媒体存储边界，而不只是新增下载器。它通过 `PluginExtension(key="media.provider", data=bundle)` 注册；每个 `provider_key` 全局唯一。

bundle 必须声明：

- `provider_key`、`display_name`；
- `library_config_fields`：由 `ConfigField` 组成的元组，输入类型只有 `text`、`secret`、`path`；
- `playback_deliveries`：支持的播放方式，必须包含 `proxy`，可额外支持 `redirect`；
- `prepare_library()`：校验和规范化媒体库配置；
- `build_storage()`：为一个媒体库创建存储实现；
- `downloads`：没有下载能力时设为 `None`，有下载能力时提供下载组件。

存储实现必须覆盖以下能力：

| 能力 | 必需方法 |
|---|---|
| 浏览与导入来源 | `browse`、`scan_import_source`、`read_import_file`、`delete_import_file` |
| 导入事务 | `stage_import_file`、`finalize_import`、`abort_import` |
| 媒体处理 | `delete_media`、`compute_file_hash`、`handle_playback`、`generate_thumbnails`、`create_clip` |

`source_ref`、`storage_ref`、导入回执和 `provider_config` 都是不透明 JSON：宿主只保存并原样传回，Provider 自己负责解释。`stage_import_file` 必须按 `operation_key` 幂等；`finalize_import` 和 `abort_import` 必须可安全重试。

若实现下载组件，还需实现配置准备与诊断（`prepare_client`、`test_client`、`build`），以及远端任务的提交、列举和删除（`submit`、`list_tasks`、`delete_task`）。下载完成的来源只能交给同一个 Provider 导入。

完整类型签名以 [后端 Provider 协议源码](https://github.com/tinypinglite/sakuramediabe/blob/main/src/plugins/provider_protocol.py) 为准。可参考 [本地存储与 qBittorrent Provider](https://github.com/tinypinglite/sakuramedia_local_provider) 和 [115 Provider](https://github.com/tinypinglite/sakuramedia_115_provider)。

## 开发、安装与排错

在 SakuraMediaBE 仓库根目录检查插件目录：

```bash
uv run python -m src.start.commands plugins check /path/to/example_plugin
```

发布 zip 时，`manifest.json` 和 `__init__.py` 必须位于 zip 根目录，不能额外包一层目录。安装后，无依赖插件重启 API 和任务服务即可；声明了 `dependencies` 的插件必须完整重启容器。

插件加载失败只会隔离当前插件，不会阻止服务启动。进入「系统设置 → 插件」或执行 `plugins list` 查看 `load_error`；常见原因是目录名、manifest 与 `register()` 的 `plugin_id` / `version` / Host API 版本不一致，或任务和扩展点标识冲突。

## 版本兼容

`host_api_version` 是精确匹配，不提供旧版适配层。宿主升级后，先查看本页对应的 Host API 和公开类型变更，再发布兼容的新插件版本。
