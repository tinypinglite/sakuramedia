# lib/features/playlists/ — 影片播放列表(收藏夹)

用户自建的影片播放列表:创建、增删影片、拖序、跨设备顺序持久化。域级通用范式看 `lib/features/CLAUDE.md`。

## 目录结构

```
data/
  api/playlists_api.dart              (1)
  dto/playlist_dto.dart               (1)
  playlist_order_store.dart           # 例外:SharedPreferences 持久化辅助
                                      # (scopeKey + 有序 id 列表),既非 API 也非 DTO,
                                      # 放在 data/ 根不再另开子目录
presentation/
  controllers/                        (2 扁平,< 3 不分子域)
    playlist_detail_controller.dart
    playlists_overview_controller.dart
  pages/
    desktop/                          (2) playlists / playlist_detail
    mobile/                           (2) 同上
    shared/                           (1) playlist_detail_content
  widgets/                            (2 扁平)
    create_playlist_dialog.dart
    movie_playlist_picker_dialog.dart # 影片详情页「加入播放列表」入口
```

**在其它 feature 内 import 时**:DTO/API 走 `data/dto/`、`data/api/`,`PlaylistOrderStore` 直接从 `data/playlist_order_store.dart` 拿(见 `lib/app/CLAUDE.md` 装配顺序)。`movie_playlist_picker_dialog` 主要被 movies 详情动作(`features/movies/presentation/actions/`)触发。

## 域特有约定

- **顺序持久化**:`PlaylistOrderStore` 抽象 + `SharedPreferencesPlaylistOrderStore` 实现,`scopeKey` 命名空间隔离不同视图的顺序(如 `mobile_overview` 与 `desktop_playlists` 各自存)。**新增排序视图记得起唯一 scopeKey**。
- **共享列表 UI**:`playlist_detail_content` 内嵌 `MovieSummaryGrid`(来自 `widgets/movies/`),直接复用 movies 的列表渲染。
- **playlist_banner_card 在 lib/widgets/playlists/**:是被 `overview` mobile 骨架页借用的横向 banner 卡,保留在 `lib/widgets/playlists/`(跨 feature 共享,不进 feature)。

## 与测试的关系

`test/features/playlists/` 覆盖较全:
- `data/api/playlists_api_test`
- `presentation/controllers/*`(两个 controller 都有 test)
- `presentation/pages/{desktop,mobile}/*`(4 个 page test 全)

**无 dialog test、无 `playlist_order_store` 单测**;改这两处需手动验证。
