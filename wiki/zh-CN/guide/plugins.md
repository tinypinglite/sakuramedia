---
outline: [2, 3]
---

# 推荐插件

SakuraMedia 的媒体存储、下载和部分自动化能力由插件提供。可直接在「系统设置 → 插件 → 插件市场」中浏览、安装和更新插件（移动端在「插件」页底部进入），也可以手动上传 zip 安装包。插件与宿主的接口兼容规则见[插件开发文档](/zh-CN/guide/plugin-development#版本兼容)。

::: info 关于插件来源
当前版本要求所有插件声明 Host API 18；未按 18 重新发版的旧插件不可用。内置插件清单暂时为空，首次部署需要自行安装兼容插件。

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

本页列出的插件安装或更新后均需重启容器才会生效；官方镜像预装的插件在首次启动时已启用。插件的底层目录和配置项见[配置说明](/zh-CN/guide/config#plugins)，命令行管理方式见[常用命令](/zh-CN/guide/commands#插件管理)。

## 插件目录

| 插件 | 插件 ID | 用途 | 地址 |
|---|---|---|---|
| 115 网盘 Provider | `sakuramedia_115_provider` | 接入 115 网盘，提供目录浏览、影片导入、115 离线下载、302/后端代理播放、缩略图和片段。 | [源码](https://github.com/tinypinglite/sakuramedia_115_provider) · [下载最新版](https://github.com/tinypinglite/sakuramedia_115_provider/releases/latest) |
| 光鸭云盘 Provider | `sakuramedia_guangyapan_provider` | 接入光鸭云盘，提供目录浏览、影片导入、302 直链或后端代理播放、缩略图、片段，以及磁力/种子云添加下载。 | [源码](https://github.com/tinypinglite/sakuramedia_guangyapan_provider) · [下载最新版](https://github.com/tinypinglite/sakuramedia_guangyapan_provider/releases/latest) |
| 本地存储与 qBittorrent | `sakuramedia_local_provider` | 接入本地媒体目录，提供手动导入、qBittorrent 下载、后端代理播放、缩略图和片段。 | [源码](https://github.com/tinypinglite/sakuramedia_local_provider) · [下载最新版](https://github.com/tinypinglite/sakuramedia_local_provider/releases/latest) |
| 女优资料补全 | `sakuramedia_actor_metadata` | 从 JavDB 和 MinnanoAV 补全本地女优资料，包括生日、身高、三围、罩杯、出生地、血型和性别。 | [源码](https://github.com/tinypinglite/sakuramedia-actor-metadata) · [下载最新版](https://github.com/tinypinglite/sakuramedia-actor-metadata/releases/latest) |
| JavBus 元数据 | `sakuramedia_javbus_metadata` | 按番号从 JavBus 补全影片标题、发行日期、时长、片商、演员、标签、封面和剧照等元数据。 | [源码](https://github.com/tinypinglite/sakuramedia_javbus_metadata) · [下载最新版](https://github.com/tinypinglite/sakuramedia_javbus_metadata/releases/latest) |
| 影片文案抓取与翻译 | `sakuramedia_movie_scrape_translate` | 从 DMM 抓取影片的日文标题和简介，可选翻译成中文后写回影片标题与简介。 | [源码](https://github.com/tinypinglite/sakuramedia_movie_scrape_translate) · [下载最新版](https://github.com/tinypinglite/sakuramedia_movie_scrape_translate/releases/latest) |
| JavDB 排行榜 | `sakuramedia_javdb_ranking` | 提供 JavDB 热播、高评分、有码、无码、FC2 和 TOP250 榜单，并注册定时同步任务。 | [源码](https://github.com/tinypinglite/sakuramedia_javdb_ranking) · [下载最新版](https://github.com/tinypinglite/sakuramedia_javdb_ranking/releases/latest) |
| 更多影片榜单 | `sakuramedia_more_rank_movies` | 接入 Minnano AV 和 JavLibrary，提供 Minnano AV 日榜/周榜/月榜以及 JavLibrary 高评价、最想要榜单（上个月/全部），并注册定时同步任务。 | [源码](https://github.com/tinypinglite/sakuramedia_more_rank_movies) · [下载最新版](https://github.com/tinypinglite/sakuramedia_more_rank_movies/releases/latest) |
| 合集影片判定 | `sakuramedia_judge_collecttion_movie` | 按影片时长和番号前缀自动标记合集影片，不覆盖 App 内的手动判定。 | [源码](https://github.com/tinypinglite/sakuramedia_judge_collecttion_movie) · [下载最新版](https://github.com/tinypinglite/sakuramedia_judge_collecttion_movie/releases/latest) |
| SubtitleCat 中文字幕 | `sakuramedia_subtitlecat` | 为已有影片抓取 `zh-CN` 字幕，支持手动抓取单部影片和定时处理已订阅影片。 | [源码](https://github.com/tinypinglite/sakuramedia_subtitlecat) · [下载最新版](https://github.com/tinypinglite/sakuramedia_subtitlecat/releases/latest) |

## 怎么选

- 当前版本不再内置插件；请安装已声明 Host API 18 的本地存储 Provider，再创建媒体库。需要自动下载时配置 qBittorrent，需要 115 离线下载时安装「115 网盘 Provider」。
- 排行榜、合集判定、字幕、女优资料补全、JavBus 元数据和影片文案抓取与翻译插件可以按需独立安装，不决定媒体的存储方式。
- 影片文案抓取与翻译需要容器能访问 DMM（通常需日本 IP 或代理），启用翻译时还需配置兼容 `chat_completions` 的大模型 API。
- 按番号查询影片时，宿主按「设置 → 元数据源」中的插件顺序依次调用，第一个有效结果胜出。
- SubtitleCat 当前只抓取中文字幕，且影片必须已经存在于 SakuraMedia。

## 配套服务不是插件

SigLIP2 嵌入服务和 SakuraMedia Torznab Server 是独立部署的配套服务，不能从「系统设置 → 插件」安装，因此不列入本页。
