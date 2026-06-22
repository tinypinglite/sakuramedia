import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/features/videos/data/video_collection_dto.dart';
import 'package:sakuramedia/widgets/movie_player/collection_playback_mode.dart';

/// 合集详情页 → 连播页 的一次性「交接信箱」。
///
/// 详情页在用户点击某集、跳转连播页**之前**，把当前已排序、可直接播放的成员列表
/// 暂存于此；连播页打开时取走直接组装播放列表，免去重复全量拉取（即原本「详情页和
/// 连播页各自全量拉一遍」的浪费）。**取走即清**，保证只被紧邻的那次导航消费；深链 /
/// 刷新等取不到时，连播页回退到自行拉取。
///
/// 在 `lib/app/app.dart` 作为普通 [Provider]（非监听）注册，详情页 `offer*`、
/// 连播页 `take*`，均通过 `context.read` 访问。数据是「点击那一刻」的实时列表，
/// 因此天然新鲜，无需失效逻辑。
///
/// 「播放模式」走独立的 [offerMode]/[takeMode]：与 items 信箱解耦，便于在详情页
/// 同步弹窗拿到选择后单独 offer。深链/刷新场景取不到 → 连播页回退默认 playlist 模式。
class CollectionPlaybackHandoff {
  _VideoHandoff? _video;
  _ClipHandoff? _clip;
  final Map<String, CollectionPlaybackMode> _modes = <String, CollectionPlaybackMode>{};

  /// 暂存视频合集成员。成员须带 `playUrl`（详情页以 `includePlayUrl` 加载），否则
  /// 连播页拿到也无法直接组装播放列表。[sort] 须与连播页将收到的排序一致，作匹配键。
  void offerVideoItems({
    required int collectionId,
    required String? sort,
    required List<VideoCollectionItemDto> items,
  }) {
    _video = _VideoHandoff(collectionId: collectionId, sort: sort, items: items);
  }

  /// 取走匹配 [collectionId] 且排序一致的成员；一次性（取后清空），不匹配返回 `null`。
  List<VideoCollectionItemDto>? takeVideoItems({
    required int collectionId,
    required String? sort,
  }) {
    final cached = _video;
    if (cached == null ||
        cached.collectionId != collectionId ||
        cached.sort != sort) {
      return null;
    }
    _video = null;
    return cached.items;
  }

  /// 暂存切片合集成员（切片自带 `streamUrl`，可直接播放；连播无排序参数）。
  void offerClips({
    required int collectionId,
    required List<MediaClipDto> clips,
  }) {
    _clip = _ClipHandoff(collectionId: collectionId, clips: clips);
  }

  /// 取走匹配 [collectionId] 的切片；一次性（取后清空），不匹配返回 `null`。
  List<MediaClipDto>? takeClips({required int collectionId}) {
    final cached = _clip;
    if (cached == null || cached.collectionId != collectionId) {
      return null;
    }
    _clip = null;
    return cached.clips;
  }

  /// 暂存用户在详情页选择的「播放模式」；[key] 由调用方约定（切片用 `clip:<id>`、
  /// 视频用 `video:<id>:<sort>`），与 items 信箱独立。
  void offerMode({required String key, required CollectionPlaybackMode mode}) {
    _modes[key] = mode;
  }

  /// 取走 [key] 上的播放模式；一次性（取后清空），不存在返回 `null`，连播页据此回退默认。
  CollectionPlaybackMode? takeMode({required String key}) {
    return _modes.remove(key);
  }
}

class _VideoHandoff {
  const _VideoHandoff({
    required this.collectionId,
    required this.sort,
    required this.items,
  });

  final int collectionId;
  final String? sort;
  final List<VideoCollectionItemDto> items;
}

class _ClipHandoff {
  const _ClipHandoff({required this.collectionId, required this.clips});

  final int collectionId;
  final List<MediaClipDto> clips;
}
