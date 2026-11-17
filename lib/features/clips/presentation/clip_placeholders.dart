import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 切片列表 / 详情加载态占位切片：真实 [MediaClipDto] + [BoneMock] 文案，
/// 封面为 `null` 不触发网络请求；时长给非零值让副信息骨块宽度接近真实。
List<MediaClipDto> clipPlaceholders({int count = 6}) {
  return List<MediaClipDto>.generate(
    count,
    (index) => MediaClipDto(
      clipId: -1 - index,
      mediaId: null,
      movieNumber: 'ABC-000',
      startOffsetSeconds: 0,
      endOffsetSeconds: 30,
      title: BoneMock.words(3),
      durationSeconds: 30,
      fileSizeBytes: 0,
      coverImage: null,
      streamUrl: '',
      createdAt: null,
    ),
    growable: false,
  );
}
