---
outline: [2, 3]
---

# 常用命令

这页整理的是 SakuraMedia 服务跑起来之后，最常用的几个命令。

## 账号

### 重置账号（忘记用户名 / 密码）

```bash
docker exec -it --user app -w /app sakuramedia python -m src.start.commands reset-account
```

执行后会分别提示输入新的**用户名**和**密码**（密码是隐式输入并要求二次确认）。如果不想交互式输入，也可以直接把两个参数带在命令行里：

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands reset-account --username admin --password 'your-new-password'
```

说明：

- 这条命令是**覆盖式重置**：会先删掉数据库里所有已有账号，再按你给的用户名和密码重建一个单账号
- 同时会清空所有 refresh token，**已登录的客户端会立即失效**，需要用新账号重新登录
- 不校验旧密码，忘记用户名或忘记密码时都能用；整个过程在一个事务里，中途失败会回滚，不会出现“旧账号删了、新账号没建”导致完全登不上
- 用户名不能为空、密码不能为空，命令行传值时注意用单引号包住带特殊字符的密码



## 存量数据迁移

::: warning 只有从老版本升级上来的用户才需要跑
本节命令都是**一次性升级迁移**，用来把老结构的存量数据搬到新结构上：

- **后端 v0.4.6 及之后版本首次部署的**：新入库数据从一开始就是新结构，**不用跑**
- **从更早版本升级上来的**：按下面步骤跑一次即可，跑完就不用再管了

命令都是幂等的，重跑会自动收敛；Ctrl+C 中断或容器崩溃后重跑也能接着走。
:::

### 剧照路径平铺

老版本的影片剧照落在 `movies/<番号>/plots/N.ext`，30 万条规模下会额外产生 30 万个空的 `plots/` 中间目录。新版本改成同层平铺的 `movies/<番号>/plot-N.ext`，这条命令用来把存量数据搬过来。

**先 dry-run 预览规模**（不会动任何文件和数据库）：

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands migrate-plot-layout --dry-run
```

确认统计合理后再真跑：

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands migrate-plot-layout
```

要点：

- **进度会持续打日志**：service 侧每 1000 行或每 10 秒打一次心跳（`current/total`、速率、剩余时间），CLI 侧还会额外打点，30 万条规模下也不会静默
- **可中断重跑**：`image.origin` 的单条 UPDATE 是原子提交点，Ctrl+C 或崩溃后重跑会把中间态（文件已改名、数据库未更新）自动补齐
- **失败不阻塞**：`images_failed` / `images_data_lost` / `images_conflict_skipped` 都只累计在结果统计里，不会让整条命令挂掉；跑完看输出再决定要不要人工排查具体条目
- **不进服务生命周期**：这条命令不会随服务启动自动执行，也没有进数据库迁移框架 —— 30 万条规模下大事务会把 PostgreSQL 的 WAL 打满并让容器 healthcheck 超时，评估后放弃自动迁移

### 影片资产目录分片

老版本的影片封面、剧照、缩略图都放在 `movies/<番号>/` 下，`movies/` 是**单层平铺**目录，一部影片一个子目录。番号规模到 30 万时，`ls` / `du` / `rsync` / `tar` 备份 / Docker 卷迁移全都会因为顶层条目数太多而明显变慢。新版本按 `sha1(番号)` 十六进制前 2 位分成固定 **256 片**：`movies/<shard>/<番号>/`，顶层条目数恒为 256。

::: tip 不迁移也能正常用
不跑这条命令服务照常运行——新入库的资产直接落分片目录，老资产继续留在 `movies/<番号>/`，读写路径同时兼容两种布局。只有当你觉得**卷备份 / 目录巡检 / 大规模 rsync 明显变慢**时才需要迁移；小库（几千部以内）无感，不跑也没关系。
:::

**先 dry-run 预览规模**（不会动任何文件和数据库）：

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands migrate-movie-asset-shard --dry-run
```

确认统计合理后再真跑：

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands migrate-movie-asset-shard
```

要点：

- **两阶段**：先把每个番号目录整目录 `rename` 进对应分片（同一文件系统内原子），再按主键分页批量重写 `image.origin` 前缀；不搬文件内容，只挪目录 + 改字符串前缀，30 万番号也很快
- **可中断重跑**：已归片的番号目录不再出现在 `movies/` 顶层，重跑天然跳过；数据库侧只重写老布局行，已分片的行不会被重复处理
- **不进服务生命周期**：和剧照迁移同一模式，不随服务启动自动执行，也没进数据库迁移框架
- **建议在下面的字幕迁移之前跑**：这样字幕迁移的目标目录一开始就是分片布局（不是硬性顺序，反过来也能收敛，只是要多一次目录合并）

### 字幕位置统一

老版本的字幕散在两处：本地导入的作为 sidecar 跟视频放在媒体库 `<库根>/jav/<番号>/<版本时间戳>/<番号>.srt`；115 云盘导入的落在旧字幕根 `<旧字幕根>/<番号>/<编码名>.srt`。新版本统一收敛到 `movies/<shard>/<番号>/subtitles/<番号>-<N>.srt`（N 从 1 递增），**字幕跟番号走而不跟具体媒体文件走**——媒体文件被删除或失效不会连带清掉字幕。

::: tip 不迁移也能正常用
不跑这条命令服务照常运行——运行时同时放行**新布局**和**两处老位置**（115 旧字幕根、媒体库里视频所在版本目录的 sidecar），存量字幕继续可读，新导入的字幕直接落新布局。只有当你想**把字幕从媒体库子目录里拆出来单独管理**、或者想清空旧字幕根目录时才需要迁移。
:::

**先 dry-run 预览规模**（不会动任何文件和数据库）：

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands migrate-movie-subtitles --dry-run
```

确认统计合理后再真跑：

```bash
docker exec --user app -w /app sakuramedia python -m src.start.commands migrate-movie-subtitles
```

要点：

- **命名分配**：按影片分组处理，每部影片下一个 seq 分配器从当前 `subtitles/` 目录已有 `<番号>-<N>.srt` 最大 N + 1 起分配；同一部影片下多份字幕（如 whisperjav 的 `.chinese.srt` + `.srt`、跨版本目录的同名 srt）都会拿到不同 N，天然不撞车
- **单文件三步**：先把 `.srt` 硬链接（同一文件系统）或复制（跨文件系统）到新路径 → `UPDATE subtitle.file_path` → 删旧文件；`file_path` 的单条 UPDATE 是原子提交点，硬链接语义保证即使中途掉电文件也一定被至少一条路径 hold 住
- **可中断重跑**：已在新目录且文件名符合 `<番号>-<N>.srt` 的行走 fast-path 跳过；老一轮迁移遗留的 `<版本时间戳>.srt` 命名会被本轮自动改名收敛
- **失败不阻塞**：`subtitles_failed` / `subtitles_data_lost` 只累计在结果统计里，不会让整条命令挂掉；`data_lost` 通常是 DB 里 subtitle 行指向的物理文件已被删除（sync 后续会清）
- **建议在上面的资产分片迁移之后跑**：这样目标目录一开始就是分片布局
- **跑完后旧字幕根可以清空**：`/data/cache/subtitles/` 里对应的番号目录会被逐个 `unlink` 清掉；配置项 `media.subtitle_root_path` 是 legacy 目录，存量搬完后可以从 `config.toml` 里删掉，运行期不再有任何写入

