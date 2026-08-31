import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/features/movies/presentation/pages/desktop/movie_player_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_surface_controller.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dispose flushes final progress before the page state is gone', (
    tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieDetailJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/100/thumbnails',
      body: const <Map<String, dynamic>>[],
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/media/100/progress',
      body: <String, dynamic>{
        'media_id': 100,
        'last_position_seconds': 25,
        'last_watched_at': '2026-03-12T14:00:00',
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          theme: sakuraThemeData,
          home: DesktopMoviePlayerPage(
            movieNumber: 'ABC-001',
            surfaceBuilder: _surfaceBuilder,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('PUT', '/media/100/progress'), 1);
  });
}

Widget _surfaceBuilder(
  BuildContext context,
  String resolvedUrl,
  MoviePlayerSurfaceController surfaceController,
  Duration? initialPosition,
  Duration? resumePosition,
  VoidCallback onResumePromptResolved,
  ValueChanged<Duration>? onPositionChanged,
  ValueChanged<bool>? onPlayingChanged,
  MoviePlayerSubtitleState subtitleState,
  ValueChanged<int?> onSubtitleSelectionChanged,
  Future<void> Function() onSubtitleReloadRequested,
  VoidCallback onBackPressed,
  bool useTouchOptimizedControls,
) {
  return _PositionEmitter(onPositionChanged: onPositionChanged);
}

class _PositionEmitter extends StatefulWidget {
  const _PositionEmitter({required this.onPositionChanged});

  final ValueChanged<Duration>? onPositionChanged;

  @override
  State<_PositionEmitter> createState() => _PositionEmitterState();
}

class _PositionEmitterState extends State<_PositionEmitter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPositionChanged?.call(const Duration(seconds: 25));
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Map<String, dynamic> _movieDetailJson() {
  return <String, dynamic>{
    'javdb_id': 'MovieA1',
    'movie_number': 'ABC-001',
    'title': 'Movie 1',
    'cover_image': null,
    'release_date': '2026-03-08',
    'duration_minutes': 120,
    'score': 4.5,
    'watched_count': 12,
    'want_watch_count': 23,
    'comment_count': 34,
    'score_number': 45,
    'is_collection': false,
    'is_subscribed': true,
    'can_play': true,
    'summary': '',
    'plot_images': const <Map<String, dynamic>>[],
    'actors': const <Map<String, dynamic>>[],
    'tags': const <Map<String, dynamic>>[],
    'playlists': const <Map<String, dynamic>>[],
    'media_items': <Map<String, dynamic>>[
      <String, dynamic>{
        'media_id': 100,
        'library_id': 1,
        'play_url': '/files/media/movies/ABC-001/video.mp4',
        'path': '/library/main/ABC-001/video.mp4',
        'storage_mode': 'hardlink',
        'resolution': '1920x1080',
        'file_size_bytes': 1024,
        'duration_seconds': 7200,
        'special_tags': '普通',
        'valid': true,
        'progress': null,
        'points': const <Map<String, dynamic>>[],
      },
    ],
  };
}
