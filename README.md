# SakuraMedia

SakuraMedia 是一个面向 NAS 用户的媒体管理工作台前端（Flutter 桌面应用）。
它通过连接 SakuraMediaBE，提供影片、女优、播放列表、时刻、以图搜图和系统配置等统一入口，适合在本地媒体库场景下做整理、检索与回看。

> ⚠️ 重要风险提示
>
> 当前 SakuraMedia（前后端整体）仍处于实验性阶段，可能存在数据损坏、配置误用、任务异常或误操作风险。请务必先在测试环境或有完整备份的前提下使用。
>
> 本项目仅用于技术交流与个人媒体管理实践，请在遵守当地法律法规与版权要求的前提下使用。

## 平台支持状态

| 平台 | 当前状态 | 说明 |
| --- | --- | --- |
| macOS | ✅ 已支持（当前主力） | 推荐日常使用平台 |
| Android | 🚧 未完成 | 客户端尚未完善 |
| Windows | 🚧 未完成 | 客户端尚未完善 |
| Web / 移动壳层 | 🧩 骨架/占位 | 仅基础路由与占位页面 |

## 功能清单

### 已支持（桌面端）

- 登录与会话管理：支持自定义服务器 BaseURL、登录、Token 自动刷新
- 概览：系统统计信息与最近入库影片
- 影片：列表/筛选/详情/订阅切换
- 女优：列表/筛选/详情/订阅切换
- 统一搜索：本地搜索 + 在线搜索（SSE 实时状态）
- 配置管理：媒体库、下载器、索引器、账号密码修改
- 播放器：媒体播放、续播进度回写、缩略图面板定位
- 时刻：全局标记点浏览、预览、跳转播放
- 播放列表：创建播放列表、查看详情、影片归档
- 以图搜图：上传图片检索、筛选、结果联动播放/详情/标记

### 进行中 / 未完整

- Android 与 Windows 客户端
- 移动端与 Web 端完整业务页面

## 系统架构（用户视角）

```text
SakuraMedia（Flutter macOS 客户端）
            <->
SakuraMediaBE（FastAPI 服务）
            <->
NAS 媒体目录 / Jackett / qBittorrent / JoyTag
```

说明：客户端不提供任何媒体资源本体，只负责业务操作入口、元数据展示与检索流程。

## 快速开始（面向 NAS 用户）

### 前提条件

- 你已部署并可访问 SakuraMediaBE
- 如需以图搜图，请准备 JoyTag 模型文件（`model_vit_768.onnx`）

### A. 启动后端（最短路径）

在 SakuraMediaBE 仓库执行（完整说明见后文链接）：

```bash
mkdir -p docker-data/config docker-data/db docker-data/cache/assets docker-data/cache/gfriends docker-data/image-search-index docker-data/logs docker-data/joytag
cp config.example.toml docker-data/config/config.toml
docker compose up --build -d
```

默认 API 地址示例：`http://localhost:38000`

### B. 启动 macOS 客户端

在本仓库执行：

```bash
flutter pub get
flutter run -d macos
```

### C. 首次登录

- BaseURL 填写后端地址，例如：`http://127.0.0.1:38000`
- 用户名/密码来自 SakuraMediaBE 的 `config.toml`
- 后端默认示例账号：`account / account`（请尽快修改）

### D. 首次配置顺序（建议严格按顺序）

1. 先创建媒体库（Media Library）
2. 再创建下载器（Download Client），确认 `qBittorrent 保存路径` 与 `本地访问路径` 映射正确
3. 再配置索引器（Indexer）：填写 Jackett API Key、添加 indexer、并绑定下载器
4. 最后再进行在线搜索、订阅与下载链路操作

## 推荐使用流程（NAS 场景）

1. 导入已有媒体
2. 浏览已有影片/女优并按需订阅
3. 使用在线搜索并按需订阅影片/女优
4. 用时刻与播放列表管理回看内容
5. 用以图搜图做精准场景识别

## 常见问题（精简）

- 无法登录：检查 BaseURL、端口与后端容器状态
- 在线搜索无结果：通常是索引器未配置完成，或 indexer 未绑定下载器
- 以图搜图无结果：通常是 JoyTag 模型未部署，或索引任务尚未生成
- 播放/缩略图异常：优先检查后端媒体路径挂载与下载路径映射是否一致

## 文档与仓库

- 前端仓库：<https://github.com/tinypinglite/sakuramedia>
- 后端仓库：<https://github.com/tinypinglite/sakuramediabe>
- 后端 Docker 部署：<https://github.com/tinypinglite/sakuramediabe/blob/main/docs/deployment/docker.md>
- 后端部署后常用命令：<https://github.com/tinypinglite/sakuramediabe/blob/main/docs/deployment/commands.md>
- 后端 FAQ：<https://github.com/tinypinglite/sakuramediabe/blob/main/docs/faq.md>
- 后端 API 文档总览：<https://github.com/tinypinglite/sakuramediabe/blob/main/docs/README.md>

## 声明

- SakuraMedia 仅提供媒体管理与检索工作台能力，不提供任何媒体资源内容。
- 请确保你的使用行为符合所在地法律法规与版权要求。
- License: [GNU GPL v3](./LICENSE)
