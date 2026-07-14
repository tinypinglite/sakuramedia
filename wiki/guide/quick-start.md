---
outline: [2, 4]
---

# 快速开始

这是一份"先把服务跑起来"的快速指引，覆盖 SakuraMedia 完整能力，包括「订阅 → 自动找种 → 自动下载 → 自动导入」的全自动收藏链路。这条主线需要你已经部署好 qBittorrent 和 Jackett 服务。这里会尽量把第一次部署需要的主线写完整，但不会展开所有高级配置和所有运行命令。

::: tip 只想用它管已有影片、不想配 qB + Jackett？
SakuraMedia 的下载链路是**可选能力**，不启用也能作为 NAS 上的 JAV 影片管理 / 播放工作台使用（元数据、订阅追新、播放、切片、以图搜图、翻译都保留，只失去"自动下载"）。这条路径的部署步骤更简单、compose 更精简、硬件门槛更低，详见 [轻量部署（不用自动下载）](/guide/lightweight-deploy)。
:::

## 准备工作

### 使用前提

SakuraMedia 更适合已经有 NAS、已经在管理本地媒体文件，并且希望把找Jav影片、下载、整理和观影尽量收敛到同一个工作台里的用户。

它不是资源站，也不是开箱即用的公共在线平台。你需要自己准备种子/磁力资源站、QB 下载器、Jackett、NAS 存储空间，SakuraMedia 负责把这些能力串起来。

::: tip 索引器请自行准备
SakuraMedia 的自动下载效果取决于你在 Jackett 里接入了哪些种子/磁力索引器。请根据你自己的资源情况，在 Jackett 中配置合适的索引器。SakuraMedia 不对具体站点做推荐。
:::

### 你需要准备什么

这里把前提分成「必备」和「可选」两类：**必备**项缺了就无法完成基础部署；**可选**项只在你需要对应功能时才用得到，可以等用到时再补。

#### 必备

- 一台基于 Linux 的 NAS（目前仅在飞牛 OS 上测试过，理论上其他 Linux 发行版也支持，但未测试；ARM 架构现已支持但尚未经过测试，可自行尝试；Windows 系统同样未经测试，暂不保证兼容性）
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

最小可用部署里，一般会有这 5 个服务：

- `sakuramedia`：后端服务，负责账号、媒体库、下载链路、任务调度等核心能力
- `postgres`：PostgreSQL 数据库，存储所有业务数据；照抄 compose 即可，无需任何数据库配置
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
mkdir -p sakuramedia-data/{cache,logs,config,joytag,media-clips,image-search-index,postgres} sakuramedia-data/cache/{assets,subtitles,gfriends}
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

好在挂没挂对是可以验证的：完成下面的首次初始化后，[用组件诊断验证配置](#_4-用组件诊断验证配置)——它会实际测一次「下载目录 → 媒体库」的目录映射和硬链接，跨盘、没整体挂载都会直接暴露出来。
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
  postgres:
    # 服务名必须保持 postgres，后端默认按这个主机名连接数据库，照抄即可零配置
    image: postgres:16-alpine
    container_name: sakuramedia-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: sakuramedia
      POSTGRES_USER: sakuramedia
      POSTGRES_PASSWORD: sakuramedia
    volumes:
      # 数据库数据目录，务必放 SSD
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
      - "38000:8000" # API服务端口
    environment:
      # 如果你知道 PUID/PGID 的含义，可用 `id -u` 和 `id -g` 查询
      # 如果你不懂，就保持默认 0/0（root）
      PUID: 0
      PGID: 0
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

::: tip 数据库无需任何配置
后端默认就按 `postgres` 这个服务名连接内置的 PostgreSQL，账号密码也和上面 compose 里的默认值对齐，**照抄就能跑，不用改任何数据库配置**。

`postgres` 服务没有对宿主机映射端口，只在 compose 内部网络可见，外部无法直接访问。只有当你想用自己已有的 PostgreSQL 时，才需要去 `config.toml` 里改 `[database].url`（见[配置说明](/guide/config#database)）。
:::

### 4. 启动
运行 `docker compose up -d` 启动服务。

```bash
docker compose up -d
```

### 5. 访问

默认用户名和密码是`account` 和 `account`，登录后建议第一时间修改密码。

#### 浏览器（Web 端）

直接访问 `http://你的IP:38080`。

#### 桌面端 / 移动端 APP

桌面端和移动端 APP 在首次登录界面需要填写「服务器地址」，这里要填的是**后端 API 服务地址**，也就是 `compose.yaml` 里 `sakuramedia` 容器对外暴露的端口（默认 `38000`）：

```text
http://你的IP:38000
```

::: warning 不要把 38080 当成 APP 的服务器地址
`38080` 是 `sakuramedia-web` 容器对外暴露的端口，**只给浏览器访问 Web 客户端用**，APP 直接连它会登录失败。

APP 必须连后端 API 端口 `38000`（即 `sakuramedia` 容器的 `38000:8000` 那一行映射出来的宿主机端口）。如果你在 `compose.yaml` 里改过这个端口映射，填你改成的那个端口即可。
:::



### 6. 首次登录后的最小初始化

服务启动后，建议按这个顺序完成最小初始化。


#### 1. 创建媒体库

登录后先进入配置页面，创建一个新的媒体库，假设你挂载到容器里的媒体目录是`/mnt/volume1/media`


```bash
/mnt/volume1/media/sakuramedia
```

也就是相当于新建了一个`sakuramedia`的子目录，用于保存导入或者是自动下载的影片资源。




#### 2. 添加 qBittorrent 下载器

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
如果你打算按类别隔离下载任务（例如把不同类型的索引器接到不同下载器上），可以部署多个 qBittorrent 实例，并在 SakuraMedia 里各建一个下载器。
:::


#### 3. 配置索引器 - Jackett

1. 填写Jackett API Key
2. 新建索引器
  - 名称：随意
  - 类别：建议如实填写，方便手动搜索资源时，展示资源所属类别
  - 绑定下载器: 决定此站点的种子会交由哪个下载器来处理.

这一步完成后，SakuraMedia 才能走完整的”搜索候选资源 -> 提交下载 -> 导入媒体库”链路。

#### 4. 用组件诊断验证配置

前面几步配没配对，不用挨个手动试：回到「总览」页，顶部有一条「组件诊断」横条（桌面端和 Web 端都有），点「开始检测」会一键检测媒体库、下载器、索引器、JavDB / DMM、LLM 与 JoyTag 的连通性。

和前面几步直接对应的检查有：

- **下载器的存储检测**会实际验证「本地访问路径」的目录映射和硬链接——[媒体目录挂载](#媒体目录怎么挂才能正确硬链接)如果跨了盘或没整体挂载，这里会直接暴露，不用等第一次下载完成才发现悄悄回退成了复制。
- **索引器检测**会校验 Jackett 配置完整性（API Key、索引器条目、下载器绑定），并实测一次 Jackett 连通。
- 检测不通过的项会给出「可能原因 / 怎么改 / 影响」的说明，并能直接跳到配置页对应位置去改。

还没配置的可选能力（比如 LLM 翻译未启用）只会标成黄色提醒，不影响其它项，可以先忽略，配好之后再测一次。

#### 5. 在线搜索影片或女优

服务刚启动时，数据库通常还是空的。这时候如果你直接搜索一部影片或一个女优，可能会看到“本地库中没有匹配内容”。

这是正常的，因为 SakuraMedia 默认是先从本地数据库里搜索，如果本地数据库里没有，你可以在搜索页里手动开启右侧的 `网络` 图标，这将从`javdb`中进行搜索.

示例界面如下：

![联网搜索示例](./images/online-search-network-toggle.png)

联网搜索的作用是：

- 当本地库里没有这部影片或这个女优时，主动去在线源查询
- 查询成功后，把对应的影片或女优元数据自动写入本地库
- 下次再搜索同一部影片或同一个女优时，通常就不需要再手动开启 `联网`


## 强烈建议使用客户端，而不是 Web 端

服务跑起来之后，日常使用**强烈建议下载对应平台的客户端**，不要长期用浏览器 Web 端。

::: warning Web 端仅作为兜底，未经完善测试
`sakuramedia-web` 目前只保证「能用」，很多细节交互、播放性能、图片加载、快捷键、下载/导入反馈等都**没有和客户端做等价测试**
:::

前往 GitHub Releases 下载对应平台的安装包：

👉 [https://github.com/tinypinglite/sakuramedia/releases](https://github.com/tinypinglite/sakuramedia/releases)

支持的平台：

- **Windows**：下载 zip 包，解压后直接运行 `.exe`
- **macOS**：下载 zip 包，解压后拖动到应用程序后打开，若打开时提示「已损坏 / 无法打开」，是未签名导致的系统拦截，可在「系统设置 → 隐私与安全性」放行
- **Android**：下载 `.apk`，允许「安装未知来源应用」后直接安装
- **iOS**：Releases 提供 `.ipa`，需要通过 [AltStore（AltServer）](https://altstore.io/) 或 [SideStore](https://sidestore.io/) 自签安装（Apple 的免费开发者证书 7 天需要重签一次，AltStore/SideStore 会自动处理）

::: tip 客户端的服务器地址仍然填后端 API 端口
无论在哪个平台，客户端首次登录时填的**服务器地址**都是后端 `sakuramedia` 容器对外暴露的端口（默认 `http://你的IP:38000`），**不是 Web 端的 `38080`**。详见上面 [5. 访问 → 桌面端 / 移动端 APP](#桌面端-移动端-app)。
:::
