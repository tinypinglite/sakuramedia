---
outline: [2, 3]
---

# 常用命令

这页整理的是 SakuraMedia 服务跑起来之后，最常用的一批运维命令。

如果你只是第一次部署，先看“快速开始”就够了。这一页更适合下面几种场景：

- 想手动创建媒体库
- 想导入已有影片
- 想补跑一次缩略图、字幕或以图搜图索引
- 想排查容器状态和日志

## 先知道这几件事

### 命令默认针对后端容器 `sakuramedia`

下面所有示例都默认你的后端容器名是：

```bash
sakuramedia
```

如果你自己的容器名不是这个，就把命令里的 `sakuramedia` 换成你实际使用的名字。

### 路径都写 SakuraMedia 容器内路径

命令里出现的路径，都应该写成 SakuraMedia 容器内看到的绝对路径，不是宿主机路径。

例如：

- 媒体库根目录：`/mnt/volume1/media/sakuramedia`
- 旧媒体目录：`/mnt/volume1/media/av`
- 不要写成你本机上的 Finder、Windows 盘符或别的宿主机路径表示法

### 这页只写当前后端实际存在的命令

文中的命令都直接对齐后端当前 CLI 实现。  
如果某个任务只是由定时任务自动执行、但当前没有单独暴露手动命令，这页就不会硬写一个并不存在的命令。

## 查看状态与日志

### 查看容器状态

```bash
docker compose ps
```

适合先确认：

- `sakuramedia` 是否正常运行
- `sakuramedia-web` 是否正常运行
- `joytag-infer` 是否正常运行

### 查看后端日志

```bash
docker compose logs -f sakuramedia
```

适合排查：

- 服务启动失败
- 配置文件写错
- 数据库连接异常
- 定时任务报错

### 查看前端日志

```bash
docker compose logs -f sakuramedia-web
```

这个一般只在你怀疑 Web 容器没有正常启动时才需要看。

### 查看 API 持久化日志

```bash
tail -f ./docker-data/logs/api.log
```

如果你已经把日志目录持久化到了 `docker-data/logs`，这个命令会比 `docker compose logs` 更适合长期跟日志。

## 媒体库与导入

### 创建媒体库

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands add-media-library --name "主媒体库" --root-path /mnt/volume1/media/sakuramedia
```

说明：

- `--name` 是媒体库显示名称
- `--root-path` 是媒体库根目录在 SakuraMedia 容器内的绝对路径
- 这个目录通常应该是你准备用来承接新导入影片的目标目录
- 第一次创建媒体库时，建议先用一个专门目录，不要直接指向杂乱的历史媒体根目录

### 导入已有媒体

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands import-media --library-id 1 --source-path /mnt/volume1/media/av
```

说明：

- `--library-id` 是目标媒体库 ID
- `--source-path` 是你已有影片所在目录
- 命令会扫描目录、识别影片、导入到指定媒体库
- 这里的 `/mnt/volume1/media/av` 仍然是 SakuraMedia 容器内路径

适合场景：

- 你原来已经有一批历史影片
- 现在想把它们导入 SakuraMedia 管理

### 回填媒体元信息

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands backfill-media-metadata
```

说明：

- 用于给已有 `media` 记录补齐分辨率、时长、文件大小等缺失字段
- 这是幂等命令，可以重复执行
- 适合在导入一批历史媒体后跑一次

### 回填影片字幕记录

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands backfill-movie-subtitles
```

说明：

- 用于重新整理数据库中的影片字幕记录
- 会扫描影片和已有字幕关系，并补建或清理记录
- 更适合在你已经有字幕文件、但页面展示不完整时使用

### 巡检媒体文件

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands scan-media-files
```

说明：

- 用于按已有 `media.path` 巡检文件是否还存在
- 文件不存在时会把 `media.valid` 修正为 `false`
- 文件存在但视频信息缺失时，会补齐编码、码率等信息

如果你想把这次巡检作为“后台任务”记录到活动中心里，建议用后面的 `aps scan-media-files` 版本。

## 单次执行后台任务

这一组命令适合“我不想等下一个定时周期，现在就跑一次”。

格式统一是：

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps <task-name>
```

这类命令通常会把执行记录写进活动中心 / 任务中心，更适合观察进度和结果。

### 同步订阅女优影片

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps sync-subscribed-actor-movies
```

适合场景：

- 你刚订阅了一批女优
- 不想等夜间定时任务
- 想立刻把她们的影片信息同步进来

### 自动下载已订阅缺失影片

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps auto-download-subscribed-movies
```

适合场景：

- Jackett 和 qBittorrent 已经配置好
- 想立刻为“已订阅但本地缺失”的影片跑一次自动下载

### 同步合集影片标记

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps sync-movie-collections
```

适合场景：

- 你调整了合集番号特征
- 或者刚导入了一批影片，想立刻重新判断哪些属于合集

### 重算影片热度

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps update-movie-heat
```

适合场景：

- 你刚导入了一批影片
- 想立刻刷新排行榜、热门排序等依赖热度值的内容

### 同步影片互动数

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps sync-movie-interactions
```

适合场景：

- 想立刻回刷影片评分、想看数、评论数等互动统计
- 不想等下一个整点的自动同步
- 想让依赖互动统计的热度更快更新

### 同步排行榜

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps sync-rankings
```

适合场景：

- 想马上刷新本地排行榜数据
- 不想等下一个定时同步周期

### 同步 JavDB 热评

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps sync-hot-reviews
```

适合场景：

- 想立刻刷新热评页
- 刚部署完，想先把热评数据拉下来

### 生成媒体缩略图

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps generate-media-thumbnails
```

适合场景：

- 导入了历史影片
- 页面里还没有缩略图
- 想立刻为以图搜图和时刻相关能力准备数据

### 抓取影片字幕

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps fetch-movie-subtitles
```

适合场景：

- 想立刻为已订阅影片抓取字幕
- 不想等字幕任务的下一次定时执行

### 回填影片描述

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps sync-movie-desc
```

适合场景：

- 历史影片已经入库，但详情页里还缺原文描述
- 你刚补好了 DMM 代理，想立刻重跑一次描述回填
- 不想等每天清晨的描述回填任务

### 翻译影片简介

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps translate-movie-desc
```

适合场景：

- 原文描述已经补齐，但还没有中文简介
- 你刚配置好 OpenAI 格式的大模型接口，想立刻验证整批翻译链路
- 不想等每天清晨的自动翻译任务

### 生成以图搜图索引

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps index-image-search-thumbnails
```

适合场景：

- 缩略图已经生成
- 但以图搜图还搜不到结果
- 想立刻把待处理缩略图写入向量索引

### 优化以图搜图索引

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps optimize-image-search-index
```

适合场景：

- 你刚完成了一大批缩略图索引
- 想手动做一次索引优化

普通使用场景下，这条命令通常不需要频繁手动执行。

### 以后台任务方式巡检媒体文件

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands aps scan-media-files
```

这条命令和前面的普通 `scan-media-files` 作用相近，但它会以“后台任务”的形式运行，更方便在活动中心里看进度和结果。

## 外部服务测试命令

这一组命令更适合联调和排障。

- 不会初始化数据库
- 不会写任务记录
- 传入 `--json` 后更适合脚本集成或自动化检查

### 测试翻译模型接口

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands test-trans --text "これはテストです"
```

补充：

- 想从文件读取待翻译文本时，可以改用 `--text-file`
- 想拿稳定结构化输出时，可以加 `--json`
- 这个命令本质上是在测试你配置的 OpenAI 兼容大模型接口是否能正常响应

### 测试 JavDB

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands test-javdb --movie-number ABP-123
```

补充：

- 想输出 JSON 时，可以加 `--json`
- 如果你要强制走 metadata 代理，可以补 `--use-metadata-proxy`

### 测试 DMM

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands test-dmm --movie-number ABP-123
```

补充：

- 想输出 JSON 时，可以加 `--json`
- 实际是否可用强依赖 `metadata.dmm_proxy` 指向可用的日本 IP 代理
- 如果代理不是日本 IP，DMM 描述抓取通常会失败或结果不稳定

## 相关页面

- 后台任务的默认频率和作用见 [后台任务](/guide/tasks)
- `config.toml` 字段说明见 [配置说明](/guide/config)
- 部署路径、多硬盘和 OpenVINO 相关内容见 [进阶部署](/guide/docker)
