import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/features/shared/presentation/collection_playback_handoff.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';

void main() {
  VideoCollectionItemDto videoItem(int id) =>
      VideoCollectionItemDto.fromJson(<String, dynamic>{
        'item_id': id,
        'position': id,
        'play_url': '/media/$id/stream',
        'video': <String, dynamic>{
          'id': id,
          'title': 'V$id',
          'media_count': 1,
          'can_play': true,
        },
      });

  MediaClipDto clip(int id) => MediaClipDto.fromJson(<String, dynamic>{
        'clip_id': id,
        'stream_url': '/media-clips/$id/stream',
        'title': 'C$id',
      });

  group('视频成员交接', () {
    test('take 返回 offer 的成员，且一次性（取后清空）', () {
      final handoff = CollectionPlaybackHandoff();
      final items = <VideoCollectionItemDto>[videoItem(1), videoItem(2)];
      handoff.offerVideoItems(collectionId: 7, sort: null, items: items);

      expect(handoff.takeVideoItems(collectionId: 7, sort: null), same(items));
      // 取后即清，再取返回 null（避免后续深链误用陈旧数据）。
      expect(handoff.takeVideoItems(collectionId: 7, sort: null), isNull);
    });

    test('collectionId 或 sort 不匹配返回 null，且不消费', () {
      final handoff = CollectionPlaybackHandoff();
      final items = <VideoCollectionItemDto>[videoItem(1)];
      handoff.offerVideoItems(collectionId: 7, sort: 'title:asc', items: items);

      expect(handoff.takeVideoItems(collectionId: 8, sort: 'title:asc'), isNull);
      expect(handoff.takeVideoItems(collectionId: 7, sort: null), isNull);
      // 不匹配不消费，正确键仍可取到。
      expect(
        handoff.takeVideoItems(collectionId: 7, sort: 'title:asc'),
        same(items),
      );
    });
  });

  group('切片成员交接', () {
    test('take 返回 offer 的切片，且一次性（取后清空）', () {
      final handoff = CollectionPlaybackHandoff();
      final clips = <MediaClipDto>[clip(1), clip(2)];
      handoff.offerClips(collectionId: 3, clips: clips);

      expect(handoff.takeClips(collectionId: 3), same(clips));
      expect(handoff.takeClips(collectionId: 3), isNull);
    });

    test('collectionId 不匹配返回 null，且不消费', () {
      final handoff = CollectionPlaybackHandoff();
      final clips = <MediaClipDto>[clip(1)];
      handoff.offerClips(collectionId: 3, clips: clips);

      expect(handoff.takeClips(collectionId: 9), isNull);
      expect(handoff.takeClips(collectionId: 3), same(clips));
    });
  });

  test('视频与切片两个信箱互不干扰', () {
    final handoff = CollectionPlaybackHandoff();
    handoff.offerVideoItems(
      collectionId: 1,
      sort: null,
      items: <VideoCollectionItemDto>[videoItem(1)],
    );
    handoff.offerClips(collectionId: 1, clips: <MediaClipDto>[clip(1)]);

    expect(handoff.takeVideoItems(collectionId: 1, sort: null), isNotNull);
    expect(handoff.takeClips(collectionId: 1), isNotNull);
  });
}
