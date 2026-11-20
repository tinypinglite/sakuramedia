# Android TV / Pico TV 模式

## 功能范围

TV 布局是独立的 `AppPlatform.tv` 路由和壳层，只保留电视端必要的观看链路：

- 登录、退出登录和界面语言切换
- 首页继续观看、最近添加、收藏、最近订阅和自定义/智能播放列表
- 影片库和女优影片列表（页头排序入口：发行时间 / 最近入库 / 订阅时间 / 热度 / 我的评分）
- 播放列表详情与页头排序入口
- 影片详情、媒体版本选择、合并播放（按媒体库连播多段）、收藏/已看、剧情图和演员入口
- 女优搜索
- 播放器、遥控器播放/暂停与快进快退
- 默认外部播放器选择，以及跟随后端 / 代理 / 直连播放模式
- 简单搜索

服务器管理、下载器、插件市场、媒体导入、投屏、通知和管理类页面不进 TV 路由。

## Android TV

普通 Android APK 已包含 `LEANBACK_LAUNCHER` 和 TV banner。电视会通过原生
`UiModeManager` / Leanback 特性自动进入 TV 布局；手机和平板仍走原有移动布局。

```bash
flutter build apk
```

## Pico 等非 Android TV 设备

Pico 运行 Android，但没有 Leanback 特性，也不会触发 Android TV 自动识别。
这类设备使用同一个代码库的“强制 TV 模式”包：

```bash
flutter build apk --dart-define=SAKURAMEDIA_TV=true
```

调试时可对已连接设备运行：

```bash
flutter run -d <device-id> --dart-define=SAKURAMEDIA_TV=true
```

Pico 上实际进入的是 2D 应用面板，不是原生 VR 界面；控制器按键到 Flutter
焦点的映射仍需在具体机型上验证。

## 遥控器按键

- 方向键：移动焦点
- 确定：进入/激活，播放器内播放或暂停
- 返回：关闭浮层、返回上一页或退出播放器
- 左右：播放器内快退/快进
- 媒体播放/暂停键：播放或暂停

## Apple TV

Flutter 官方不支持 tvOS，本仓库没有 tvOS target；现有 iOS IPA 不能安装到
Apple TV，TV 布局也不包含在 Apple TV 的交付范围内。
