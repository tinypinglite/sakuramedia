---
outline: [2, 4]
---

# 快速开始

这是一份“先把服务跑起来”的快速指引，适合已经在 NAS 上使用过 Docker、qBittorrent、Jackett 的用户。这里会尽量把第一次部署需要的主线写完整，但不会展开所有高级配置和所有运行命令。

## 准备工作

### 使用前提

SakuraMedia 更适合已经有 NAS、已经在管理本地媒体文件，并且希望把找片、下载、整理和观影尽量收敛到同一个工作台里的用户。

它不是资源站，也不是开箱即用的公共在线平台。你需要自己准备PT站或者BT资源站、QB下载器、Jackett、NAS存储空间，SakuraMedia 负责把这些能力串起来。

### 你需要准备什么

开始之前，建议先确认这些前提已经具备：

- 一台基于 Linux 的 NAS
- 已安装 `Docker` 和 `Docker Compose`
- 一个可正常使用的 `qBittorrent`
- 一个可正常使用的 `Jackett`
- 一个已有媒体目录，或者一个准备交给 SakuraMedia 管理的新媒体目录
- 一个可被 SakuraMedia 容器访问的下载目录，同时需要能被 `qBittorrent` 容器访问
- 如果需要影片简介和标题翻译，还需要所部署的机器能够直接或通过代理访问dmm，以及兼容OpenAI的大模型API接口。

其中有一点要特别提前想清楚：`qBittorrent` 的下载目录和你计划使用的媒体目录，最终都需要挂载到 SakuraMedia 容器内。否则后续无法完成自动导入，也无法顺利接上订阅下载链路。

### 硬件建议

如果你只是先跑通服务，建议按下面的思路准备：

- 至少 `4C8G`
- 运行数据尽量放在 SSD
- 媒体文件尽量放在容量盘或机械盘
- 以图搜图默认使用 `joytag-infer:cpu`

如果你的 NAS 是 Intel 平台，后续可以再考虑 `openvino` 方案；但在“快速开始”阶段，更推荐先用 CPU 版把主线跑通。

### 部署后会有哪些服务

最小可用部署里，一般会有这 3 个服务：

- `sakuramedia`：后端服务，负责账号、媒体库、下载链路、任务调度等核心能力
- `sakuramedia-web`：Web 客户端，用浏览器访问和管理 SakuraMedia
- `joytag-infer`：以图搜图推理服务，负责图片向量化能力

你可以把它理解成：`sakuramedia` 负责业务，`sakuramedia-web` 负责界面，`joytag-infer` 负责图片搜索。

## 快速部署服务端

### 1. 创建工作目录

这一步建议先把“运行数据放哪里”和“媒体文件怎么挂载”一次想清楚，后面会省很多事。

#### 目录应该怎么分

推荐把目录分成两类：

- 运行数据目录：放数据库、配置、日志、缓存和图片索引，尽量放在 SSD 上
- 媒体目录：放已有影片和下载中的文件，尽量放在容量盘上

#### 推荐路径

一个比较实用的目录规划方式是：

- SSD 路径：`/mnt/ssd/sakuramedia`
- 媒体盘路径：`/mnt/volume1/media`

其中：

- `/mnt/ssd/sakuramedia` 用来存放 SakuraMedia 自己的运行数据
- `/mnt/volume1/media` 作为统一挂载根目录，里面同时包含已有影片和 `qBittorrent` 下载目录

#### 推荐目录结构

这样做的好处是后面写 `compose.yaml` 时更简单，也更不容易把路径挂错。尤其是自动下载和导入场景，SakuraMedia 必须同时能看到：

- 你已经有的影片目录
- `qBittorrent` 的下载目录

如果这两个目录不在容器可访问的挂载范围内，后续就算下载成功，也没法自动导入。

一个推荐的媒体目录结构可以是这样：

```text
/mnt/volume1/media
├── av
├── downloads
└── sakuramedia
```

这里可以这样理解：

- `av`：你已有的影片目录，用于后续导入历史媒体
- `downloads`：`qBittorrent` 的实际下载目录
- `sakuramedia`：给 SakuraMedia 新建的媒体库目录，后续自动导入的影片可以优先放这里

#### qBittorrent 下载目录怎么挂

这里建议你在 `qBittorrent` 容器里，把宿主机目录：

```bash
/mnt/volume1/media/downloads
```

映射成容器内的：

```bash
/downloads
```

后面在 SakuraMedia 里添加 `qBittorrent` 下载器时，`client_save_path` 就直接填写这个容器内路径 `/downloads`。

这样做的目的，是同时满足两件事：

- SakuraMedia 知道`qBittorrent` 容器内部的下载保存路径是什么
- SakuraMedia 知道这个下载路径在自己容器里对应到哪里

只有这两个路径关系是明确的，SakuraMedia 才能在下载完成后正确识别并导入媒体文件。

#### 直接创建目录

如果你准备按这套方式来，可以先直接执行：

```bash
mkdir -p /mnt/ssd/sakuramedia
cd /mnt/ssd/sakuramedia
mkdir -p docker-data/config
mkdir -p docker-data/db
mkdir -p docker-data/cache/assets
mkdir -p docker-data/cache/subtitles
mkdir -p docker-data/image-search-index
mkdir -p docker-data/logs
mkdir -p docker-data/joytag

mkdir -p /mnt/volume1/media/av
mkdir -p /mnt/volume1/media/downloads
mkdir -p /mnt/volume1/media/sakuramedia
```

执行完以后，你可以把当前目录理解成后续的部署根目录：

```bash
/mnt/ssd/sakuramedia
```

后面的 `config.toml`、`compose.yaml` 和绝大多数部署命令，都默认在这个目录下执行。

#### 这一步完成后的状态

最后再确认一遍这一步的目标：

- SakuraMedia 的运行数据目录已经准备好
- 媒体目录和下载目录已经规划好
- `/mnt/volume1/media/downloads` 已经准备挂载到 `qBittorrent` 容器内，建议映射为 `/downloads`
- `qBittorrent` 下载目录后续会被一起挂载进 SakuraMedia 容器

只要这一步规划对了，后面的配置基本就是顺着往下填。

### 2. 准备 `config.toml`

在工作目录里创建 `docker-data/config/config.toml`。

#### 数据库怎么选

当前支持的数据库类型有：

- `sqlite`
- `mysql`
- `postgres`

如果你只是临时试跑，`sqlite` 可以先用；但只要你准备长期使用，推荐直接使用 PostgreSQL，不建议把 `sqlite` 当成正式长期方案。

更实用的选择建议是：

- 只想快速验证服务能不能跑起来：`sqlite`
- 准备长期使用，或者希望后面少折腾一次：`postgres`
- 已经有稳定运行的 MySQL 环境：`mysql`

#### 推荐的最小示例

第一次部署时，先用下面这份最小可用配置就够了。这里默认按“长期使用”思路，直接给 PostgreSQL 示例：

```toml
[database]
# 支持 sqlite / mysql / postgres
# 推荐长期使用 PostgreSQL
engine = "postgres"
path = "/data/db/sakuramedia.db"
charset = "utf8mb4"
url = "postgresql://sakuramedia:change-me@postgres:5432/sakuramedia"

[auth]
# 建议之后用 app 修改这个配置项，修改后会覆盖掉 config.toml 中的配置
# 默认登录用户名。
username = "account"
# 默认登录密码。
password = "account"

# JWT 签名密钥，必须改成你自己的随机字符串！！！建议长度不少于32个字符，否则可能存在安全风险。
secret_key = "replace-with-a-random-secret-key"

[metadata]
# 下载 GFriends 使用的代理地址，用于处理女优头像。
# 仅支持 http 代理：例如 http://192.168.1.1:7890
# 不需要代理时留空即可
proxy = ""

[image_search]
# JoyTag 独立推理服务地址。
inference_base_url = "http://joytag-infer:8001"
```

#### 其他数据库示例

如果你暂时不用 PostgreSQL，也可以参考下面这些写法。

SQLite 示例：

```toml
[database]
engine = "sqlite"
path = "/data/db/sakuramedia.db"
charset = "utf8mb4"
url = ""
```

MySQL 示例：

```toml
[database]
engine = "mysql"
path = "/data/db/sakuramedia.db"
charset = "utf8mb4"
url = "mysql://sakuramedia:change-me@mysql:3306/sakuramedia"
```

PostgreSQL 示例：

```toml
[database]
engine = "postgres"
path = "/data/db/sakuramedia.db"
charset = "utf8mb4"
url = "postgresql://sakuramedia:change-me@postgres:5432/sakuramedia"
```

#### 这几个配置最重要

这一版配置只保留快速开始必须用到的字段，重点注意这几点：

- `database.engine` 和 `database.url` 要和你实际使用的数据库一致
- `username` 和 `password` 是第一次登录 Web 时使用的账号密码
- `secret_key` 一定要改，不能直接保留示例值
- `inference_base_url` 默认写成 `http://joytag-infer:8001`，前提是你后面的 `compose.yaml` 里服务名也叫 `joytag-infer`

如果你只是先把系统跑起来，这份配置已经足够用了。它只覆盖第一次启动最需要的部分；如果你想了解更多配置项，可以直接看[配置说明](/guide/config)。

### 3. 准备 `compose.yaml`

#### 最小可用示例

在工作目录里创建 `compose.yaml`。如果你前面就是按本文的目录规划做的，可以先直接用下面这份最小可用示例：

```yaml
services:
  sakuramedia:
    image: tinyping/sakuramediabe:latest
    container_name: sakuramedia
    restart: unless-stopped
    ports:
      - "38000:8000"
    environment:
      PUID: "${PUID:-1000}"
      PGID: "${PGID:-1000}"
      TZ: "Asia/Shanghai"
    volumes:
      - ./docker-data/config:/data/config
      - ./docker-data/db:/data/db
      - ./docker-data/cache/assets:/data/cache/assets
      - ./docker-data/cache/subtitles:/data/cache/subtitles
      - ./docker-data/image-search-index:/data/indexes
      - ./docker-data/logs:/data/logs
      - /mnt/volume1/media:/mnt/volume1/media

  joytag-infer:
    image: tinyping/joytag-infer:cpu
    container_name: joytag-infer
    restart: unless-stopped
    environment:
      JOYTAG_INFER_BACKEND: "cpu"
      JOYTAG_INFER_MODEL_PATH: "/data/lib/joytag/model_vit_768.onnx"
      JOYTAG_INFER_API_KEY: ""
    volumes:
      - ./docker-data/joytag:/data/lib/joytag
    ports:
      - 8001:8001

  sakuramedia-web:
    image: tinyping/sakuramedia-web:latest
    container_name: sakuramedia-web
    restart: unless-stopped
    depends_on:
      - sakuramedia
    ports:
      - "38080:80"
```

#### 文件放在哪里

如果你当前就在部署根目录 `/mnt/ssd/sakuramedia` 下，可以直接这样创建文件：

```bash
cd /mnt/ssd/sakuramedia
```

然后把上面的内容保存成：

```bash
compose.yaml
```

#### 这份示例里最重要的点

这份示例里有几个关键点需要理解：

- `sakuramedia` 是后端服务，负责账号、媒体库、下载链路和任务调度
- `joytag-infer` 是以图搜图服务，这里默认用 `cpu` 版本
- `sakuramedia-web` 是浏览器访问用的 Web 前端
- `38000` 是后端端口，`38080` 是 Web 端口
- `/mnt/volume1/media:/mnt/volume1/media` 这一行非常重要，它决定了容器能看到你的已有媒体和下载目录

这里特别建议宿主机路径和容器内路径保持一致，也就是都用：

```bash
/mnt/volume1/media
```

这样后面创建媒体库、导入历史影片、处理下载目录时，路径最不容易搞混。

如果你的实际媒体盘路径不是 `/mnt/volume1/media`，那你只需要改这一行，把左右两边一起改掉即可。第一次部署阶段，`joytag-infer` 先保持 `cpu` 就行，不建议再额外改成别的后端。

### 4. 放置 JoyTag 模型

以图搜图默认依赖 JoyTag 模型文件。先去这里下载模型文件：

[JoyTag 模型下载页](https://github.com/tinypinglite/sakuramediabe/releases/tag/model)

下载完成后，把模型文件放到当前部署目录下的这个位置：

```bash
./docker-data/joytag/model_vit_768.onnx
```

如果你当前就在部署根目录 `/mnt/ssd/sakuramedia` 下，可以这样操作：

```bash
cd /mnt/ssd/sakuramedia
mkdir -p ./docker-data/joytag
```

然后把你下载到本地的 `model_vit_768.onnx` 移动或复制到这个目录里，最终文件路径应该是：

```bash
/mnt/ssd/sakuramedia/docker-data/joytag/model_vit_768.onnx
```

放好以后，建议立刻检查一下文件是否已经在正确位置：

```bash
ls -lh /mnt/ssd/sakuramedia/docker-data/joytag/model_vit_768.onnx
```

只要这条命令能正常看到文件，后面的 `joytag-infer` 容器就能按这一路径读取模型。

### 5. 启动服务

准备好配置文件和模型后，就可以启动服务：

```bash
docker compose up -d
```

启动后，先做两件事：

- 访问 Web 地址，确认登录页能正常打开
- 如果容器没有正常启动，先查看容器状态和日志

常用检查命令可以在后面的常用命令文档里查看。

### 6. 首次登录后的最小初始化

服务启动后，建议按这个顺序完成最小初始化。

#### 1. 登录 Web

先打开 Web 地址：

```bash
http://<你的NAS地址>:38080
```

然后用 `config.toml` 里设置的账号密码登录。

#### 2. 创建媒体库

登录后先进入配置页面，创建一个新的媒体库。

如果你前面是按本文档的推荐目录做的，这里的媒体库根路径可以填写：

```bash
/mnt/volume1/media/sakuramedia
```

后续导入或者是自动下载的影片都会保存到这个目录下。


#### 3. 添加 qBittorrent 下载器

如果你前面已经按本文建议，把宿主机目录：

```bash
/mnt/volume1/media/downloads
```

挂载到了 `qBittorrent` 容器内的：

```bash
/downloads
```

那么这里就建议固定这样填：

- `client_save_path = /downloads`
- `local_root_path = /mnt/volume1/media/downloads`

这里一定要注意：

- `client_save_path` 填的是 `qBittorrent` 容器里的下载路径，这里就是你前面挂载进去的 `/downloads`
- `local_root_path` 填的是 `SakuraMedia` 容器里的路径
- 这两个路径在宿主机上，必须实际指向同一个目录

换句话说：

- `qBittorrent` 看到的是 `/downloads`
- SakuraMedia 看到的是 `/mnt/volume1/media/downloads`
- 它们在宿主机上其实都是同一个目录：`/mnt/volume1/media/downloads`

如果这里填错了，后续下载任务虽然可能能提交成功，但 SakuraMedia 没法正确识别和导入下载结果。

目标媒体库直接选择你刚刚创建的那个媒体库即可。

#### 4. 配置 Jackett

继续在 `Indexer Settings` 里配置 Jackett，并把 indexer 绑定到刚刚创建的下载器。

这一步完成后，SakuraMedia 才能走完整的“搜索候选资源 -> 提交下载 -> 导入媒体库”链路。

#### 5. 在线搜索影片或女优

服务刚启动时，数据库通常还是空的。这时候如果你直接搜索一部影片或一个女优，可能会看到“本地库中没有匹配内容”。

这不是异常，说明当前这条数据还没有进入本地库。你可以在搜索页里手动开启右侧的 `联网` 图标，再执行一次搜索。

示例界面如下：

![联网搜索示例](./images/online-search-network-toggle.png)

联网搜索的作用是：

- 当本地库里没有这部影片或这个女优时，主动去在线源查询
- 查询成功后，把对应的影片或女优元数据自动写入本地库
- 下次再搜索同一部影片或同一个女优时，通常就不需要再手动开启 `联网`

建议第一次使用时，可以先试着搜索一部影片番号，或者直接搜索一个女优名字，确认这条“在线搜索 -> 自动入库 -> 本地下次可直接命中”的链路已经打通。
