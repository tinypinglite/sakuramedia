import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';

/// 切片合集详情 State：合集元信息 + 有序切片列表。
///
/// 合集切片量通常不大（后端 `_pageSize=50` 并发翻页拉全），本地始终持有完整
/// 有序列表，拖序 / 移除 / 硬删都对全量列表打补丁。
@immutable
class ClipCollectionDetailState {
  const ClipCollectionDetailState({
    required this.collection,
    required this.clips,
  });

  final ClipCollectionDto collection;
  final List<MediaClipDto> clips;

  bool get isEmpty => clips.isEmpty;

  ClipCollectionDetailState copyWith({
    ClipCollectionDto? collection,
    List<MediaClipDto>? clips,
  }) {
    return ClipCollectionDetailState(
      collection: collection ?? this.collection,
      clips: clips ?? this.clips,
    );
  }
}
