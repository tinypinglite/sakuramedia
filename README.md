<p align="center">
  <img src="./wiki/public/brand/sakuramedia-logo.png" alt="SakuraMedia logo" width="96" />
</p>

<h1 align="center">SakuraMedia</h1>

<p align="center">面向 NAS 用户的 NSFW 观影平台</p>

<p align="center">
以Jav影片为中心，整合搜索、订阅、下载、播放功能；同时也可用于非Jav影片的管理和观看。**由Flutter开发提供全平台支持**
</p>


<p align="center">
  <img src="./wiki/public/images/sakuramedia-home-hero.png" alt="SakuraMedia 海报图" width="1100" />
</p>

<p align="center">
  <a href="https://tinypinglite.github.io/sakuramedia/"><strong>查看 Wiki</strong></a>
  ·
  <a href="https://tinypinglite.github.io/sakuramedia/guide/quick-start"><strong>快速开始</strong></a>
  ·
  <a href="https://github.com/tinypinglite/sakuramediabe"><strong>后端仓库</strong></a>
</p>

<p align="center">
  本仓库为前端;后端(SakuraMediaBE)是独立项目,部署在 NAS 上,负责影片发现、订阅、下载、入库与媒体服务。<br />
  后端地址:<a href="https://github.com/tinypinglite/sakuramediabe">github.com/tinypinglite/sakuramediabe</a>
</p>

<h2 align="center">特性</h2>

- 影片发现与观影：以影片为中心，整合搜索、订阅、下载、播放功能。
- 缩略图辅助观影：播放界面侧边栏可选展示影片缩略图，用于快速预览不同画面，高效定位精彩片段。
- VR 影片播放：支持调用外部播放器播放 VR 影片，一部影片分多个片段的资源可合并为完整影片播放；实验性支持 Pico 等 VR 设备以 2D 形式使用。
- 以图搜图：当影片库达到一定数量级后，通过以图搜图功能，可以快速找到相似场景的影片片段。
- 女优订阅与最新作品追踪：支持订阅女优持续追踪新作动态。
- 多客户端支持：支持 Web端、并提供Win/Mac/IOS/Android 平台 APP。
- 排行榜：由已启用的排行榜插件提供来源和定时同步能力，可以快速找到最近热门的影片。

<h2 align="center">是什么 / 不是什么</h2>

SakuraMedia 适合拥有 NAS 的高级用户，原因在于它本身就是前后端分离的设计。后端（[SakuraMediaBE](https://github.com/tinypinglite/sakuramediabe)）需要部署在你的 NAS 中并长期稳定运行，持续承担媒体服务和任务调度等能力；本仓库作为前端，负责把这些能力在 Web、桌面端和移动端统一呈现出来。并且部署方面需要用到 `Docker`和`compose`，普通用户玩不明白这一套不建议使用。

如果你用过早期的 `nastool` 或现在的 `moviepilot`，可以把 SakuraMedia 理解为一种更完整的产品形态：`nastool + 媒体中心 + 全平台 App`。这只是帮助理解的类比，不代表 SakuraMedia 依赖 Jellyfin、Emby、Plex 之类的现成媒体服务器，也不是对它们的封装。当前 GitHub 上不少同类开源项目更多停留在刮削或外部播放源接入，SakuraMedia 更强调从发现、订阅、下载、入库到观看的一体化闭环；其中自动化下载能力依赖你自己配置可用的 索引器 和下载链路。SakuraMedia 本身不提供任何资源和下载能力。

**SakuraMedia 是什么**

- 面向 NAS 用户、以前后端分离方式运行的 Jav 影片管理平台。
- 整合搜索、订阅、下载、播放功能。
- 提供以图搜图、排行榜等辅助功能。

**SakuraMedia 不是什么**

- 不是单纯的刮削器，也不是负责补充元数据的工具。
- 和 Jellyfin、Emby、Plex 没有依赖或从属关系，不是它们的前端、插件或壳，不能也不会和它们联动。
- 不能直接接管和管理你现有目录里的媒体文件，但支持把已有媒体导入 SakuraMedia。导入完成后，你可以在 SakuraMedia 中继续观看和管理这些已经存在的媒体.



<h2 align="center">风险与声明</h2>

- **SakuraMedia 当前仍处于持续迭代阶段，不保证任何功能可用性和历史兼容性**，建议优先在测试环境或有完整备份的前提下使用。
- 项目提供的是媒体管理与工作台能力，不提供任何媒体资源内容的存储、下载、分发。
- 请确保你的使用行为符合所在地法律法规与版权要求。
- License: [GNU GPL v3](./LICENSE)

<h2 align="center">Star History</h2>

<p align="center">
  <a href="https://github.com/tinypinglite/sakuramedia/stargazers">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://tinypinglite.github.io/sakuramedia/star-history-dark.svg" />
      <source media="(prefers-color-scheme: light)" srcset="https://tinypinglite.github.io/sakuramedia/star-history-light.svg" />
      <img alt="Star History Chart" src="https://tinypinglite.github.io/sakuramedia/star-history-light.svg" />
    </picture>
  </a>
</p>
