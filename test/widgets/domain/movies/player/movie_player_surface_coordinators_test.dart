import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_surface_coordinators.dart';

void main() {
  group('MoviePlayerSurfaceOpenCoordinator', () {
    test(
      'opens paused with requested start position, then starts playback',
      () async {
        final fake = _FakePlaybackFunctions();
        var markedReady = false;

        await const MoviePlayerSurfaceOpenCoordinator().open(
          open: fake.open,
          play: fake.play,
          seek: fake.seek,
          waitUntilFirstFrameRendered: fake.waitUntilFirstFrameRendered,
          resolvedUrl: 'https://example.com/video.mp4',
          initialPosition: const Duration(seconds: 61),
          shouldContinue: () => true,
          markReady: () => markedReady = true,
        );

        expect(fake.operations, <String>[
          'open:https://example.com/video.mp4:start=0:01:01.000000:play=false',
          'play',
          'waitUntilFirstFrameRendered',
          'seek:0:01:01.000000',
        ]);
        expect(markedReady, isTrue);
      },
    );

    test(
      'starts playback without seek when no initial position is provided',
      () async {
        final fake = _FakePlaybackFunctions();

        await const MoviePlayerSurfaceOpenCoordinator().open(
          open: fake.open,
          play: fake.play,
          seek: fake.seek,
          waitUntilFirstFrameRendered: fake.waitUntilFirstFrameRendered,
          resolvedUrl: 'https://example.com/video.mp4',
          initialPosition: null,
          shouldContinue: () => true,
          markReady: () {},
        );

        expect(fake.operations, <String>[
          'open:https://example.com/video.mp4:start=null:play=false',
          'play',
          'waitUntilFirstFrameRendered',
        ]);
      },
    );

    test('waits for initial seek readiness before exposing controls', () async {
      final fake = _FakePlaybackFunctions();
      var markedReady = false;

      await const MoviePlayerSurfaceOpenCoordinator().open(
        open: fake.open,
        play: fake.play,
        seek: fake.seek,
        waitUntilFirstFrameRendered: fake.waitUntilFirstFrameRendered,
        resolvedUrl: 'https://example.com/video.mp4',
        initialPosition: null,
        shouldContinue: () => true,
        waitUntilSeekReady: () async {
          fake.operations.add('waitUntilSeekReady');
        },
        markReady: () => markedReady = true,
      );

      expect(fake.operations, <String>[
        'open:https://example.com/video.mp4:start=null:play=false',
        'play',
        'waitUntilFirstFrameRendered',
        'waitUntilSeekReady',
      ]);
      expect(markedReady, isTrue);
    });

    test('defers requested seek until remote media is seek-ready', () async {
      final fake = _FakePlaybackFunctions();

      await const MoviePlayerSurfaceOpenCoordinator().open(
        open: fake.open,
        play: fake.play,
        seek: fake.seek,
        waitUntilFirstFrameRendered: fake.waitUntilFirstFrameRendered,
        resolvedUrl: 'https://example.com/video.mp4',
        initialPosition: const Duration(seconds: 61),
        shouldContinue: () => true,
        waitUntilSeekReady: () async {
          fake.operations.add('waitUntilSeekReady');
        },
        markReady: () {},
      );

      expect(fake.operations, <String>[
        'open:https://example.com/video.mp4:start=null:play=false',
        'play',
        'waitUntilFirstFrameRendered',
        'waitUntilSeekReady',
        'seek:0:01:01.000000',
      ]);
    });

    test(
      'stops before follow-up actions when request is no longer current',
      () async {
        final fake = _FakePlaybackFunctions();
        var shouldContinue = true;
        var markedReady = false;
        fake.onAfterOpen = () {
          shouldContinue = false;
        };

        await const MoviePlayerSurfaceOpenCoordinator().open(
          open: fake.open,
          play: fake.play,
          seek: fake.seek,
          waitUntilFirstFrameRendered: fake.waitUntilFirstFrameRendered,
          resolvedUrl: 'https://example.com/video.mp4',
          initialPosition: const Duration(seconds: 12),
          shouldContinue: () => shouldContinue,
          markReady: () => markedReady = true,
        );

        expect(fake.operations, <String>[
          'open:https://example.com/video.mp4:start=0:00:12.000000:play=false',
        ]);
        expect(markedReady, isFalse);
      },
    );

    test(
      'stops before readiness when request becomes stale after first frame',
      () async {
        final fake = _FakePlaybackFunctions();
        var shouldContinue = true;
        var markedReady = false;
        fake.onAfterWaitUntilFirstFrameRendered = () {
          shouldContinue = false;
        };

        await const MoviePlayerSurfaceOpenCoordinator().open(
          open: fake.open,
          play: fake.play,
          seek: fake.seek,
          waitUntilFirstFrameRendered: fake.waitUntilFirstFrameRendered,
          resolvedUrl: 'https://example.com/video.mp4',
          initialPosition: const Duration(seconds: 12),
          shouldContinue: () => shouldContinue,
          markReady: () => markedReady = true,
        );

        expect(fake.operations, <String>[
          'open:https://example.com/video.mp4:start=0:00:12.000000:play=false',
          'play',
          'waitUntilFirstFrameRendered',
        ]);
        expect(markedReady, isFalse);
      },
    );
  });

  group('MoviePlayerSurfaceSubtitleCoordinator', () {
    test('applies external subtitle data and returns the selected id',
        () async {
      final fake = _FakePlaybackFunctions();
      const subtitleText = '1\n00:00:01,000 --> 00:00:02,000\nhello\n';

      final result =
          await const MoviePlayerSurfaceSubtitleCoordinator().applySelection(
        setSubtitleTrack: fake.setSubtitleTrack,
        selectedOption: const MoviePlayerSubtitleOption(
          subtitleId: 501,
          label: 'ABC-001.zh.srt',
          resolvedUrl: 'https://example.com/subtitles/501.srt',
          title: 'ABC-001.zh.srt',
        ),
        loadSubtitleText: (_) async => subtitleText,
        onError: () {},
      );

      expect(result, 501);
      expect(
        fake.operations,
        contains(
          'subtitle:$subtitleText:title=ABC-001.zh.srt:language=null:uri=false:data=true',
        ),
      );
    });

    test('disables subtitles when null is selected', () async {
      final fake = _FakePlaybackFunctions();

      final result =
          await const MoviePlayerSurfaceSubtitleCoordinator().applySelection(
        setSubtitleTrack: fake.setSubtitleTrack,
        selectedOption: null,
        loadSubtitleText: (_) async => throw UnimplementedError(),
        onError: () {},
      );

      expect(result, isNull);
      expect(fake.operations, <String>[
        'subtitle:no:title=null:language=null:uri=false:data=false',
      ]);
    });

    test(
      'falls back to no subtitle and emits error when subtitle load fails',
      () async {
        final fake = _FakePlaybackFunctions()
          ..failNextSubtitleSelection = true;
        var didError = false;

        final result =
            await const MoviePlayerSurfaceSubtitleCoordinator().applySelection(
          setSubtitleTrack: fake.setSubtitleTrack,
          selectedOption: const MoviePlayerSubtitleOption(
            subtitleId: 501,
            label: 'ABC-001.zh.srt',
            resolvedUrl: 'https://example.com/subtitles/501.srt',
          ),
          loadSubtitleText: (_) async =>
              '1\n00:00:01,000 --> 00:00:02,000\nhello\n',
          onError: () => didError = true,
        );

        expect(result, isNull);
        expect(didError, isTrue);
        expect(fake.operations, <String>[
          'subtitle:1\n00:00:01,000 --> 00:00:02,000\nhello\n:title=null:language=null:uri=false:data=true',
          'subtitle:no:title=null:language=null:uri=false:data=false',
        ]);
      },
    );

    test(
      'falls back to no subtitle and emits error when subtitle text load fails',
      () async {
        final fake = _FakePlaybackFunctions();
        var didError = false;

        final result =
            await const MoviePlayerSurfaceSubtitleCoordinator().applySelection(
          setSubtitleTrack: fake.setSubtitleTrack,
          selectedOption: const MoviePlayerSubtitleOption(
            subtitleId: 501,
            label: 'ABC-001.zh.srt',
            resolvedUrl: 'https://example.com/subtitles/501.srt',
          ),
          loadSubtitleText: (_) async => throw const FormatException('bad'),
          onError: () => didError = true,
        );

        expect(result, isNull);
        expect(didError, isTrue);
        expect(fake.operations, <String>[
          'subtitle:no:title=null:language=null:uri=false:data=false',
        ]);
      },
    );
  });
}

class _FakePlaybackFunctions {
  final List<String> operations = <String>[];
  VoidCallback? onAfterOpen;
  VoidCallback? onAfterWaitUntilFirstFrameRendered;
  bool failNextSubtitleSelection = false;

  Future<void> open(
    String resolvedUrl, {
    required Duration? startPosition,
    required bool play,
  }) async {
    operations.add('open:$resolvedUrl:start=$startPosition:play=$play');
    onAfterOpen?.call();
  }

  Future<void> play() async {
    operations.add('play');
  }

  Future<void> seek(Duration position) async {
    operations.add('seek:$position');
  }

  Future<void> waitUntilFirstFrameRendered() async {
    operations.add('waitUntilFirstFrameRendered');
    onAfterWaitUntilFirstFrameRendered?.call();
  }

  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    operations.add(
      'subtitle:${track.id}:title=${track.title}:language=${track.language}:uri=${track.uri}:data=${track.data}',
    );
    if (failNextSubtitleSelection && (track.uri || track.data)) {
      failNextSubtitleSelection = false;
      throw StateError('subtitle failure');
    }
  }
}
