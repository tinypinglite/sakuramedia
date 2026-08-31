---
outline: [2, 4]

---

### Joytag推理服务 GPU方案

#### 1. Intel核显

如果你已经用 CPU 版把系统跑通，并且满足下面条件，可以考虑试 `openvino`：

- 机器是 Intel CPU
- 机器有 Intel 核显

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
      - "8001:8001" # 如果你想要在其他机器部署 Joytag 推理服务可以映射端口， 然后修改配置文件中的 joytag 相关配置。
```

#### 2. CUDA 方案

如果你的机器装了 NVIDIA 独立显卡，可以用 `cuda` 版本的 `joytag-infer`，把图片搜索推理跑在 GPU 上。

##### 前置条件

部署 `cuda` 版前，宿主机需要先满足：

- 已经装好 NVIDIA 驱动，`nvidia-smi` 能正常输出 GPU 信息
- 驱动版本不低于 `550`（这是 CUDA 12.4 runtime 的最低要求）
- 已经装好 `nvidia-container-toolkit`，并且把 `nvidia` runtime 注册到了 Docker

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
      - "8001:8001" # 如果你想要在其他机器部署 Joytag 推理服务可以映射端口， 然后修改配置文件中的 joytag 相关配置。
```

这里有几个容易踩坑的点：

- `runtime: nvidia` 走的是 NVIDIA 老式 runtime 路径，目前最稳。在部分 Docker 和 toolkit 版本上，改用 `--gpus all` 会出现"容器能起来但 GPU 没注入"的情况，容器日志里会看到 `WARNING: The NVIDIA Driver was not detected`
- `NVIDIA_VISIBLE_DEVICES` 和 `NVIDIA_DRIVER_CAPABILITIES` 是 nvidia runtime 用来决定挂哪些设备和库的开关，不要省略
- `JOYTAG_INFER_BACKEND` 必须显式写成 `cuda`。容器启动时会硬校验 CUDA 是否真的可用，CUDA 不可用就直接抛错退出，不会静默回退到 CPU

