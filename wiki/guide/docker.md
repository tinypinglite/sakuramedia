# 进阶部署

这页不是“第一次上手指南”，而是给已经看过快速开始、准备把部署做稳做全的用户看的。重点是把这些高频问题一次讲清楚：

- 单硬盘和多硬盘怎么规划
- `compose.yaml` 里每一项到底在做什么
- SakuraMedia 自己需要看到哪些路径
- Intel 平台下 `openvino` 应该怎么开
- NVIDIA 平台下 `cuda` 应该怎么开

## 这页解决什么问题

如果你现在已经能用 `quick-start` 把服务跑起来，这一页主要帮助你解决下面这些“第二阶段问题”：

- 不止一块媒体盘时该怎么挂载
- 为什么建议把媒体根目录整体挂进 SakuraMedia 容器
- `client_save_path` 和 `local_root_path` 到底应该怎么配
- `joytag-infer` 除了 CPU 版，Intel 或 NVIDIA 平台还有没有更合适的方案

如果你还没完成第一次部署，建议先看“快速开始”。

## 推荐部署思路

### 单硬盘推荐方案

如果你当前只有一块主要媒体盘，最推荐的思路是：

- 用 SSD 存运行数据
- 用一块容量盘存媒体文件和下载目录
- 把媒体根目录整体挂进 SakuraMedia 容器

例如：

- 运行数据目录：`/mnt/ssd/sakuramedia`
- 媒体根目录：`/mnt/volume1/media`

媒体根目录下再分：

```text
/mnt/volume1/media
├── av
├── downloads
└── sakuramedia
```

这样做的优点是：

- 历史媒体、下载目录和新媒体库都在一个统一挂载根下
- 容器内外路径更容易保持一致
- 后面创建媒体库和配置下载器时最不容易绕晕

### 多硬盘推荐方案

如果你有多块媒体盘，不建议把所有历史资源强行混到一个目录里。更稳的做法是：

- 运行数据仍然统一放在 SSD
- 每块媒体盘保留自己的历史目录和下载目录
- 每块媒体盘各自建立一个 SakuraMedia 媒体库目录

例如：

```text
/mnt/volume1/media
├── av
├── downloads
└── sakuramedia

/mnt/volume2/media
├── av
├── downloads
└── sakuramedia
```

然后在 SakuraMedia 里：

- 每块盘建一个媒体库
- 每块盘建一个下载器映射
- 下载器指向对应盘的媒体库

这样做会比“一套下载器混多个盘”更稳定，也更容易排查路径问题。

### 为什么建议整体挂媒体根目录

推荐直接把：

```bash
/mnt/volume1/media
```

整体挂进 SakuraMedia 容器，而不是只挂一个子目录。

原因很简单：

- SakuraMedia 既要看到已有影片
- 也要看到下载目录
- 还要看到新媒体库目录

如果你只挂其中一部分，后面自动导入、媒体库配置、历史导入通常都会变复杂。

### 为什么建议统一宿主机路径和容器路径

只要条件允许，建议在 SakuraMedia 容器里继续使用原样路径：

```bash
/mnt/volume1/media:/mnt/volume1/media
```

这样做的好处是：

- 文档里写的路径和容器里看到的路径一致
- 创建媒体库时不用再做一次脑内映射
- `local_root_path` 更不容易填错

## 完整目录规划

一个比较稳的目录规划，通常至少包含这些部分：

- 运行数据目录
- 历史媒体目录
- 下载目录
- SakuraMedia 新媒体库目录

推荐示例：

```text
/mnt/ssd/sakuramedia
└── docker-data
    ├── config
    ├── db
    ├── cache
    ├── image-search-index
    ├── logs
    └── joytag

/mnt/volume1/media
├── av
├── downloads
└── sakuramedia
```

各目录作用：

- `docker-data/config`
  存 `config.toml`
- `docker-data/db`
  存数据库文件
- `docker-data/cache`
  存缓存、缩略图、字幕等运行数据
- `docker-data/image-search-index`
  存图片搜索索引
- `docker-data/logs`
  存日志
- `docker-data/joytag`
  存 JoyTag 模型
- `/mnt/volume1/media/av`
  历史媒体目录
- `/mnt/volume1/media/downloads`
  qBittorrent 实际下载目录
- `/mnt/volume1/media/sakuramedia`
  SakuraMedia 自己的新媒体库目录

### 下载器路径怎么理解

在 SakuraMedia 里配置下载器时，最重要的是理解下面两个字段：

- `client_save_path`
- `local_root_path = /mnt/volume1/media/downloads`

可以把它们理解成：

- `client_save_path`：下载器自己保存文件时使用的路径
- `local_root_path`：SakuraMedia 在自己容器里访问同一批下载文件时使用的路径

这两个值最重要的前提是：它们在实际文件系统上必须指向同一个下载目录。只要这层关系是对的，SakuraMedia 才能正确识别和导入下载结果。

## 完整 `compose.yaml` 说明

下面是一份适合作为进阶基线的单硬盘示例：

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
      - "8001:8001"

  sakuramedia-web:
    image: tinyping/sakuramedia-web:latest
    container_name: sakuramedia-web
    restart: unless-stopped
    depends_on:
      - sakuramedia
    ports:
      - "38080:80"
```

### 每个服务做什么

- `sakuramedia`
  主后端服务，负责账号、媒体库、下载链路、活动中心和任务调度
- `joytag-infer`
  图片搜索推理服务
- `sakuramedia-web`
  Web 前端

### 每个 volume 做什么

- `./docker-data/config:/data/config`
  配置文件
- `./docker-data/db:/data/db`
  数据库
- `./docker-data/cache/assets:/data/cache/assets`
  缩略图、图片缓存等
- `./docker-data/cache/subtitles:/data/cache/subtitles`
  字幕目录（导入时识别到的字幕文件）
- `./docker-data/image-search-index:/data/indexes`
  图片搜索索引
- `./docker-data/logs:/data/logs`
  日志
- `/mnt/volume1/media:/mnt/volume1/media`
  历史媒体、下载目录和新媒体库的统一挂载
- `./docker-data/joytag:/data/lib/joytag`
  JoyTag 模型目录

### 每个 port 做什么

- `38000`
  SakuraMedia API
- `38080`
  Web 页面
- `8001`
  `joytag-infer` 服务端口，主要供后端容器访问

### 新手通常不需要改的地方

第一次部署阶段，下面这些通常不建议改：

- `PUID` / `PGID` 以外的大部分环境变量
- `joytag-infer` 的批量参数
- volume 挂载结构
- `ports` 的内部端口

如果你只是端口冲突，优先只改左边的宿主机端口。

## 多硬盘部署

### 推荐方式

如果你有多块媒体盘，推荐按“每块盘一套媒体库 + 一套下载器配置”的思路来做。

例如：

- 盘 1：`/mnt/volume1/media`
- 盘 2：`/mnt/volume2/media`

在 `compose.yaml` 里都挂进去：

```yaml
volumes:
  - /mnt/volume1/media:/mnt/volume1/media
  - /mnt/volume2/media:/mnt/volume2/media
```

然后在 SakuraMedia 里分别创建：

- `媒体库 A -> /mnt/volume1/media/sakuramedia`
- `媒体库 B -> /mnt/volume2/media/sakuramedia`

### 下载器和媒体库如何对应

最推荐的做法是：

- 盘 1 的下载器指向盘 1 的媒体库
- 盘 2 的下载器指向盘 2 的媒体库

这样每个下载器只负责自己那块盘，后面定位问题会清晰很多。

### 同一个 qB 客户端能不能服务多个媒体库

可以，但前提是你自己已经把不同盘的下载目录区分清楚。

在 SakuraMedia 里，更推荐的做法仍然是：

- 每块盘建立一个下载器配置
- 每个下载器只对应一块盘的媒体库
- `local_root_path` 明确指向那块盘自己的下载目录

如果你不想把路径关系搞复杂，宁愿多建几个清晰的下载器配置，也不要让一个配置同时承担太多目录职责。

## OpenVINO 方案

这一节只讨论 Intel 平台。NVIDIA 平台见下文的 CUDA 方案。

### 什么时候考虑 OpenVINO

如果你已经用 CPU 版把系统跑通，并且满足下面任一条件，就可以考虑试 `openvino`：

- 机器是 Intel CPU
- 机器有 Intel 核显
- 图片搜索推理速度对你来说太慢

### 最小 `joytag-infer` 片段

#### Intel CPU 优先方案

```yaml
  joytag-infer:
    image: tinyping/joytag-infer:openvino
    container_name: joytag-infer
    restart: unless-stopped
    environment:
      JOYTAG_INFER_BACKEND: "openvino"
      JOYTAG_INFER_OPENVINO_DEVICE_TYPE: "CPU"
      JOYTAG_INFER_MODEL_PATH: "/data/lib/joytag/model_vit_768.onnx"
      JOYTAG_INFER_API_KEY: ""
    volumes:
      - ./docker-data/joytag:/data/lib/joytag
    ports:
      - "8001:8001"
```

#### Intel 核显尝试方案

```yaml
  joytag-infer:
    image: tinyping/joytag-infer:openvino
    container_name: joytag-infer
    restart: unless-stopped
    environment:
      JOYTAG_INFER_BACKEND: "openvino"
      JOYTAG_INFER_OPENVINO_DEVICE_TYPE: "GPU"
      JOYTAG_INFER_MODEL_PATH: "/data/lib/joytag/model_vit_768.onnx"
      JOYTAG_INFER_API_KEY: ""
    volumes:
      - ./docker-data/joytag:/data/lib/joytag
    devices:
      - /dev/dri:/dev/dri
    ports:
      - "8001:8001"
```

### `JOYTAG_INFER_OPENVINO_DEVICE_TYPE` 怎么选

- `CPU`
  最稳，最适合先验证 OpenVINO 是否正常
- `GPU`
  适合已配置好 Intel 核显直通并希望优先使用 GPU 推理

注意：当前容器只支持 `CPU` 或 `GPU`，不要设置为 `AUTO`。

建议顺序：

1. 先用 CPU 版把整套服务跑通
2. 再切到 `openvino + CPU`
3. 最后再尝试 `openvino + GPU`

## CUDA 方案

如果你的机器装了 NVIDIA 独立显卡，可以用 `cuda` 版本的 `joytag-infer`，把图片搜索推理跑在 GPU 上。

### 什么时候考虑 CUDA

满足下面任一条件时可以试 `cuda`：

- 机器装了 NVIDIA 独立显卡
- 图片搜索推理速度对你来说太慢

### 前置条件

部署 `cuda` 版前，宿主机需要先满足：

- 已经装好 NVIDIA 驱动，`nvidia-smi` 能正常输出 GPU 信息
- 驱动版本不低于 `550`（这是 CUDA 12.4 runtime 的最低要求）
- 已经装好 `nvidia-container-toolkit`，并且把 `nvidia` runtime 注册到了 Docker

### 最小 `joytag-infer` 片段

```yaml
  joytag-infer:
    image: tinyping/joytag-infer:cuda
    container_name: joytag-infer
    restart: unless-stopped
    runtime: nvidia
    environment:
      NVIDIA_VISIBLE_DEVICES: "all"
      NVIDIA_DRIVER_CAPABILITIES: "compute,utility"
      JOYTAG_INFER_BACKEND: "cuda"
      JOYTAG_INFER_MODEL_PATH: "/data/lib/joytag/model_vit_768.onnx"
      JOYTAG_INFER_API_KEY: ""
    volumes:
      - ./docker-data/joytag:/data/lib/joytag
    ports:
      - "8001:8001"
```

这里有几个容易踩坑的点：

- `runtime: nvidia` 走的是 NVIDIA 老式 runtime 路径，目前最稳。在部分 Docker 和 toolkit 版本上，改用 `--gpus all` 会出现"容器能起来但 GPU 没注入"的情况，容器日志里会看到 `WARNING: The NVIDIA Driver was not detected`
- `NVIDIA_VISIBLE_DEVICES` 和 `NVIDIA_DRIVER_CAPABILITIES` 是 nvidia runtime 用来决定挂哪些设备和库的开关，不要省略
- `JOYTAG_INFER_BACKEND` 必须显式写成 `cuda`。容器启动时会硬校验 CUDA 是否真的可用，CUDA 不可用就直接抛错退出，不会静默回退到 CPU

## 部署后如何检查是否正常

部署完成后，建议至少检查这几件事：

### 1. 容器状态是否正常

```bash
docker compose ps
```

至少要确认：

- `sakuramedia`
- `sakuramedia-web`
- `joytag-infer`

都已经正常启动。

### 2. Web 能不能打开

浏览器访问：

```bash
http://<你的NAS地址>:38080
```

能打开登录页，说明 Web 基本可用。

### 3. 登录和配置能不能保存

建议实际做一次：

- 登录
- 创建媒体库
- 添加下载器
- 保存 Jackett 配置

如果这些配置能保存，说明后端、数据库和主要页面链路都正常。

### 4. 搜索是否正常

第一次可以尝试：

- 搜影片番号
- 开启 `联网` 搜一次
- 再搜同一条数据确认本地已入库

如果这一套能通，说明最基本的数据写入链路没问题。

### 5. `joytag-infer` 是否读到模型

最简单的先看容器日志，确认没有模型缺失或启动失败。

如果你想更稳一点，也可以在服务启动后关注图片搜索相关状态页或日志输出，确认 `joytag-infer` 已经正常响应。
