---
outline: [2, 4]
---

# 轻量部署（不用自动下载）

如果你**不想部署 qBittorrent、也不想配 Jackett**，只是想把 SakuraMedia 当作 NAS 上的 JAV 影片管理/播放工具用，这一页给你一条最小可用的部署路径。

不用担心「缺组件」——SakuraMedia 的下载链路和索引器都是**可选能力**，不配就是不启用，后端不会因此启动失败，其它功能全都能正常工作。

::: tip 这一页适合谁
- 你已经有一批 JAV 影片资源，想要一个**能自动识别番号、抓元数据、按女优组织、能翻译标题简介**的工作台
- 你的资源用别的工具（手动、其它下载器、朋友那里拷贝）拿到，**不需要项目帮你自动找种/自动下载**
- 你希望**部署尽量简单**，能少一个服务是一个

如果你想要「订阅 → 自动找种 → 自动下载 → 自动导入」的全链路自动化，这一页不适合你，请看[快速开始](/guide/quick-start)。
:::

## 你会得到什么 / 放弃什么

| 能力 | 轻量部署 | 说明 |
|---|---|---|
| 已有影片一键导入（含元数据抓取） | ✅ | 从「媒体导入」页浏览挂载的 `/mnt` 目录直接导入 |
| 影片浏览、搜索、女优/番号/系列信息 | ✅ | 联网搜索 JavDB / DMM 元数据、GFriends 女优头像 |
| 影片订阅 / 女优订阅 / 上新追踪 | ✅ | 订阅仅表示"关注"，不会自动去下载 |
| 播放（含硬解，桌面/移动/Web） | ✅ | 客户端解码，不依赖服务端转码 |
| 缩略图预览、切片收藏、切片合集 | ✅ | 仍需 ffmpeg / 缩略图任务，容器已内置 |
| 以图搜图（相似画面探索） | ✅（可选） | 需要额外部署 `joytag-infer` + `qdrant`；不想要可以砍掉 |
| 中文标题 / 中文简介 翻译 | ✅（可选） | 需要一个 OpenAI 兼容的 LLM API；不用就关掉 |
| PornBox 视频（非 JAV）纳管 | ✅ | 与 JAV 平行的合集管理 |
| **自动找种 / 自动下载 / 自动导入** | ❌ | 需要 qB + Jackett；这一页专门省掉的部分 |
| Jackett 手动搜索种子 | ❌ | 同上 |

::: tip 订阅仍然有用
即使不启用自动下载，「订阅」也不是白订阅——它决定了「女优上新」页面看谁的更新、以及影片详情页的关注状态。将来你如果加了 qB + Jackett，历史订阅会**直接触发第一批自动下载**，不需要重新订阅一遍。
:::

## 准备工作

### 必备

- 一台 Linux NAS（飞牛 OS / 常见 Linux 发行版；ARM 架构现已支持但尚未经过测试，可自行尝试；Windows 理论上可以，未经测试）
- 已安装 `Docker` 和 `Docker Compose`
- **一个已有影片目录**，或一个准备用来放媒体库的空目录
- 一个 SSD 目录用来放运行时数据（数据库、缓存、配置、日志、图片索引）

### 可选

- **以图搜图**：额外的 `joytag-infer` 推理服务和 `qdrant` 向量库，本页 compose 里已经带上，不需要可整段删掉
- **中文标题 / 简介翻译**：任意一个兼容 OpenAI 格式的 LLM API（推荐 `Gemma 4 31B`，见[常见问题](/faq#movie-desc-translation-model)）

### 硬件建议

以下数字来自一台跑了一段时间、约 2 万部影片元数据 / 3 千多部可播放媒体 / 170 万张缩略图规模的实际部署，供你估算最低配置。

#### 档 A：只做元数据 + 播放（3 个服务）

- 运行的容器：`postgres` + `sakuramedia` + `sakuramedia-web`
- 空闲态内存合计约 **500~700 MB**（三者相加：数据库 ~300MB、后端 ~320MB、Web ~10MB）
- 高峰在「大批量导入 + 元数据抓取」时，默认 3 并发抓取，可能吃到 1 GB 上下
- **建议配置：2 核 2 G 起步；4 核 4 G 更宽裕，能同时应付导入并发和后台任务**
- 数据库磁盘：**≈ 1 GB / 万部影片元数据**（不含影片文件本身）

#### 档 B：加以图搜图（5 个服务）

- 在档 A 基础上再跑 `joytag-infer` + `qdrant`
- 空闲态内存合计约 **2 GB**（joytag 空闲 ~440MB、qdrant 空闲 ~1GB）
- 缩略图生成默认最多 4 并发 ffmpeg 截帧，任务跑起来时 CPU 会被吃满
- **建议配置：4 核 8 G 起步；核显 / 独显能让 joytag 推理更快，见[进阶部署](/guide/docker#openvino-方案)**
- 存储磁盘：
  - `joytag` 模型文件 **≈ 300 MB**（`model_vit_768.onnx`）
  - `qdrant` 图片向量库 **≈ 3~4 GB / 百万张缩略图**
  - 缩略图 JPEG 缓存本身也会占一大块，跟你的可播放媒体规模成正比（默认每 10 秒一帧）

::: tip 内存不够但想用以图搜图？
可以先按档 A 起，之后再往 `compose.yaml` 里补 `joytag-infer` 和 `qdrant`。历史缩略图会在后台任务里逐步补建索引，不需要重新导入影片。
:::

::: warning 缩略图和向量库随规模线性增长
上面「≈ 3~4 GB / 百万张缩略图」是可播放影片积累起来之后的量级；刚部署时你可能只有几百上千张缩略图，qdrant 占用几十兆而已。随着你把影片入库、缩略图慢慢生成，这两块磁盘和内存都会缓慢增长，建议把 `sakuramedia-data` 放在有余量的 SSD 上，而不是刚好够用的挂载点。
:::

## 部署步骤

### 1. 创建数据目录

准备一个 SSD 目录放运行时数据（下方假设是 `/mnt/ssd/sakuramedia`）：

```bash
cd /mnt/ssd/sakuramedia
mkdir -p sakuramedia-data/{cache,logs,config,joytag,media-clips,image-search-index,postgres} sakuramedia-data/cache/{assets,subtitles,gfriends}
```

### 2. 准备 JoyTag 推理模型（可选）

**只有你想启用以图搜图才需要这一步。** 不需要以图搜图，直接跳到下一步，`joytag-infer` 和 `qdrant` 两个服务也一并从 compose 里删掉即可。

```bash
cd sakuramedia-data/joytag
wget -O model_vit_768.onnx https://github.com/tinypinglite/sakuramediabe/releases/download/model/model_vit_768.onnx
```

### 3. 准备 `compose.yaml`

假设你已有的影片目录挂在宿主机的 `/mnt/volume1/media/av`（或整块媒体盘的根 `/mnt/volume1/media`），下面的示例把这块**已有影片目录**整体挂进容器。

::: tip 挂载路径必须在 `/mnt` 下
容器内路径**必须以 `/mnt/` 开头**，否则「媒体导入」页浏览不到你的影片。建议宿主机路径和容器内路径写成一样，省得后面创建媒体库时脑内换算。

与全量部署不同：**你不需要挂载下载目录**（没有下载器），也不需要担心「下载目录和媒体库跨盘」的硬链接问题。
:::

在 `/mnt/ssd/sakuramedia/compose.yaml` 里填入：

```yaml
services:
  postgres:
    # 服务名保持 postgres，后端默认按这个主机名连接数据库，照抄即可零配置
    image: postgres:16-alpine
    container_name: sakuramedia-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: sakuramedia
      POSTGRES_USER: sakuramedia
      POSTGRES_PASSWORD: sakuramedia
    volumes:
      - ./sakuramedia-data/postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sakuramedia -d sakuramedia"]
      interval: 10s
      timeout: 5s
      retries: 10

  sakuramedia:
    image: tinyping/sakuramediabe:latest
    container_name: sakuramedia
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "38000:8000" # API 服务端口
    environment:
      # 如果你知道 PUID/PGID 的含义，可用 `id -u` 和 `id -g` 查询
      # 如果你不懂，就保持默认 0/0（root）
      PUID: 0
      PGID: 0
      TZ: "Asia/Shanghai"
    volumes:
      - ./sakuramedia-data:/data
      # 已有影片目录，容器内路径必须在 /mnt 下；建议宿主机和容器内保持一致
      - /mnt/volume1/media:/mnt/volume1/media

  # 以下两个服务用于以图搜图；不需要可以整段删掉
  joytag-infer:
    image: tinyping/joytag-infer:cpu
    container_name: joytag-infer # 不要改名
    restart: unless-stopped
    environment:
      JOYTAG_INFER_BACKEND: "cpu"
      JOYTAG_INFER_MODEL_PATH: "/data/lib/joytag/model_vit_768.onnx"
      JOYTAG_INFER_API_KEY: ""
    volumes:
      - ./sakuramedia-data/joytag:/data/lib/joytag

  qdrant:
    image: qdrant/qdrant:v1.12.4
    container_name: qdrant # 不要改名
    restart: unless-stopped
    environment:
      QDRANT__SERVICE__HTTP_PORT: "6333"
      QDRANT__LOG_LEVEL: "INFO"
    volumes:
      - ./sakuramedia-data/image-search-index:/qdrant/storage

  sakuramedia-web:
    image: tinyping/sakuramedia-web:latest
    container_name: sakuramedia-web
    restart: unless-stopped
    depends_on:
      - sakuramedia
    ports:
      - "38080:80"
```

::: tip 想要更精简？
如果连以图搜图都不打算用，把 `joytag-infer` 和 `qdrant` 两个 service 整段删掉即可，最终只留 `postgres` / `sakuramedia` / `sakuramedia-web` 三个服务。后端会跳过缩略图索引任务，其它功能不受影响。
:::

### 4. 启动

```bash
docker compose up -d
```

### 5. 访问

默认账号密码是 `account` / `account`，登录后建议第一时间修改。

- **浏览器（Web 端）**：`http://你的IP:38080`
- **桌面端 / 移动端 APP**：从 [GitHub Releases](https://github.com/tinypinglite/sakuramedia/releases) 下载后，首次登录填**后端 API 地址** `http://你的IP:38000`（不是 `38080`）

## 首次登录后的最小初始化

轻量部署只需要两步初始化，跟全量部署省掉了「添加下载器」和「配置 Jackett」两块。

### 1. 创建媒体库

进入「配置」页面，创建一个新的媒体库。假设你想把已识别的 JAV 影片整理到 `/mnt/volume1/media/sakuramedia`：

```text
/mnt/volume1/media/sakuramedia
```

后端会自动在这个目录下按 `女优/番号/` 的结构组织文件。原有的 `/mnt/volume1/media/av` 里的已有资源会通过硬链接（同盘）或复制（跨盘）落进来，**不会挪动或删除源文件**。

### 2. 导入已有媒体

进入「管理 → 媒体导入」页，选择「JAV 影片」标签，浏览挂载进来的 `/mnt/volume1/media/av`（或你的实际影片目录），选择要纳管的子目录 → 目标媒体库选刚创建的那一个 → 提交。

后端会异步执行：

1. 扫描视频文件 → 从文件名解析番号
2. 联网抓取 JavDB / DMM 元数据（首次抓完就存本地库）
3. 通过硬链接/复制把文件落进媒体库结构里
4. 后台跑缩略图生成（默认每 10 秒一帧）
5. 如果启用了以图搜图，缩略图会异步进入向量索引
6. 如果启用了翻译，会异步补 `title_zh` / `desc_zh`

进度可以在「活动中心 → 任务中心」看。

### 3. 跑一次组件诊断（可选）

「总览」页顶部的「组件诊断」横条点「开始检测」，会一键检测各组件连通性。

::: warning 下载器 / 索引器项标黄是**预期状态**
轻量部署下：

- **下载器（qBittorrent）** 会显示「未配置」——**这是正确的**，不用管
- **索引器（Jackett）** 会显示「未配置」——**同样是正确的**
- **LLM 翻译**：如果你没开翻译，也会标黄，忽略即可
- **JoyTag**：如果你砍掉了这两个服务，也会标黄

其它项（媒体库、JavDB / DMM）应该是绿色。如果出现红色，才需要按提示排查。
:::

## 之后想加自动下载怎么办

**不需要重装、不需要迁移数据**。你随时可以：

1. 单独部署 qBittorrent + Jackett（可以在同一个 compose 里加，也可以另起）
2. 把 qB 的下载目录挂载进 SakuraMedia 容器，路径规划见[进阶部署 → 推荐部署思路](/guide/docker#推荐部署思路)
3. 在 SakuraMedia 里添加下载器 + 配 Jackett，参考[快速开始 → 添加 qBittorrent 下载器](/guide/quick-start#_2-添加-qbittorrent-下载器)

添加完成后，**你之前订阅过的、本地还没有媒体的影片**会在下一次「已订阅缺失影片自动下载」任务里自动进入下载队列（默认凌晨 2:30 跑一次，也可以在活动中心手动触发一次 `auto-download-subscribed-movies`）。

## 相关页面

- 完整部署路径（含自动下载）：[快速开始](/guide/quick-start)
- 各配置项含义：[配置说明](/guide/config)
- 想手动跑一次某个后台任务：[常用命令](/guide/commands)
- 影片信息翻译推荐模型：[常见问题 → 做影片信息翻译时，推荐用什么模型？](/faq#movie-desc-translation-model)
