# lib/features/clip_collections/ — 切片合集

切片合集 CRUD、合集详情、合集连播。与 `videos/collections` 平行但服务对象是**切片(clips)**而非视频。域级通用范式看 `lib/features/CLAUDE.md`(尤其"短视频/切片域"一节的合集连播接线)。

## 目录结构

```
data/
  api/clip_collections_api.dart  (1)
  dto/clip_collection_dto.dart   (1,dto/ 内平铺)
presentation/
  controllers/                   (2 扁平,< 3 不分子域)
    clip_collection_detail_controller.dart
    clip_collections_overview_controller.dart
  pages/
    desktop/                     (3) clip_collections / detail / play
    mobile/                      (3) 同上
  widgets/                       (5 扁平,全部是 dialog)
    add_clips_to_collection_dialog.dart
    add_to_clip_collection_dialog.dart
    create_clip_collection_dialog.dart
    pick_clip_collection_dialog.dart
    clip_collection_delete_dialog.dart(从原 lib/widgets/clip_collections/ 迁入)
```

**在其它 feature 内 import 时**:DTO 从 `data/dto/`,API 从 `data/api/`,controllers 直接从 `presentation/controllers/`(无子域)。

## 与 videos/collections 的差异

- **无独立成员端点分页**:切片合集直接用 `ClipCollectionsApi.getAllCollectionClips`(并发翻页拉全,详见 `lib/features/CLAUDE.md`)。videos 合集有独立的 `getCollectionItems` 分页 + `getAllCollectionItems` 并发拉全。
- **无 reorder 端点**:拖序走 `setCollectionClips` 全量覆盖。videos 合集有独立 reorder 且**必须全量**。
- **成员自带 streamUrl**:`ClipDto` 自带播放地址,连播不用回拉。videos 合集则依赖成员 `playUrl` 内联(需 `includePlayUrl: true`)。
- **共享连播 mixin/组件**:两个连播页 State 都 `with CollectionPlaybackPageMixin`,右侧关键帧面板复用 `MoviePlayerThumbnailPanel`(切片走 `ClipsApi.getClipThumbnails` 取帧)——见 `lib/widgets/CLAUDE.md`「合集连播页布局」一节。**切片帧无对应 media,不支持添加时刻**(与 pornbox 相反)。

## 与测试的关系

`test/features/clip_collections/`:
- `data/api/clip_collections_api_test`
- `presentation/controllers/clip_collection_detail_controller_test`
- `presentation/controllers/clip_collections_overview_controller_test`

**无 page test、无 dialog test、无连播集成测试**;改这些没有回归网,需手动验证。
