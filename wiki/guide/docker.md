---
outline: [2, 4]
---

# SigLIP2 嵌入服务硬件方案

快速开始中的 CPU 镜像适用于 AMD、Intel 和 ARM64 主机。SigLIP2 镜像已包含模型和运行时，**不需要**下载模型、挂载模型目录或预先缩放图片。

后端和嵌入服务在同一个 Compose 项目中时，不需要映射端口；后端默认通过 `http://siglip2-embed:8080` 访问服务。

## Intel 核显

适用于 Linux amd64 的 Intel 核显主机。将快速开始中的 `siglip2-embed` 服务替换为：

```yaml
  siglip2-embed:
    image: tinyping/siglip2-embed-service:intel
    container_name: siglip2-embed
    restart: unless-stopped
    devices:
      - /dev/dri:/dev/dri
    group_add:
      - "${RENDER_GID:-0}"
    environment:
      EMBEDDING_BACKEND: "intel_gpu"
      CPU_CONCURRENCY: "1"
```

在宿主机执行 `getent group render` 查看 `render` 组的 GID，并在同目录的 `.env` 文件写入 `RENDER_GID=实际GID`。确认 `/dev/dri` 存在后再启动容器。

## NVIDIA CUDA

宿主机需要已安装 NVIDIA 驱动、`nvidia-container-toolkit`，且 `nvidia-smi` 能正常显示显卡。将快速开始中的服务替换为：

```yaml
  siglip2-embed:
    image: tinyping/siglip2-embed-service:cuda
    container_name: siglip2-embed
    restart: unless-stopped
    gpus: all
    environment:
      EMBEDDING_BACKEND: "cuda"
      CPU_CONCURRENCY: "1"
```

若容器启动后没有使用 GPU，先检查 `docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi` 是否成功，再检查 NVIDIA Container Toolkit 配置。

## 将嵌入服务部署到其他主机

仅在后端与 SigLIP2 不在同一个 Compose 网络时才需要映射端口，例如添加：

```yaml
    ports:
      - "8080:8080"
```

然后把 `config.toml` 的 `[image_search].inference_base_url` 改为该服务的可访问 HTTP 地址。若服务启用了鉴权，同时填写 `inference_api_key`。
