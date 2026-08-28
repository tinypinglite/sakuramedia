---
outline: [2, 4]
---

# 从 v0.5.3 升级到 v0.6.0

本页适用于**完整的 v0.5.3** Docker Compose 部署直接升级到 v0.6.0。升级会自动迁移存储 provider；不需要手动执行数据库迁移命令。

使用过测试构建、手工修改过数据库结构，或不是从完整 v0.5.3 升级的实例，请先恢复到 v0.5.3 再按本页操作。

## 1. 备份 PostgreSQL 和配置

在 `compose.yaml` 所在目录执行；备份文件请保存到当前部署目录之外：

```bash
mkdir -p ../sakuramedia-backup
docker compose exec -T postgres pg_dump -U sakuramedia -d sakuramedia -Fc \
  > ../sakuramedia-backup/sakuramedia-v053.dump
cp sakuramedia-data/config/config.toml ../sakuramedia-backup/config-v053.toml
```

如果使用外部 PostgreSQL，请使用该数据库自己的 `pg_dump` 流程。不要跳过配置文件备份。

## 2. 更新 Compose 服务

将后端镜像固定为 v0.6.0：

```yaml
  sakuramedia:
    image: tinyping/sakuramediabe:v0.6.0
```

删除旧的 `joytag-infer` 服务及其模型挂载，新增以下 `siglip2-embed` 服务；完整示例见[快速开始](/guide/quick-start)。

```yaml
  siglip2-embed:
    image: tinyping/siglip2-embed-service:cpu
    container_name: siglip2-embed
    restart: unless-stopped
    environment:
      EMBEDDING_BACKEND: "cpu"
      CPU_CONCURRENCY: "1"
```

SigLIP2 镜像内已包含模型和运行时，无需保留 JoyTag 模型目录。需要 Intel 核显或 NVIDIA CUDA 时，按[进阶部署](/guide/docker)替换该服务。

## 3. 配置迁移规则

正常启动时，后端会把**精确的旧默认值**：

```toml
inference_base_url = "http://joytag-infer:8001"
```

自动写为：

```toml
inference_base_url = "http://siglip2-embed:8080"
```

自定义的 `inference_base_url` 不会被覆盖。若你曾指向自建 JoyTag 服务，请在启动前把它改为兼容的 SigLIP2 服务地址；迁移日志也会给出提醒。

## 4. 拉取并启动

```bash
docker compose pull sakuramedia siglip2-embed
docker compose up -d
docker compose logs -f sakuramedia
```

日志会依次显示 v0.5.3 桥接迁移、数据库迁移和运行时配置迁移。确认服务正常后，可按自己的 Docker 管理方式停止并删除不再使用的 JoyTag 容器；不要删除 PostgreSQL、`sakuramedia-data` 或 Qdrant 数据目录。

## 5. 迁移会保留和重建什么

- 已有媒体库、媒体文件引用和存储配置会迁移到官方存储 provider。
- 旧版运行中的下载、批量秒传和索引等任务状态不兼容，会被清理；按需重新创建即可。
- 图片搜索索引状态会重置并重新构建。旧版 Qdrant 集合 `media_thumbnail_vectors` 和 `movie_plot_image_vectors` 会在迁移成功后自动删除，避免继续占用磁盘。
- 已升级实例可以安全重启，不会重复执行 v0.5.3 桥接迁移。

迁移完成后，到「概览」页运行组件诊断，并按需在任务中心重新执行图片索引。
