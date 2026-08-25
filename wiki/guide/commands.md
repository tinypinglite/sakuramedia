---
outline: [2, 4]
---

# 常用命令

以下命令都在后端容器中执行。示例中的容器名是 `sakuramedia`，部署时如有调整请替换。

## 账号

### 重置账号

```bash
docker exec -it --user app -w /app sakuramedia python -m src.start.commands reset-account
```

也可以直接传入新账号：

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands reset-account --username admin --password 'your-new-password'
```

命令会覆盖数据库中的账号并清空 refresh token，已登录客户端需要重新登录。

## 数据库与服务

### 初始化数据库

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands initdb
```

### 应用数据库结构

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands migrate
```

### 等待数据库就绪

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands wait-db --timeout 60 --interval 2
```

### 测试 JavDB 查询

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands test-javdb --movie-number ABP-001
docker exec --user app -w /app sakuramedia python -m src.start.commands test-javdb --movie-number ABP-001 --json
```

## 手动触发后台任务

`aps` 子命令会把任务放入任务中心，任务中心可以查看进度和结果：

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps sync-subscribed-actor-movies
docker exec --user app -w /app sakuramedia python -m src.start.commands aps auto-download-subscribed-movies
docker exec --user app -w /app sakuramedia python -m src.start.commands aps sync-download-tasks
docker exec --user app -w /app sakuramedia python -m src.start.commands aps auto-import-download-tasks
docker exec --user app -w /app sakuramedia python -m src.start.commands aps generate-media-thumbnails
```

完整任务名和默认频率见[后台任务](/guide/tasks)。插件注册的任务也会自动出现在 `aps` 命令组中。

## 插件管理

```bash
# 列出插件
docker exec --user app -w /app sakuramedia python -m src.start.commands plugins list

# 安装目录或 zip 包
docker exec --user app -w /app sakuramedia python -m src.start.commands plugins install /path/to/plugin.zip

# 启用或停用
docker exec --user app -w /app sakuramedia python -m src.start.commands plugins enable plugin_id
docker exec --user app -w /app sakuramedia python -m src.start.commands plugins disable plugin_id

# 删除
docker exec --user app -w /app sakuramedia python -m src.start.commands plugins remove plugin_id

# 校验插件目录
docker exec --user app -w /app sakuramedia python -m src.start.commands plugins check /path/to/plugin
```

插件变更后按命令输出重启 `api` 与 `aps` 服务。

## 其他维护命令

为缺少精简封面的影片补生成封面：

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands backfill-movie-thin-cover-images
```

普通影片和视频的导入从客户端「管理 → 媒体导入」发起。来源浏览由媒体库 provider 提供，提交的数据包含 provider 能理解的 `source_ref`。
