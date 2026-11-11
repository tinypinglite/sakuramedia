---
outline: [2, 3]
---

# 快速开始

这份指引从零部署 SakuraMedia 后端，并把宿主机上已有的影片导入媒体库。完成基础流程后，可以按需继续配置自动下载和向量服务。

只想先跑通导入和播放时，完成阶段 1、2 即可。自动下载、以图搜图、115 网盘等属于可选扩展，见下方两节和[推荐插件](/zh-CN/guide/plugins)。

## 开始前

- 一台持续运行的主机或 NAS，已安装 Docker 和 Docker Compose。
- 一个 SSD 目录存放后端运行数据（数据库、配置、日志、插件）。
- 客户端从 [GitHub Releases](https://github.com/tinypinglite/sakuramedia/releases/latest) 下载。

## 阶段 1：部署后端

### 1. 准备目录

#### 1.1 准备运行数据目录

首先在固态硬盘(推荐)中建立一个空的目录，并在里面建立一个 `sakuramedia-data` 目录，这个目录将用来存储 `sakuramedia` 运行时的文件，不包含媒体文件。

#### 1.2 准备媒体文件存放目录

这里假设你已经有一部分影片了，存放在 `/mnt/av` 下，我们需要在 `av` 这个目录的父目录下建一个 `media` 目录，之后我们添加媒体库时就用这个目录，之后自动下载和导入的影片都会存放在这个目录，**请不要手动往这个目录添加文件或修改其中的文件**

#### 1.3 准备qBittorrent下载的目录

为了在导入时能够正确的硬链接文件，建议将 qBittorrent 的下载目录设置到和 `media` 目录也就是媒体库根目录的同级目录下。比如 `/mnt/downloads`

最终的目录结构示例：

```text
/mnt
├── av/          # 已有影片（示例名，换成你的实际目录）
├── media/       # 之后创建 sakuramedia 媒体库用
└── downloads/   # qBittorrent 容器的下载目录
```

按这种目录设计，在下一步的挂载中**仅需要挂载 `/mnt`** 就可以同时把已有影片目录和后续媒体库目录以及 qBittorrent 下载目录一起挂载进去。

### 2. 写 `compose.yaml`

在 `sakuramedia-data` 目录的同级目录下新建 `compose.yaml`文件，填入以下内容，注意`sakuramedia`容器的`volumes` 需要按你的实际情况修改。 

```yaml
services:
  postgres:
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
      # 需要使用其他宿主机端口时修改左侧的 38000。
      - "38000:8000"
    environment:
      # 如果你知道 PUID/PGID 的含义，可以改成和宿主机用户一致。
      PUID: 0
      PGID: 0
      # 不使用中国时区时修改为宿主机所在时区。
      TZ: "Asia/Shanghai"
      # 若部署机器无法直连 GFriends，取消下方三行注释并填入代理地址。
      # HTTP_PROXY: "http://192.168.1.1:7890"
      # HTTPS_PROXY: "http://192.168.1.1:7890"
      # NO_PROXY: "localhost,127.0.0.1"
      MALLOC_TRIM_THRESHOLD_: "131072"
    volumes:
      - ./sakuramedia-data:/data # 这行一般不需要动
      # 宿主机上包含「已有影片目录」和「媒体库目录」的父目录，按实际情况修改，这里按上文的假设来
      - /mnt:/mnt
```

::: danger 保存前必须修改
- 把 `/mnt` 改成宿主机上包含「已有影片目录」和「媒体库目录」的父目录，必须是绝对路径。
- 不使用中国时区时修改 `TZ`。
- 如果 SakuraMedia 以非 root 运行，确保 PUID/PGID 对 你挂载的媒体目录(示例中是`/mnt`) 有读写权限。
:::

SakuraMedia 的 `/data` 是后端运行数据，`/mnt`下才是媒体数据，建议放机械盘。

::: tip 数据库
后端默认按 `postgres` 服务名连接内置 PostgreSQL，照抄示例即可运行。使用外部 PostgreSQL 时，按[配置说明](/zh-CN/guide/config#database)修改 `[database].url`。
:::

### 3. 启动

```bash
# 进入 compose.yaml 所在目录
cd /path/to/compose-directory
docker compose up -d
docker compose ps
```

首次启动会自动建表。`docker compose ps` 中 `postgres` 为 `healthy`、`sakuramedia` 为 `running` 后，打开客户端，首次登录时填写后端地址：

```text
http://你的IP:38000
```

默认用户名和密码是 `account` 和 `account`。登录后建议立即修改密码。

::: tip 元数据插件
当前版本要求所有插件声明 Host API 18。安装兼容的元数据插件后，在「设置 → 元数据源」调整调用顺序即可按番号搜索和导入影片。演员搜索使用后端内置的 GFriends 索引。
:::

## 阶段 2：创建媒体库并导入已有影片

官方镜像已经预装并启用「本地存储与 qBittorrent」，不需要再上传插件。

### 1. 创建媒体库

「系统设置 → 媒体库 → 新增」，选择「本地存储与 qBittorrent」，填写：

| 字段 | 填写 | 对应宿主机目录 |
|---|---|---|
| 媒体库路径 | `/mnt/media` | `/mnt/media` |
| 手动导入根目录(也就是已有影片的存储目录) | `/mnt/av` | `/mnt/av` |

媒体库路径是影片导入后的最终目录；手动导入根目录是在APP中进行资源导入时浏览的根目录。

### 2. 导入已有影片

「管理 → 资源导入」→「JAV 影片」→「新建导入」→ 选择刚才的媒体库 → 在来源浏览器中选中影片文件或目录 → 选择导入方式 → 开始导入。

三种导入方式：

| 方式 | 实际行为 | 源文件 | 适合 |
|---|---|---|---|
| 保留源文件 | 优先硬链接；不能硬链接时回退到复制 | 保留 | 同一挂载点，想省空间、保持做种 |
| 导入成功后删除源文件 | 复制到媒体库，成功后删除源文件（效果等同移动） | 删除 | 不想保留原件 |
| 原地导入 | 不复制也不硬链接，媒体直接引用源文件 | 不动 | 文件已整理好，不想动 |

- **保留源文件**：同一挂载点且文件系统支持硬链接时，导入几乎瞬间完成，不占额外空间；不能硬链接时会复制，导入慢一些，并占用双倍空间。
- **导入成功后删除源文件**：先复制到媒体库，导入成功后再删除源文件；导入期间会临时占用双倍空间，但跨文件系统也能用。选择前确认文件没有在做种或被其他程序使用。
- **原地导入**：只支持从手动导入目录导入；之后移动、重命名或修改源文件，媒体会失效；删除 SakuraMedia 中的媒体记录不会删除源文件。

第一次导入建议先选一个小目录，用「保留源文件」验证流程。

提交后在「任务中心」查看进度。导入成功后打开影片详情，确认媒体出现并能播放。

导入任务均为一次性任务，后续源目录如果发生变化， 比如新增了新的影片之类的，不会自动导入。

## 可选：自动下载与索引器

完成上面的部署和媒体库创建后，配置好下载器和索引器，SakuraMedia 才能为订阅的影片自动寻找资源、提交下载并导入媒体库。本节以本地存储和 qBittorrent 为例。

### 需要准备

- 一个可访问的 qBittorrent，和 SakuraMedia 在同一台机器上（本机 Docker 或 NAS 套件）。
- 一个 Jackett 或 Prowlarr 索引器。
- 想使用硬链接时，下载目录和媒体库需要在同一个挂载点下。

### 1. 让 qBittorrent 和 SakuraMedia 看到同一个下载目录

上面的基础部署把媒体库目录设为 `/mnt/media`，并把包含它的父目录 `/mnt` 挂载进了 `sakuramedia` 容器。qBittorrent 容器的下载目录也需要位于同一个挂载点下的 `/mnt/downloads`；这里假设你的 qBittorrent 也是 Docker 部署的，它的下载设置中下载目录是 `/downloads`，那么要确保 **qBittorrent 中的这个下载目录对应到宿主机就是 `/mnt/downloads`**。

### 2. 添加下载器

「系统设置 → 下载器 → 新增」，选择目标媒体库：

| 字段 | 填写 |
|---|---|
| qBittorrent 地址 | qB 在宿主机：`http://宿主机IP:8080`（按你的 qB WebUI 端口）；qB 和 SakuraMedia 在同一 compose：`http://qbittorrent:8080` |
| 用户名 / 密码 | qBittorrent WebUI 的登录信息 |
| qBittorrent 保存根目录 | `/downloads` 注意这里需要按你实际的情况来 |
| 后端下载根目录 | `/mnt/downloads`  也就是`sakuramedia` 看到的同一个下载目录，在宿主机上需要是同一个目录。 |

保存前点「测试配置」，确认目录映射和硬链接通过。目录映射失败通常是两个根目录没有指向同一个物理目录；

<Screenshot src="/images/guide/download-client-form.png" alt="添加下载器表单" caption="界面示意：添加下载器时选择目标媒体库，并填写插件提供的配置字段。" />

### 3. 配置索引器并绑定下载器

「系统设置 → 索引器 → 新增」。「资源地址」要填完整的 Torznab 地址，不要填网站或聚合器的首页：

| 来源 | 资源地址 | API Key |
|---|---|---|
| Jackett | 站点对应的「Copy Torznab Feed」 | 面板右上角复制 |
| Prowlarr | 索引器列表的 RSS 图标地址，形如 `http://<主机>:9696/<索引器ID>/api?apikey=...` | 地址已包含 `apikey`，可留空 |

保存后绑定一个或多个下载器（第一个作为默认下载目标），再点「测试 Torznab 连通性」。

### 4. 验证

1. 在「概览」页运行「组件诊断」，确认媒体库和索引器的连通性；下载器用下载器页的「测试配置」单独检查。
2. 订阅一部影片，等待后台任务查询资源。
3. 想主动验证自动流程时，在任务中心手动触发「已订阅缺失影片自动下载」，然后查看运行结果。没有合适资源时，任务运行完成也不代表成功下载。

完整流程见[获得第一部想看的影片](/zh-CN/manual/first-movie)。导入已有影片不需要这一步，见[导入已有资源](/zh-CN/manual/import)。

## 可选：向量服务与 SigLIP2 硬件方案

以图搜图和相似影片依赖 Qdrant 与 SigLIP2 嵌入服务。本文示例中的 CPU 镜像适用于 AMD、Intel 和 ARM64 主机。SigLIP2 镜像已包含模型和运行时，**不需要**下载模型、挂载模型目录或预先缩放图片。服务启动时会按镜像内安装的运行时自动选择推理后端，不需要配置。

后端和嵌入服务在同一个 Compose 项目中时，不需要映射端口；后端默认通过 `http://siglip2-embed:8080` 访问服务。

### 按需启用

基础部署不需要这两个服务。仅需相似影片时启动 Qdrant 并在桌面高级设置中开启「相似影片与向量服务」；需要图搜时再部署 SigLIP2，开启「图片与文字搜图」。完整 Compose 见下方[完整 Compose 示例](#完整-compose-示例)。保存后需重启后端容器。

缩略图与时刻收藏独立保留。每日推荐和时刻推荐在关闭向量能力后仍使用其他候选信号。重新启用时保留原索引；关闭期间发生删除或更新的，应在「系统设置 → 系统维护」重建图搜索引，并在任务中心运行「影片相似度重算」。

### 完整 Compose 示例

在上面的基础 compose 中追加以下两个服务。基础部署不需要它们；只有启用相似影片或图搜时才需要。ARM 平台不建议启用以图搜图。

```yaml
  qdrant:
    image: qdrant/qdrant:v1.12.4
    container_name: qdrant
    restart: unless-stopped
    environment:
      QDRANT__SERVICE__HTTP_PORT: "6333"
      QDRANT__LOG_LEVEL: "INFO"
    volumes:
      - ./sakuramedia-data/image-search-index:/qdrant/storage
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

  siglip2-embed:
    image: tinyping/siglip2-embed-service:cpu
    container_name: siglip2-embed
    restart: unless-stopped
    environment:
      CPU_CONCURRENCY: "1"
      MALLOC_TRIM_THRESHOLD_: "131072"
      # 内存不够可尝试设为 false，降低文字搜图的内存占用。
      TEXT_TOWER_ENABLED: "true"
```

### Intel 核显

适用于 Linux amd64 的 Intel 核显主机。将上面的 `siglip2-embed` 服务替换为：

```yaml
  siglip2-embed:
    image: tinyping/siglip2-embed-service:intel
    container_name: siglip2-embed
    restart: unless-stopped
    devices:
      - /dev/dri:/dev/dri
    group_add:
      # 换成宿主机 render 组的实际 GID（getent group render）
      - "0"
    environment:
      CPU_CONCURRENCY: "1"
```

在宿主机执行 `getent group render` 查看 `render` 组的 GID，把上面 `group_add` 里的数字改成该 GID（例如 `- "105"`）。确认 `/dev/dri` 存在后再启动容器。

### NVIDIA CUDA

宿主机需要已安装 NVIDIA 驱动、`nvidia-container-toolkit`，且 `nvidia-smi` 能正常显示显卡。将上面的服务替换为：

```yaml
  siglip2-embed:
    image: tinyping/siglip2-embed-service:cuda
    container_name: siglip2-embed
    restart: unless-stopped
    gpus: all
    environment:
      CPU_CONCURRENCY: "1"
```

若容器启动后没有使用 GPU，先检查 `docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi` 是否成功，再检查 NVIDIA Container Toolkit 配置。

### 只做图片搜图：关闭文本塔

SigLIP2 默认同时加载图片塔与文本塔。只检索相似图片、不需要文字搜画面时，可以在 `siglip2-embed` 的 `environment` 中加上：

```yaml
      TEXT_TOWER_ENABLED: "false"
```

服务启动时会跳过文本编码器与 tokenizer，只保留图片塔，内存占用更低。文字搜画面会失败（文本接口返回 503），图片搜图、相似图片和图片索引都不受影响。改回 `"true"` 或删掉这一行并重启容器即可恢复。

### 将嵌入服务部署到其他主机

仅在后端与 SigLIP2 不在同一个 Compose 网络时才需要映射端口，例如添加：

```yaml
    ports:
      - "8080:8080"
```

然后在桌面高级设置中将 SigLIP2 地址改为该服务的可访问 HTTP 地址，按需填写 API Key，保存后重启后端。Qdrant 同样支持远程地址；使用远程服务时不必启动对应的本地容器。

## 下一步

- 导入更多影片：[导入已有资源](/zh-CN/manual/import)
- 自动下载后的完整订阅流程：[获得第一部想看的影片](/zh-CN/manual/first-movie)
- 以图搜图操作：[从一张画面发现更多内容](/zh-CN/manual/image-search)
- 115 网盘和其他插件：[推荐插件](/zh-CN/guide/plugins)
- 字段和任务频率：[配置说明](/zh-CN/guide/config)、[后台任务](/zh-CN/guide/tasks)
