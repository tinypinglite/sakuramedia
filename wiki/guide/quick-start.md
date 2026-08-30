---
outline: [2, 4]
---

# 快速开始

这是一份“先把服务跑起来”的快速指引，覆盖 SakuraMedia 的「搜索 → 订阅 → 下载 → 导入」主流程，以及以图搜图功能。

## 准备工作

#### 必备

- 一台持续运行的主机或 NAS。
- 已安装 `Docker` 和 `Docker Compose`。
- 按需准备索引器和下载 provider。可用 provider 由已安装插件提供，前置条件和配置字段以插件说明为准。
- 如果 provider 需要访问宿主机目录或远端存储，按 provider 的部署说明准备凭据和挂载；SakuraMedia 不要求统一的本地目录结构。

### 硬件要求

- CPU 建议 4 核，可用内存不少于 4 GB；SigLIP2 嵌入服务和 Qdrant 会消耗额外内存。
- SSD 用于运行数据（数据库、配置、日志、缓存和图片索引）。
- 媒体存储空间由所选 provider 管理，容量按实际库规模准备。

### 部署后会有 4 个服务

- `sakuramedia`：后端服务，负责媒体管理和任务调度等核心能力。
- `postgres`：PostgreSQL 数据库，存储业务数据。
- `siglip2-embed`：以图搜图嵌入服务，负责图片与文本向量化。
- `qdrant`：图片搜索向量数据库，存储缩略图向量并提供检索。

## 部署后端服务

### 1. 创建数据目录

准备一个目录存放运行时数据和 `compose.yaml`，例如：

```bash
mkdir -p /mnt/ssd/sakuramedia/sakuramedia-data/{cache,logs,config,media-clips,image-search-index,postgres,plugins}
mkdir -p /mnt/ssd/sakuramedia/sakuramedia-data/cache/{assets,gfriends}
```

### 2. 准备 `compose.yaml`

下面的示例只挂载应用运行数据。需要额外挂载目录时，按已安装 provider 的部署说明添加，并在 provider 配置中填写其要求的字段。

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
    image: tinyping/sakuramediabe:v0.6.0
    container_name: sakuramedia
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "38000:8000"
    environment:
      PUID: 0
      PGID: 0
      TZ: "Asia/Shanghai"
      # 需要为 JavDB / GFriends 配置代理时再填写。
      # HTTP_PROXY: "http://192.168.1.1:7890"
      # HTTPS_PROXY: "http://192.168.1.1:7890"
      # NO_PROXY: "localhost,127.0.0.1"
    volumes:
      - ./sakuramedia-data:/data

  siglip2-embed:
    image: tinyping/siglip2-embed-service:cpu
    container_name: siglip2-embed
    restart: unless-stopped
    environment:
      EMBEDDING_BACKEND: "cpu"
      CPU_CONCURRENCY: "1"
    # 模型和运行时已包含在镜像内；不需要下载模型、挂载模型目录或暴露端口。

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
```

::: tip 数据库
后端默认按 `postgres` 服务名连接内置 PostgreSQL，照抄示例即可运行。若使用外部 PostgreSQL，再按[配置说明](/guide/config#database)修改 `[database].url`。
:::

### 3. 启动

```bash
cd /mnt/ssd/sakuramedia
docker compose up -d
```

### 4. 访问

默认用户名和密码是 `account` 和 `account`，登录后建议立即修改密码。桌面端和移动端首次登录时填写后端地址，例如：

```text
http://你的IP:38000
```

### 5. 首次登录后的初始化

#### 1. 安装并启用插件

进入「系统设置 → 插件」，安装并启用需要的 media provider、download provider、索引器或排行榜插件。插件安装后按提示重启 `api` 和 `aps` 服务。

#### 2. 创建媒体库

进入「系统设置 → 媒体库 → 新增」，选择 media provider，填写 provider 动态提供的配置字段并保存。媒体库的存储、浏览和播放能力由该 provider 提供。

#### 3. 添加下载器

进入「系统设置 → 下载器 → 新增」，选择下载 provider，填写动态配置字段并绑定目标媒体库。下载完成后，provider 返回的 `completed_source_ref` 会被自动导入流程使用。

下载任务的连接信息和存储参数由下载 provider 的动态配置字段提供。

#### 4. 配置索引器并绑定下载器

进入「系统设置 → 索引器 → 新增」，填写索引器地址和鉴权信息，然后绑定一个或多个下载器。多个下载器时按绑定顺序选择。

#### 5. 用组件诊断验证

在「概览」页运行「组件诊断」，检查媒体库、索引器、JavDB 和 SigLIP2 嵌入服务的连通性。

#### 6. 在线搜索影片或女优

数据库为空时，在搜索页开启「联网」后再搜索。在线结果写入本地后，下次搜索通常可以直接使用本地数据。

更多字段说明见[配置说明](/guide/config)，任务频率见[后台任务](/guide/tasks)。
