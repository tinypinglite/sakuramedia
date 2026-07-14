---
outline: [2, 4]
---

# 飞牛 NAS 部署

这一页手把手带你在**飞牛 OS** 上通过桌面的 Docker Compose UI 部署 SakuraMedia，不用敲一行命令。

::: tip 这一页适合谁
- 你用的是**飞牛 OS**（fnOS）并已开启内置 Docker
- 你想通过飞牛的图形界面完成部署，不想 ssh 上去手写 compose
- 你已经或即将自行部署 **`jackett`** 和 **`qBittorrent`**（本教程**不含**这两个的部署步骤，请自备）
:::

::: warning 关于示例路径
本页所有涉及 `/vol1/1000/...` 的路径都是**举例**。飞牛把硬盘挂在 `/vol1`、`/vol2` 等编号下，你的编号可能不同，只要**替换成你实际看到的路径**即可，其它保持一致。
:::

## 准备工作

### 前置依赖

- 已在飞牛上部署好 `qBittorrent`，能记住它的 Web 端口和账号
- 已在飞牛上部署好 `jackett`，能拿到它的 API Key 和 torznab 地址
- 一块**固态硬盘**上的空目录（用来放数据库、缓存、图片索引等运行时数据）

### 硬件建议

数据来自一个约 2 万部影片元数据、3 千多部可播放媒体、170 万张缩略图规模的实际部署。

- **完整部署（5 个服务）**：内存空闲态约 2 GB（Postgres 300MB + 后端 320MB + JoyTag 440MB + Qdrant 1GB + Web 10MB），建议 **4 核 8G 起步**
- **只做元数据 + 播放（砍掉 JoyTag + Qdrant）**：内存空闲态约 500~700 MB，2 核 2G 也能跑，详见[轻量部署](/guide/lightweight-deploy)

## 部署步骤

### 1. 新建项目目录

在一块固态硬盘的空间里新建一个 `sakuramedia` 目录（假设是 `/vol1/1000/sakuramedia`），再在里面新建 `sakuramedia-data`；然后在 `sakuramedia-data` 下建三个子目录：

- `image-search-index` — Qdrant 图片向量库
- `postgres` — 数据库文件
- `joytag` — JoyTag 推理模型

### 2. 下载 JoyTag 模型

用任意下载工具下载模型文件，放进上一步创建的 `joytag/` 目录里：

```
https://github.com/tinypinglite/sakuramediabe/releases/download/model/model_vit_768.onnx
```

完成后 `sakuramedia-data` 结构如下：

![sakuramedia-data 目录结构](./images/fnos-data-dir.png)

::: tip 不想要以图搜图？
可以跳过这一步，同时把后面 compose 里 **`joytag-infer`** 和 **`qdrant`** 两段服务整段删掉即可，最终只留 `postgres` / `sakuramedia` / `sakuramedia-web` 三个服务。其它功能不受影响。
:::

### 3. 规划媒体目录

::: warning 强烈建议：三个目录必须在**同一父目录**下
最终你需要三个平级目录，它们**必须放在同一个父目录**（也就是同一块盘）下：

| 目录 | 用途 |
|---|---|
| `av` | 你已有的媒体目录 |
| `downloads` | qBittorrent 下载文件的落盘目录 |
| `sakuramedia` | SakuraMedia 接管后影片的落地目录 |

**为什么**：SakuraMedia 把已识别影片从 `av` / `downloads` 落进 `sakuramedia` 时，会**优先用硬链接**（不占额外空间、零耗时）。硬链接只能在同一块盘内做，如果跨盘就会**退化成复制**——不但慢，还会实打实占用你双倍空间。
:::

用飞牛文件管理器进入你的媒体父目录，右键 `av` → 弹出详情面板，点击**复制原始路径**，把这条路径记下来（假设复制出来是 `/vol1/1000/媒体库/av`）：

![飞牛复制原始路径演示](./images/fnos-copy-path.png)

然后在同一层再建一个 `sakuramedia` 空目录，最终三兄弟平级：

![av / downloads / sakuramedia 三个平级目录](./images/fnos-media-siblings.png)

### 4. 在 Docker 面板新建 Compose 项目

打开飞牛的 **Docker → Compose**，右上角点**新增项目**：

- **项目名称**：随便写，示例 `sakuramedia-service`
- **路径**：选**第 1 步创建的 `sakuramedia` 目录**（也就是 `/vol1/1000/sakuramedia`，**不是**里面的 `sakuramedia-data`）
- **来源**：选**创建 docker-compose.yml**

![新增 Compose 项目](./images/fnos-new-compose.png)

### 5. 填入 compose.yaml

**先修改下面 yaml 里媒体挂载那一行的宿主机路径，再整段粘贴进去。** 只需要改**注释标出来的那一行**，其它照抄即可。

```yaml
services:
  postgres:
    # 服务名保持 postgres，后端默认按这个主机名连接数据库，不要改名
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

      # 媒体挂载 —— 只改这一行
      # 冒号左边写你的媒体父目录（第 3 步里 av/downloads/sakuramedia 所在的那个父目录）
      # 例如 /vol1/1000/媒体库/av 的父目录就是 /vol1/1000/媒体库
      - /vol1/1000/媒体库:/mnt/media1   # ← 冒号左边改成你自己的实际路径

  # 以下两个服务用于以图搜图；不需要可整段删掉
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
      - "38080:80" # Web 前端端口
```

::: warning 服务名不能改
`postgres` / `joytag-infer` / `qdrant` 三个**服务名**（yaml 顶层的 key）不能改。后端会按这些主机名去连它们，改了名就连不上了。
:::

粘贴完成后，勾选**创建项目后立即启动**，然后点**确认**：

![Compose 编辑器](./images/fnos-compose-editor.png)

### 6. 等待构建

飞牛会依次拉镜像、创建网络、启动容器、等 postgres 健康检查通过、再依次拉起其它容器。全部成功后，日志最后会输出 **`Exited:0`**：

![构建成功 Exited:0](./images/fnos-compose-exited0.png)

如果卡住或某个容器反复重启，可以在 Docker 面板点开对应容器看日志排查。

### 7. 首次登录

浏览器打开 `http://你的IP:38080`，填入服务器地址与账号：

- **服务器地址**：`http://你的IP:38000` ← 注意是 **38000（API 端口）**，不是 38080
- **用户名 / 密码**：都是 `account`（登录后建议立即修改）

![首次登录](./images/fnos-login.png)

::: warning 推荐使用桌面 / 移动客户端
Web 端目前**未经充分测试**，可能存在体验问题或部分功能缺失。**推荐使用桌面端或移动端客户端**，从 [GitHub Releases](https://github.com/tinypinglite/sakuramedia/releases) 下载对应平台的安装包。

客户端首次登录同样填 **后端 API 地址** `http://你的IP:38000`（不是 `38080`）。
:::

## 首次登录后的初始化

登录进去后，点左下角**系统设置**，开始配置：

![系统设置入口](./images/fnos-settings-entry.png)

### 1. 新增媒体库

在**媒体库**页签点新增，填写：

- **名称**：随便写，例如 `媒体库1`
- **根路径**：填你规划好的 sakuramedia 落地目录**在容器内**的路径。第 5 步里我们把宿主机 `/vol1/1000/媒体库` 挂进容器成 `/mnt/media1`，所以：
  - 宿主机路径 `/vol1/1000/媒体库/sakuramedia` → 容器内路径 **`/mnt/media1/sakuramedia`**

![新增媒体库](./images/fnos-add-library.png)

::: tip 截图里为什么是 `/mnt/media1`？
截图只是演示界面，你实际填的应该是 `/mnt/media1/sakuramedia`（也就是第 3 步创建的那个空目录），而不是父目录。
:::

### 2. 添加下载器

::: warning 关键：qBittorrent 保存路径和本地访问路径要指向同一物理位置
两个路径分别是：

- **qBittorrent 保存路径**：你在 qBittorrent 容器里配置的下载落盘路径（例如 `/downloads`）
- **本地访问路径**：SakuraMedia **容器里**看到的同一目录的路径

**它们在宿主机上必须是同一目录**。也就是说，你部署 qBittorrent 时，qB 容器内 `/downloads` 要映射到宿主机的 `/vol1/1000/媒体库/downloads`（第 3 步里的那个 `downloads`）；SakuraMedia 也已经在第 5 步把 `/vol1/1000/媒体库` 挂成 `/mnt/media1`，所以这里**本地访问路径填 `/mnt/media1/downloads`** 即可。

不这么做的后果：SakuraMedia 找不到 qBittorrent 下载完成的文件，或者硬链接失败，都会导致自动入库失败。
:::

填完后**同时勾上「连通性」和「目录映射」两个测试项**再保存，确保都通过。

![添加下载器](./images/fnos-add-downloader.png)

### 3. 添加索引器

索引器就是 Jackett 里的一个个 tracker。在 Jackett 面板复制出目标 tracker 的 **torznab URL** 和 **API Key**，然后：

- **名称 / URL / API Key**：照 Jackett 里的填
- **类别**：选 **PT（私有）** 或 **BT（公网）**
- **绑定下载器**：选上一步创建的下载器 —— 通过这个索引器搜到的种子，会走绑定的下载器下载

![添加索引器](./images/fnos-add-indexer.png)

::: tip 同时用 BT 和 PT？
建议**部署两个 qBittorrent** 实例（比如 `qbittorrent-bt` 和 `qbittorrent-pt`），在 SakuraMedia 里各建一个下载器；然后 BT 类索引器绑 BT 下载器、PT 类索引器绑 PT 下载器，隔离干净。
:::

### 4. LLM 翻译（可选）

用于翻译影片标题和简介，不配也不影响使用。推荐模型见[常见问题 → 做影片信息翻译时，推荐用什么模型？](/faq#movie-desc-translation-model)。

## 完成后能做什么

- **导入已有影片**：进入「管理 → 媒体导入」，浏览 `/mnt/media1/av`（就是你原来的 `av` 目录在容器内的样子），批量入库
- **搜索并订阅影片 / 女优**：影片订阅后，后台定时任务会周期性搜可用资源并自动下载；女优订阅后会周期性同步她的新影片

## 相关页面

- 通用完整部署（用命令行、非飞牛 UI）：[快速开始](/guide/quick-start)
- 不部署下载器 / 索引器的最小方案：[轻量部署](/guide/lightweight-deploy)
- 进阶部署（OpenVINO 加速、目录规划思路）：[进阶部署](/guide/docker)
- 常见问题：[FAQ](/faq)
