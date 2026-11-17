import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';

MovieMediaItemDto _media({
  int mediaId = 1,
  String playUrl = '/media/1/play/file.mp4?expires=1&signature=sig',
}) {
  return MovieMediaItemDto(
    mediaId: mediaId,
    libraryId: 1,
    providerKey: 'filesystem',
    playUrl: playUrl,
    fileName: 'movie.mp4',
    resolution: '1920x1080',
    fileSizeBytes: 100,
    durationSeconds: 60,
    valid: true,
    progress: null,
    points: const <MovieMediaPointDto>[],
  );
}

void main() {
  for (final mode in ['proxy', 'redirect']) {
    testWidgets('影片入口传递 $mode 偏好，不按 provider 类型筛选', (tester) async {
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final session = SessionStore.inMemory();
      const channel = MethodChannel('sakuramedia/external_player');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      try {
        await session.saveBaseUrl('http://nas:8000');
        SharedPreferences.setMockInitialValues({
          'android.external_player.package_name': 'player',
          'external_player.playback_mode': mode,
        });
        Map? args;
        messenger.setMockMethodCallHandler(channel, (call) async {
          args = call.arguments as Map;
          return true;
        });
        late BuildContext context;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sessionStoreProvider.overrideWithValue(session)],
            child: MaterialApp(
              home: Builder(
                builder: (innerContext) {
                  context = innerContext;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        await ProviderScope.containerOf(
          context,
        ).read(externalPlayerPreferenceProvider.future);
        await launchMoviePlayback(
          context,
          movieNumber: 'TEST-001',
          positionSeconds: 30,
          movie: MovieDetailDto.fromJson({
            'movie_number': 'TEST-001',
            'media_items': [
              {
                'media_id': 1,
                'library_id': 2,
                'provider_key': 'future-provider',
                'play_url':
                    '/media/1/play/?expires=1&signature=sig&delivery=redirect',
              },
            ],
          }),
        );
        expect(args, isNotNull);
        expect(
          Uri.parse(args!['url'] as String).queryParameters['delivery'],
          mode,
        );
        expect(args!['positionMs'], 30000);
        expect(args!['playerId'], 'player');
      } finally {
        await tester.pumpWidget(const SizedBox());
        messenger.setMockMethodCallHandler(channel, null);
        session.dispose();
        debugDefaultTargetPlatformOverride = previous;
      }
    });
  }

  test('parses the provider play URL without a delivery choice', () {
    final dto = MovieMediaItemDto.fromJson(<String, dynamic>{
      'media_id': 12,
      'library_id': 3,
      'provider_key': 's3',
      'play_url': '/media/12/play/movie.mkv?expires=1&signature=sig',
      'file_name': 'movie.mkv',
      'resolution': null,
      'file_size_bytes': 100,
      'duration_seconds': 10,
      'valid': true,
      'progress': null,
      'points': <Map<String, dynamic>>[],
    });

    expect(dto.mediaId, 12);
    expect(dto.providerKey, 's3');
    expect(dto.fileName, 'movie.mkv');
    expect(dto.playUrl, contains('/media/12/play/'));
    expect(dto.resolution, isNull);
    expect(dto.hasPlayableUrl, isTrue);
  });

  test('copyWith preserves signed play URL and provider metadata', () {
    final media = _media();
    final copy = media.copyWith(points: const <MovieMediaPointDto>[]);

    expect(copy.playUrl, media.playUrl);
    expect(copy.providerKey, media.providerKey);
    expect(copy.fileName, media.fileName);
    expect(copy.libraryId, media.libraryId);
    expect(copy.points, isEmpty);
  });

  test('nullable fields can be cleared independently', () {
    final media = _media();
    final withProgress = media.copyWith(
      progress: const MovieMediaProgressDto(
        lastPositionSeconds: 120,
        lastWatchedAt: null,
      ),
    );

    expect(withProgress.copyWith().progress, isNotNull);
    expect(withProgress.copyWith(progress: null).progress, isNull);
    expect(withProgress.copyWith(providerKey: null).providerKey, isNull);
    expect(withProgress.copyWith(resolution: null).resolution, isNull);
  });

  test('parses merge playback candidates from movie detail', () {
    final detail = MovieDetailDto.fromJson(<String, dynamic>{
      'merge_playback_candidates': <Map<String, dynamic>>[
        <String, dynamic>{
          'library_id': 3,
          'library_name': 'VR',
          'provider_key': 'local',
          'segment_count': 2,
        },
      ],
    });

    expect(detail.mergePlaybackCandidates, hasLength(1));
    expect(detail.mergePlaybackCandidates.single.libraryId, 3);
    expect(detail.mergePlaybackCandidates.single.libraryName, 'VR');
    expect(detail.mergePlaybackCandidates.single.segmentCount, 2);
  });
}
