<p align="center">
  <img src="./wiki/public/brand/sakuramedia-logo.png" alt="SakuraMedia logo" width="96" />
</p>

<h1 align="center">SakuraMedia</h1>

<p align="center">面向 NAS 用户的 Jav 观影平台</p>

<p align="center">
提供以影片为中心，整合订阅、自动下载、观影、影片信息翻译与相似画面探索的一体化体验。
</p>

<p align="center">
  <img src="./wiki/public/images/sakuramedia-home-hero.png" alt="SakuraMedia 海报图" width="1100" />
</p>

<p align="center">
  <a href="https://tinypinglite.github.io/sakuramedia/"><strong>查看 Wiki</strong></a>
  ·
  <a href="https://tinypinglite.github.io/sakuramedia/guide/quick-start"><strong>快速开始</strong></a>
</p>

<h2 align="center">特性</h2>

- 影片发现与观影：以影片为中心，支持搜索、订阅、下载、播放与评论浏览，让找片、看片和继续追更形成更连贯的一体化体验。
- 影片信息翻译：支持调用大模型API为影片标题和介绍生成中文内容，方便在现有影片信息基础上补齐更适合中文阅读的元数据。
- 缩略图辅助观影：播放过程中可以结合影片缩略图快速预览不同画面，更高效地定位想看的片段，切换到更感兴趣的内容。
- 以图搜图探索相似场景：当你看到喜欢的画面时，可以从缩略图继续出发，查找相似场景与相关内容，把兴趣从单部影片延伸到更多作品。
- 女优订阅与最新作品追踪：可以围绕女优持续追踪新作动态，订阅后更方便集中查看她的最新作品，不错过后续更新。
- 多客户端支持：支持 Web、桌面端与移动端访问，已覆盖多端基础路由与部分真实页面，便于在不同设备上持续使用同一套服务与内容体验。

<h2 align="center">是什么 / 不是什么</h2>

SakuraMedia 面向 NAS 用户，原因在于它本身就是前后端分离的设计。后端需要部署在你的 NAS 中并长时间稳定运行，持续承担影片发现、订阅、自动化下载、入库、媒体服务和任务调度等能力，前端则负责把这些能力在 Web、桌面端和移动端统一呈现出来。

如果你用过早期的 `nastool` 或 `moviepilot`，可以把 SakuraMedia 理解为一种更完整的产品形态：`nastool + 媒体中心 + 全平台 App`。这只是帮助理解的类比，不代表 SakuraMedia 依赖 Jellyfin、Emby、Plex 之类的现成媒体服务器，也不是对它们的封装。当前 GitHub 上不少同类开源项目更多停留在刮削或外部播放源接入，SakuraMedia 更强调从发现、订阅、下载、入库到观看的一体化闭环；其中自动化下载能力依赖你自己配置可用的 indexer 和下载链路。SakuraMedia 本身不提供任何资源。

**SakuraMedia 是什么**

- 面向 NAS 用户、以前后端分离方式运行的一体化 Jav 观影平台。
- 覆盖影片发现、订阅、自动化下载、入库、观看等完整链路，后端需要在 NAS 中长期运行。
- 提供统一的多端访问入口，让同一套服务和媒体库可以在 Web、桌面端与移动端持续使用。

**SakuraMedia 不是什么**

- 不是单纯的刮削器，也不是只负责补充元数据的工具。
- 和 Jellyfin、Emby、Plex 没有依赖或从属关系，不是它们的前端、插件或壳。
- 不能直接接管和管理你现有目录里的媒体文件，但支持把已有媒体导入 SakuraMedia。
- 支持导入已有媒体，具体可以查看 Wiki 中的常用命令；导入时不会修改、搬走或破坏你的源文件，通常会以硬链接形式处理，如果跨硬盘导入则会降级为复制操作。
- 导入完成后，你可以在 SakuraMedia 中继续观看和管理这些已经存在的媒体。

<h2 align="center">风险与声明</h2>

- SakuraMedia 当前仍处于持续迭代阶段，建议优先在测试环境或有完整备份的前提下使用。
- 项目提供的是媒体管理与工作台能力，不提供任何媒体资源内容。
- 请确保你的使用行为符合所在地法律法规与版权要求。
- License: [GNU GPL v3](./LICENSE)
