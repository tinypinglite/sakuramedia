import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/clip_mutation_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/movie_clips_controller.dart';

MediaClipDto _clip(int id, {String title = ''}) =>
    MediaClipDto.fromJson(<String, dynamic>{
      'clip_id': id,
      'media_id': 1,
      'movie_number': 'ABC-001',
      'start_offset_seconds': 0,
      'end_offset_seconds': 10,
      'title': title.isEmpty ? 'clip-$id' : title,
      'duration_seconds': 10,
      'file_size_bytes': 0,
      'stream_url': '/media-clips/$id/stream',
      'created_at': '2026-06-13T10:00:00Z',
    });

void main() {
  late ClipMutationChangeNotifier mutationNotifier;

  setUp(() {
    mutationNotifier = ClipMutationChangeNotifier();
  });

  tearDown(() {
    mutationNotifier.dispose();
  });

  MovieClipsController build({
    required Future<List<MediaClipDto>> Function({
      required String movieNumber,
      int limit,
    })
    fetchClips,
    String movieNumber = 'ABC-001',
  }) {
    return MovieClipsController(
      movieNumber: movieNumber,
      mutationNotifier: mutationNotifier,
      fetchClips: fetchClips,
    );
  }

  test('load populates clips and forwards movie number on success', () async {
    String? receivedNumber;
    int? receivedLimit;
    final controller = build(
      fetchClips: ({required String movieNumber, int limit = 30}) async {
        receivedNumber = movieNumber;
        receivedLimit = limit;
        return <MediaClipDto>[_clip(1), _clip(2)];
      },
    );

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.clips.map((clip) => clip.clipId), <int>[1, 2]);
    expect(receivedNumber, 'ABC-001');
    expect(receivedLimit, 30);

    controller.dispose();
  });

  test('load sets an error message and keeps list empty on failure', () async {
    final controller = build(
      fetchClips:
          ({required String movieNumber, int limit = 30}) async =>
              throw Exception('boom'),
    );

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNotNull);
    expect(controller.clips, isEmpty);

    controller.dispose();
  });

  test('load skips fetch when movie number is blank', () async {
    var called = false;
    final controller = build(
      movieNumber: '   ',
      fetchClips: ({required String movieNumber, int limit = 30}) async {
        called = true;
        return const <MediaClipDto>[];
      },
    );

    await controller.load();

    expect(called, isFalse);
    expect(controller.clips, isEmpty);
    expect(controller.errorMessage, isNull);
    expect(controller.isLoading, isFalse);

    controller.dispose();
  });

  test('removeClip drops the matching clip', () async {
    final controller = build(
      fetchClips:
          ({required String movieNumber, int limit = 30}) async =>
              <MediaClipDto>[_clip(1), _clip(2)],
    );
    await controller.load();

    controller.removeClip(1);

    expect(controller.clips.map((clip) => clip.clipId), <int>[2]);

    controller.dispose();
  });

  test('replaceClip swaps the matching clip in place', () async {
    final controller = build(
      fetchClips:
          ({required String movieNumber, int limit = 30}) async =>
              <MediaClipDto>[_clip(1), _clip(2)],
    );
    await controller.load();

    controller.replaceClip(_clip(1, title: '改名后'));

    final first = controller.clips.firstWhere((clip) => clip.clipId == 1);
    expect(first.title, '改名后');
    expect(controller.clips, hasLength(2));

    controller.dispose();
  });

  test('removes a clip when delete is broadcast externally', () async {
    final controller = build(
      fetchClips:
          ({required String movieNumber, int limit = 30}) async =>
              <MediaClipDto>[_clip(1), _clip(2)],
    );
    await controller.load();

    // 模拟「我的切片」页删除同一切片：本控制器监听广播后就地移除。
    mutationNotifier.reportDeleted(2);

    expect(controller.clips.map((clip) => clip.clipId), <int>[1]);

    controller.dispose();
  });

  test('leaves the list untouched for collection membership broadcast',
      () async {
    final controller = build(
      fetchClips:
          ({required String movieNumber, int limit = 30}) async =>
              <MediaClipDto>[_clip(1)],
    );
    await controller.load();

    mutationNotifier.reportCollectionMembershipChanged(clipId: 1);

    expect(controller.clips.map((clip) => clip.clipId), <int>[1]);

    controller.dispose();
  });

  test('stops listening to broadcasts after dispose', () async {
    final controller = build(
      fetchClips:
          ({required String movieNumber, int limit = 30}) async =>
              <MediaClipDto>[_clip(1)],
    );
    await controller.load();
    controller.dispose();

    // dispose 后再广播不应抛异常（监听已移除）。
    expect(() => mutationNotifier.reportDeleted(1), returnsNormally);
  });
}
