---
layout: home

hero:
  image:
    src: /brand/sakuramedia-logo.png
    alt: SakuraMedia logo
  name: SakuraMedia
  text: 面向 NAS 用户的 NSFW 观影平台
  tagline: 提供以 Jav 影片为中心，整合订阅、观影、影片信息翻译与相似画面探索的一体化体验；可选启用自动下载链路，也可以只作为纳管+播放工具使用，同样可用于非 Jav 影片的管理和观看。
  actions:
    - theme: brand
      text: 快速开始
      link: /guide/quick-start
    - theme: alt
      text: GitHub
      link: https://github.com/tinypinglite/sakuramedia
    - theme: alt
      text: 电报群
      link: https://t.me/+xIsN2OZvbM4wYzIx
    - theme: alt
      text: 下载离线 Wiki
      link: https://tinypinglite.github.io/sakuramedia/downloads/sakuramedia-wiki.zip

features:
  - title: 影片发现与观影
    details: 以影片为中心，支持搜索、订阅、下载、播放与评论浏览，让找片、看片和继续追更形成更连贯的一体化体验。
  - title: 影片信息翻译
    details: 支持调用大模型API为影片标题和介绍生成中文内容，方便在现有影片信息基础上补齐更适合中文阅读的元数据。
  - title: 缩略图辅助观影
    details: 播放过程中可以结合影片缩略图快速预览不同画面，更高效地定位想看的片段，切换到更感兴趣的内容。
  - title: 以图搜图探索相似场景
    details: 当你看到喜欢的画面时，可以从缩略图继续出发，查找相似场景与相关内容，把兴趣从单部影片延伸到更多作品。
  - title: 视频切片收藏与连播
    details: 在播放时从缩略图圈出喜欢的区间，单独切出切片收藏；切片与来源影片解耦，删了原影片也还在，还能把跨影片的切片串成合集连续播放。
  - title: PornBox 视频管理
    details: 没有番号、没有外部元数据的非 JAV 视频也能纳管，按视频合集整理收纳。
  - title: 女优订阅与最新作品追踪
    details: 可以围绕女优持续追踪新作动态，订阅后更方便集中查看她的最新作品，不错过后续更新。
  - title: 多客户端支持
    details: 支持 Web、桌面端与移动端访问，已覆盖多端基础路由与部分真实页面，便于在不同设备上持续使用同一套服务与内容体验。
---

<p align="center">
  <img src="/images/sakuramedia-home-hero.png" alt="SakuraMedia 海报图" />
</p>

::: danger 装之前先把这段读完——它很可能不适合你

SakuraMedia **不是开箱即用的 App，不是资源站，不提供任何片源**。它只干一件事：
把你已有的各种服务串起来, NAS、qbittorrent、jackett

**下面的几条，只要有一条不满足，或者说你看不懂在说什么， 那这个项目不适合你**

1. **你有一台 7×24 开机的机器**（NAS / 小主机都行），且可用内存不要低于4G
2. **你能把 Docker 镜像拉下来。** 国内直连 Docker Hub 基本拉不动，镜像加速或代理得你自己搞定， 部署时使用`docker compose`部署，全程没有一键安装包、没有图形化向导、没有「下一步下一步」， 你需要**有一定的阅读理解能力和耐心，把wiki完整的读一遍.**。
3. **你的NAS/小主机 上要有一定的存储空间**，媒体目录只在本地存储空间上进行了测试，通过NFS/SMB/WebDAV挂载的目录未经测试，建议使用NFS协议(NFS支持硬链接)挂载远程目录再挂载到容器中。 网盘方面已支持 [115 网盘](/guide/cloud115)（可作媒体库、目录导入、秒传归档、离线下载、直接播放），使用前请务必先看使用说明。
4. **你知道什么是jackett以及qBittorrent**，并且你已经在你的NAS/小主机上部署了它们.



**如果上面这几条你读着就费劲，或者需要有人手把手教你——那这个项目不适合你**
