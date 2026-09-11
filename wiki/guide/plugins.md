---
outline: [2, 3]
---

# 开源插件

SakuraMedia 的媒体存储、下载和部分自动化能力由插件提供。可在「系统设置 → 插件」中上传 zip 安装。插件与宿主的接口兼容规则见[插件开发文档](/guide/plugin-development#版本兼容)。

::: info 获取插件
下面只收录源码仓库公开且提供 Release 安装包的插件。授权范围以各仓库的声明为准。
:::

## 插件目录

| 插件 | 插件 ID | 用途 | 地址 |
|---|---|---|---|
| 115 网盘 Provider | `sakuramedia_115_provider` | 接入 115 网盘，提供目录浏览、影片导入、115 离线下载、302/后端代理播放、缩略图和片段。 | [源码](https://github.com/tinypinglite/sakuramedia_115_provider) · [下载最新版](https://github.com/tinypinglite/sakuramedia_115_provider/releases/latest) |
| 本地存储与 qBittorrent | `sakuramedia_local_provider` | 接入本地媒体目录，提供手动导入、qBittorrent 下载、后端代理播放、缩略图和片段。 | [源码](https://github.com/tinypinglite/sakuramedia_local_provider) · [下载最新版](https://github.com/tinypinglite/sakuramedia_local_provider/releases/latest) |
| 女优资料补全 | `sakuramedia_actor_metadata` | 从 JavDB 和 MinnanoAV 补全本地女优资料，包括生日、身高、三围、罩杯、出生地、血型和性别。 | [源码](https://github.com/tinypinglite/sakuramedia-actor-metadata) · [下载最新版](https://github.com/tinypinglite/sakuramedia-actor-metadata/releases/latest) |
| JavDB 排行榜 | `sakuramedia_javdb_ranking` | 提供 JavDB 热播、高评分、有码、无码、FC2 和 TOP250 榜单，并注册定时同步任务。 | [源码](https://github.com/tinypinglite/sakuramedia_javdb_ranking) · [下载最新版](https://github.com/tinypinglite/sakuramedia_javdb_ranking/releases/latest) |
| 合集影片判定 | `sakuramedia_judge_collecttion_movie` | 按影片时长和番号前缀自动标记合集影片，不覆盖 App 内的手动判定。 | [源码](https://github.com/tinypinglite/sakuramedia_judge_collecttion_movie) · [下载最新版](https://github.com/tinypinglite/sakuramedia_judge_collecttion_movie/releases/latest) |
| SubtitleCat 中文字幕 | `sakuramedia_subtitlecat` | 为已有影片抓取 `zh-CN` 字幕，支持手动抓取单部影片和定时处理已订阅影片。 | [源码](https://github.com/tinypinglite/sakuramedia_subtitlecat) · [下载最新版](https://github.com/tinypinglite/sakuramedia_subtitlecat/releases/latest) |

## 怎么选

- 后端镜像不内置插件。首次部署请先安装所需的存储 Provider：「本地存储与 qBittorrent」适合本机或 NAS 挂载目录加 qBittorrent，「115 网盘 Provider」适合 115 离线下载。
- 排行榜、合集判定、字幕和女优资料补全插件可以按需独立安装，不决定媒体的存储方式。
- JavDB 排行榜只有 TOP250 需要配置 JavDB 账号，其余榜单无需账号也能同步。
- SubtitleCat 当前只抓取中文字幕，且影片必须已经存在于 SakuraMedia。

## 安装与启用

以下步骤适用于所有插件。首次部署时，先安装存储 Provider，再按需安装其他插件：

1. 从插件的「下载最新版」页面下载 zip 安装包。
2. 进入「系统设置 → 插件」，上传 zip 并确认插件已启用。
3. 安装完所有需要的插件后，重启 SakuraMedia 容器，使 API 和 APS 重新加载插件及其依赖。
4. Provider 插件安装后，先在「系统设置 → 媒体库」创建媒体库；需要下载时，再创建绑定该媒体库的下载器。
5. 排行榜、合集判定、字幕和女优资料补全插件的后台任务可在任务中心查看或手动触发。

::: warning 安全提示
插件会在 SakuraMedia 后端进程内运行。请只安装可信来源的安装包，并在更新前核对下载页面和插件 ID。
:::

本页列出的插件均需手动安装和启用。插件的底层目录和配置项见[配置说明](/guide/config#plugins)，命令行管理方式见[常用命令](/guide/commands#插件管理)。

## 配套服务不是插件

SigLIP2 嵌入服务和 SakuraMedia Torznab Server 是独立部署的配套服务，不能从「系统设置 → 插件」安装，因此不列入本页。
