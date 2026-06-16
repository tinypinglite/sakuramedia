---
outline: [2, 4]
---

# 快速开始

这是一份“先把服务跑起来”的快速指引，需要你已经部署好 qBittorrent 和 Jackett 服务。这里会尽量把第一次部署需要的主线写完整，但不会展开所有高级配置和所有运行命令。

## 准备工作

### 使用前提

SakuraMedia 更适合已经有 NAS、已经在管理本地媒体文件，并且希望把找Jav影片、下载、整理和观影尽量收敛到同一个工作台里的用户。

它不是资源站，也不是开箱即用的公共在线平台。你需要自己准备PT站或者BT资源站、QB下载器、Jackett、NAS存储空间，SakuraMedia 负责把这些能力串起来。

::: tip 强烈建议优先使用 PT 站
SakuraMedia 的核心是「订阅影片 / 女优 → 自动找种 → 自动下载 → 自动导入」的全链路自动化收藏。这条链路的效果几乎完全取决于你给 Jackett 接了什么索引器：**只用公开 BT / 磁力源时，自动下载的命中率、做种健康度和速度都会很差**，很多番号要么搜不到、要么做种者太少被过滤掉。

如果你认真打算用这套自动化收藏，**强烈建议接入 PT 站(如M-Team)作为主力索引器**，BT / 磁力源只作补充兜底。详细原因见[收藏思路 → 强烈建议接 PT 站](/guide/collection-strategy#强烈建议接-pt-站-而不是只用-bt)。
:::

### 你需要准备什么

这里把前提分成「必备」和「可选」两类：**必备**项缺了就无法完成基础部署；**可选**项只在你需要对应功能时才用得到，可以等用到时再补。

#### 必备

- 一台基于 Linux 的 NAS（目前仅在 X86 的飞牛 OS 上测试过，理论上其他 X86 Linux 发行版也支持，但未测试；Windows 系统同样未经测试，暂不保证兼容性）
- 已安装 `Docker` 和 `Docker Compose`
- 一个媒体目录：可以是已有影片目录，也可以是准备交给 SakuraMedia 管理的新目录

#### 可选（按需准备）

- **自动下载链路**（自动找种 → 自动下载 → 自动导入）
  * 需要同一个 NAS 上部署的、可正常使用的 `qBittorrent` 和 `Jackett` 服务，
  * 一个能同时被 SakuraMedia 服务 和 `qBittorrent` 服务访问的下载目录

- **简介与翻译**（影片简介抓取、标题翻译）
  * 需要部署机器能直接或通过代理访问 DMM，以及一个兼容 OpenAI 的大模型 API

::: tip *用自动下载就得让两个容器/服务能够看到同一个下载目录*
如果你要用自动下载链路，`qBittorrent` 的下载目录和你的媒体目录，最终都要挂载进 SakuraMedia 容器，否则下载完成后无法自动导入。具体怎么挂在下面的「创建工作目录」里展开。
:::

### 硬件建议

如果你只是先跑通服务，建议按下面的思路准备：

- 至少 `4核8G`， 运行Joytag推理模型还有图片的向量数据索引，内存占用会比较多，在索引影片缩略图时也会占用CPU/GPU资源.
- 需要一个固态硬盘目录来放运行数据（数据库、配置文件、日志、影片元数据、图片索引数据等）.
- 媒体文件建议放在机械盘.


### 部署后会有哪些服务

最小可用部署里，一般会有这 4 个服务：

- `sakuramedia`：后端服务，负责账号、媒体库、下载链路、任务调度等核心能力
- `sakuramedia-web`：Web 客户端，用浏览器访问和管理 SakuraMedia
- `joytag-infer`：以图搜图推理服务，负责图片向量化能力
- `qdrant`：图片搜索向量数据库，存储缩略图向量并提供检索


::: tip 桌面端APP和移动端APP可以从github releases下载 [releases](https://github.com/tinypinglite/sakuramedia/releases)
:::



## 快速部署后端服务

### 1. 创建数据目录
准备一个目录，用于存放运行时数据和compose.yaml，假设是`/mnt/ssd/sakuramedia`:
创建一个存放容器运行时数据的目录，包括了数据库、配置文件、日志、缓存、图片索引数据等。这个目录建议放在固态硬盘上，以保证服务的响应速度和稳定性。


```bash
cd /mnt/ssd/sakuramedia
mkdir -p sakuramedia-data/{db,cache,logs,config,joytag,media-clips,image-search-index} sakuramedia-data/cache/{assets,subtitles,gfriends}
```

### 2. 准备joytag 推理模型
推理模型下载到`sakuramedia-data/joytag/model_vit_768.onnx`, 你可以不用wget，也可以用其他方式下载，放到`sakuramedia-data/joytag/model_vit_768.onnx`就可以了。
```bash
cd sakuramedia-data/joytag
wget -O model_vit_768.onnx https://github.com/tinypinglite/sakuramediabe/releases/download/model/model_vit_768.onnx
```


### 3. 准备 `compose.yaml`

#### 媒体目录怎么挂才能正确硬链接

> 这一步是整个部署里最容易踩坑、又最难当场发现问题的地方，建议挂之前先读一遍。

导入已有媒体、以及下载完成后的自动导入，默认都用「**硬链接**」把文件落进媒体库：同一份文件同时出现在原目录和媒体库里，**不额外占空间、瞬间完成**，下载的种子也能继续做种。

但硬链接能成功，有两个硬性前提：

1. **源和目标在同一块盘上**
   已有影片目录、qBittorrent 下载目录、媒体库目录，必须都在**同一块物理盘 / 同一个文件系统**上。跨盘是没法硬链接的。

2. **在容器里整体挂成一个目录**
   在 `compose.yaml` 里，要把上面这几类目录的**共同父目录作为一个整体挂进容器（一个 volume）**，不要把下载目录和媒体目录拆成两个独立挂载。另外**容器内路径必须以 `/mnt` 开头**（导入界面的目录浏览只从 `/mnt` 往下看，挂到别处就选不到）。

::: warning 挂错不会报错，但会悄悄变慢、变占空间
如果跨了盘、或目录布局不对，系统**不会报错**，而是悄悄回退成「复制」——结果就是占用双倍空间、导入更慢，做种资源也失去「边做种边入库、零额外占用」的好处。正因为它不当场报错，所以这一步要一开始就挂对。
:::

**推荐目录布局**（单盘）：把媒体根目录 `/mnt/volume1/media` 整体挂进容器，下面再分三个子目录：

```text
/mnt/volume1/media        ← 整体挂进容器的就是这一个目录
├── av                    ← 已有影片目录
├── downloads             ← qBittorrent 下载目录
└── sakuramedia           ← 新建的媒体库目录
```

对应的 volume 写法（建议宿主机路径和容器路径写成一样，省得后面创建媒体库、填下载器路径时再做一次脑内换算）：

```yaml
    volumes:
      - ./sakuramedia-data:/data
      # 媒体根目录整体挂一个 volume；容器内路径以 /mnt 开头
      - /mnt/volume1/media:/mnt/volume1/media
```

挂对之后，两个场景就都能走硬链接：

- **导入已有媒体**：`av` 和 `sakuramedia` 在同一块盘、同一个挂载根下 → 导入瞬间完成、不额外占空间。
- **下载完成自动导入**：`downloads` 和 `sakuramedia` 在同一块盘、同一个挂载根下；再配合后面「添加 qBittorrent 下载器」一步把保存路径和本地访问路径对上（指向同一批真实文件），下载完就能自动硬链接进媒体库。

> 多块媒体盘怎么规划（每块盘一套媒体库 + 一套下载器），见[进阶部署 → 推荐部署思路](/guide/docker#推荐部署思路)。

#### 最小可用示例

在`/mnt/ssd/sakuramedia`里创建 `compose.yaml`

```bash
cd /mnt/ssd/sakuramedia
touch compose.yaml
```

填入以下内容:

```yaml
services:
  sakuramedia:
    image: tinyping/sakuramediabe:latest
    container_name: sakuramedia
    restart: unless-stopped
    ports:
      - "38000:8000" # API服务端口
    environment:
      PUID: "${PUID:-1000}"
      PGID: "${PGID:-1000}"
      TZ: "Asia/Shanghai"
    volumes:
      # SakuraMedia 的运行数据都在 /data 下，整体挂一个目录即可
      - ./sakuramedia-data:/data
      # 挂载媒体目录，要挂载 已有影片目录和 qbittorrent下载目录 的共同父目录
      # 另外挂载到容器中的路径必须以 /mnt 开头，否则会影响导入已有媒体功能
      - 你宿主机的路径:/mnt/volume1/media

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
      # 图片搜索向量库存储；务必放 SSD
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

### 4. 启动
运行 `docker compose up -d` 启动服务。

```bash
docker compose up -d
```

### 5. 访问
访问 `http://你的IP:38080` 默认用户名和密码是`account` 和 `account`，登录后建议第一时间修改密码。



### 6. 首次登录后的最小初始化

服务启动后，建议按这个顺序完成最小初始化。


#### 1. 创建媒体库

登录后先进入配置页面，创建一个新的媒体库，假设你挂载到容器里的媒体目录是`/mnt/volume1/media`


```bash
/mnt/volume1/media/sakuramedia
```

也就是相当于新建了一个`sakuramedia`的子目录，用于保存导入或者是自动下载的影片资源。




#### 3. 添加 qBittorrent 下载器

假设你qBittorrent的下载目录是挂载到容器中的`/mnt/volume1/media/downloads`，在qBittorent容器这个目录是 `/downloads`，那么在添加下载器的时候：
* qBittorrent保存路径填写：`/downloads`
* 本地访问路径填写：`/mnt/volume1/media/downloads`

这里一定要注意：

- qBittorrent保存路径 填的是 `qBittorrent` 容器里实际看到的下载路径
- 本地访问路径 填的是 `SakuraMedia` 容器里的实际看到的下载路径
- 这两个路径在宿主机上，实际指向的是同一个目录

如果这里填错了，后续下载任务虽然可能能提交成功，但 SakuraMedia 没法正确识别和导入下载结果。

目标媒体库直接选择你刚刚创建的那个媒体库即可。

::: tip
如果你打算PT和BT都用的话，建议部署两个qBittorrent，一个用来下载PT资源，一个用来下载BT资源. 并把两个下载器都添加上.
:::


#### 4. 配置索引器 - Jackett

1. 填写Jackett API Key
2. 新建索引器
  - 名称：随意
  - 类别：建议如实填写，方便手动搜索资源时，展示资源所属类别
  - 绑定下载器: 决定此站点的种子会交由哪个下载器来处理.

这一步完成后，SakuraMedia 才能走完整的”搜索候选资源 -> 提交下载 -> 导入媒体库”链路。

#### 5. 在线搜索影片或女优

服务刚启动时，数据库通常还是空的。这时候如果你直接搜索一部影片或一个女优，可能会看到“本地库中没有匹配内容”。

这是正常的，因为 SakuraMedia 默认是先从本地数据库里搜索，如果本地数据库里没有，你可以在搜索页里手动开启右侧的 `网络` 图标，这将从`javdb`中进行搜索.

示例界面如下：

![联网搜索示例](./images/online-search-network-toggle.png)

联网搜索的作用是：

- 当本地库里没有这部影片或这个女优时，主动去在线源查询
- 查询成功后，把对应的影片或女优元数据自动写入本地库
- 下次再搜索同一部影片或同一个女优时，通常就不需要再手动开启 `联网`

