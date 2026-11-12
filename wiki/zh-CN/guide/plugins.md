---
outline: [2, 3]
---

# 推荐插件

SakuraMedia 的媒体存储、下载和部分自动化能力由插件提供。可直接在「系统设置 → 插件 → 插件市场」中浏览、安装和更新插件（移动端在「插件」页底部进入），也可以手动上传 zip 安装包。插件与宿主的接口兼容规则见[插件开发文档](/zh-CN/guide/plugin-development#版本兼容)。

::: info 关于插件来源
当前版本要求所有插件声明 Host API 18；未按 18 重新发版的旧插件不可用。官方镜像内置 10 个官方插件，首次启动会自动安装并启用；升级镜像时会同步升级内置插件，并保留插件配置、`data/` 与启停状态。

下面只收录源码仓库公开且提供 Release 安装包的插件。授权范围以各仓库的声明为准。
:::

## 通过插件市场安装

1. 打开「系统设置 → 插件」，切到「插件市场」分栏。
2. 找到需要的插件点击「安装」；已安装的插件有新版本时，按钮会变成「更新」。
3. 安装完成后，重启 SakuraMedia 容器，使 API 和 APS 重新加载插件及其依赖。

市场索引来自官方维护的 [sakuramedia-plugin-market](https://github.com/tinypinglite/sakuramedia-plugin-market) 仓库，收录官方与社区插件；社区插件会标注「社区」徽章，安装前请确认来源可信。

## 手动安装 zip

不使用插件市场时，也可以手动下载安装包：

1. 从插件的「下载最新版」页面下载 zip 安装包。
2. 进入「系统设置 → 插件」，在「已安装」分栏点击「安装插件」上传 zip 并确认插件已启用。
3. 安装完所有需要的插件后，重启 SakuraMedia 容器，使 API 和 APS 重新加载插件及其依赖。
4. Provider 插件安装后，先在「系统设置 → 媒体库」创建媒体库；需要下载时，再创建绑定该媒体库的下载器。
5. 排行榜、合集判定、字幕和女优资料补全插件的后台任务可在任务中心查看或手动触发。

::: warning 安全提示
插件会在 SakuraMedia 后端进程内运行。请只安装可信来源的插件；社区插件未经官方审计，安装前建议先阅读其源码。
:::

本页列出的插件安装或更新后均需重启容器才会生效；官方镜像内置的插件在首次启动时自动安装并启用。插件的底层目录和配置项见[配置说明](/zh-CN/guide/config#plugins)，命令行管理方式见[常用命令](/zh-CN/guide/commands#插件管理)。

## 插件目录

| 插件 | 插件 ID | 内置 | 用途 | 地址 |
|---|---|---|---|---|
| 本地存储与 qBittorrent | `sakuramedia_local_provider` | 是 | 接入本地媒体目录，提供手动导入、qBittorrent 下载、后端代理播放、缩略图和片段。 | [源码](https://github.com/tinypinglite/sakuramedia_local_provider) · [下载最新版](https://github.com/tinypinglite/sakuramedia_local_provider/releases/latest) |
| 115 网盘 Provider | `sakuramedia_115_provider` | 是 | 接入 115 网盘，提供目录浏览、影片导入、115 离线下载、302/后端代理播放、缩略图和片段。 | [源码](https://github.com/tinypinglite/sakuramedia_115_provider) · [下载最新版](https://github.com/tinypinglite/sakuramedia_115_provider/releases/latest) |
| 光鸭云盘 Provider | `sakuramedia_guangyapan_provider` | 是 | 接入光鸭云盘，提供目录浏览、影片导入、302 直链或后端代理播放、缩略图、片段，以及磁力/种子云添加下载。 | [源码](https://github.com/tinypinglite/sakuramedia_guangyapan_provider) · [下载最新版](https://github.com/tinypinglite/sakuramedia_guangyapan_provider/releases/latest) |
| DMM / FANZA 元数据 | `sakuramedia_dmm_metadata` | 是 | 按番号从 DMM / FANZA 提供日文标题、简介、发行日期、时长、片商、系列、演员、导演、标签、封面和样张。 | [源码](https://github.com/tinypinglite/sakuramedia_dmm_metadata) · [下载最新版](https://github.com/tinypinglite/sakuramedia_dmm_metadata/releases/latest) |
| FC2 元数据 | `sakuramedia_fc2_metadata` | 是 | 按商品号从 FC2 官方商品页提供标题、简介、标签、封面和样张；官方页没有演员栏。 | [源码](https://github.com/tinypinglite/sakuramedia_fc2_metadata) · [下载最新版](https://github.com/tinypinglite/sakuramedia_fc2_metadata/releases/latest) |
| FC2CMADB 元数据 | `sakuramedia_fc2cmadb_metadata` | 是 | 按商品号从 FC2CMADB 镜像提供标题、标签和封面；没有简介和剧情图，女优信息为尽力补全。 | [源码](https://github.com/tinypinglite/sakuramedia_fc2cmadb_metadata) · [下载最新版](https://github.com/tinypinglite/sakuramedia_fc2cmadb_metadata/releases/latest) |
| JavBus 元数据 | `sakuramedia_javbus_metadata` | 是 | 按番号从 JavBus 提供标题、发行日期、时长、片商、导演、系列、演员、标签、封面和剧照；没有简介。同时支持订阅女优作品列表同步。 | [源码](https://github.com/tinypinglite/sakuramedia_javbus_metadata) · [下载最新版](https://github.com/tinypinglite/sakuramedia_javbus_metadata/releases/latest) |
| 女优资料补全 | `sakuramedia_actor_metadata` | 否 | 从 JavBus 补全本地女优的生日、身高、三围、罩杯和出生地；不补血型和性别，只写入空值，不覆盖人工维护的字段。需要时从插件市场安装。 | [源码](https://github.com/tinypinglite/sakuramedia-actor-metadata) · [下载最新版](https://github.com/tinypinglite/sakuramedia-actor-metadata/releases/latest) |
| 更多影片榜单 | `sakuramedia_more_rank_movies` | 是 | 接入 Minnano AV 和 JavLibrary，提供 Minnano AV 日榜/周榜/月榜以及 JavLibrary 高评价、最想要榜单（上个月/全部），并注册定时同步任务。 | [源码](https://github.com/tinypinglite/sakuramedia_more_rank_movies) · [下载最新版](https://github.com/tinypinglite/sakuramedia_more_rank_movies/releases/latest) |
| 合集影片判定 | `sakuramedia_judge_collecttion_movie` | 是 | 按影片时长、番号特征和标签自动标记合集影片，不覆盖 App 内的手动判定。 | [源码](https://github.com/tinypinglite/sakuramedia_judge_collecttion_movie) · [下载最新版](https://github.com/tinypinglite/sakuramedia_judge_collecttion_movie/releases/latest) |
| SubtitleCat 中文字幕 | `sakuramedia_subtitlecat` | 是 | 为已有影片抓取 `zh-CN` 字幕，支持手动抓取单部影片和定时处理已订阅影片。 | [源码](https://github.com/tinypinglite/sakuramedia_subtitlecat) · [下载最新版](https://github.com/tinypinglite/sakuramedia_subtitlecat/releases/latest) |
| 影片文案抓取与翻译 | `sakuramedia_movie_scrape_translate` | 否 | 从 DMM 抓取影片的日文标题和简介，可选翻译成中文后写回影片标题与简介。需要时从插件市场安装。 | [源码](https://github.com/tinypinglite/sakuramedia_movie_scrape_translate) · [下载最新版](https://github.com/tinypinglite/sakuramedia_movie_scrape_translate/releases/latest) |

## 验证插件

- 在「系统设置 → 插件」中，桌面端点击插件行内的试管图标，移动端从插件操作菜单选择「能力测试」。
- 能力测试使用插件声明的测试番号，只读取当前已加载的配置；不会导入影片、写入互动数或保存评论。
- 修改插件配置后，先保存并重启后端再测试，否则测试仍使用旧配置。
- 「概览 → 组件诊断」会对每个已启用的元数据源执行同样的测试，并显示标题、演员、标签和图片数量；「无数据」表示插件有响应，但测试番号没有命中。

## 怎么选

- 官方镜像已内置本地存储与 qBittorrent、115、光鸭、四个元数据源、更多影片榜单、合集判定和字幕插件，首次部署无需上传。创建媒体库即可导入；需要自动下载时配置 qBittorrent。
- 四个内置元数据源默认启用，可在「设置 → 元数据源」调整顺序；保存顺序后需要重启后端。不同来源覆盖的番号不同，顺序只影响多个来源同时命中时的优先级。
- 影片文案抓取与翻译不内置，需要时从插件市场安装。DMM 元数据已提供日文标题和简介，只有需要把中文翻译写回影片时才需要它。
- 女优资料补全不内置，需要时从插件市场安装。
- 影片文案抓取与翻译需要容器能访问 DMM；当前网络访问受限时，为容器配置代理。启用翻译时还需配置兼容 `chat_completions` 的大模型 API。
- 元数据插件需要访问的外部域名和容器代理配置见[常见问题](/zh-CN/faq#元数据插件网络与代理)。
- SubtitleCat 当前只抓取中文字幕，且影片必须已经存在于 SakuraMedia。

## 配套服务不是插件

SigLIP2 嵌入服务和 SakuraMedia Torznab Server 是独立部署的配套服务，不能从「系统设置 → 插件」安装，因此不列入本页。
