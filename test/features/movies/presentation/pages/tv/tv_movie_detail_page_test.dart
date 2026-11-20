import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/pages/tv/tv_movie_detail_page.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../support/logged_in_session_store.dart';
import '../../../../../support/preview_helpers.dart';
import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/movies/ABC-001/similar',
      body: const <dynamic>[],
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/movies/ABC-001/collection-status',
      body: <String, dynamic>{
        'movie_number': 'ABC-001',
        'is_collection': false,
      },
    );
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('TV 详情页有多个合并播放媒体库时先弹出媒体库选择', (tester) async {
    _seedMovie(bundle, libraries: const <int>[1, 2]);

    await _pumpDetail(tester, bundle);

    expect(find.text('ABC-001'), findsOneWidget);
    expect(find.text(formatAppCompactCount(123)), findsOneWidget);
    expect(find.text('合并播放'), findsOneWidget);
    await tester.tap(find.text('合并播放'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-merge-playback-library-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-merge-playback-library-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-merge-playback-library-2')),
      findsOneWidget,
    );

    // 关掉选择弹窗，避免测试里真的拉起播放器路由。
    Navigator.of(
      tester.element(
        find.byKey(const Key('movie-merge-playback-library-dialog')),
      ),
    ).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV 详情页只有一个可合并媒体库时按钮直接显示分段数', (tester) async {
    _seedMovie(bundle, libraries: const <int>[1]);

    await _pumpDetail(tester, bundle);

    expect(find.text('合并播放 · 2 段'), findsOneWidget);
    expect(
      find.byKey(const Key('movie-merge-playback-library-dialog')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV 详情页没有可合并分段时不显示合并播放按钮', (tester) async {
    _seedMovie(bundle, libraries: const <int>[1], segmentsPerLibrary: 1);

    await _pumpDetail(tester, bundle);

    expect(find.text('合并播放'), findsNothing);
    expect(find.text('合并播放 · 1 段'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV 详情页单个媒体源也显示媒体源和技术摘要', (tester) async {
    _seedMovie(bundle, libraries: const <int>[1], segmentsPerLibrary: 1);

    await _pumpDetail(tester, bundle);

    expect(find.text('媒体源'), findsOneWidget);
    expect(find.text('1 KB'), findsOneWidget);
    expect(_summaryText(tester), contains('movie-1-0.mp4'));
    expect(_summaryText(tester), contains('1080P'));
    expect(_summaryText(tester), contains('H.264'));
    expect(_summaryText(tester), contains('5.0 Mbps'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV 详情页切换媒体源更新技术摘要', (tester) async {
    _seedMovie(bundle, libraries: const <int>[1], segmentsPerLibrary: 2);

    await _pumpDetail(tester, bundle);

    expect(find.text('1 KB'), findsOneWidget);
    expect(find.text('3 KB'), findsOneWidget);
    expect(_summaryText(tester), contains('movie-1-0.mp4'));

    await tester.tap(find.text('3 KB'));
    await tester.pumpAndSettle();

    expect(_summaryText(tester), contains('movie-1-1.mp4'));
    expect(tester.takeException(), isNull);
  });
}

String _summaryText(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const Key('movie-media-tech-summary')))
      .data!;
}

Future<void> _pumpDetail(WidgetTester tester, TestApiBundle bundle) async {
  await pumpPreviewApp(
    tester,
    home: const TvMovieDetailPage(movieNumber: 'ABC-001'),
    size: const Size(1920, 1080),
    theme: buildSakuraTvThemeData(),
    platform: TargetPlatform.android,
    appPlatform: AppPlatform.tv,
    bundle: bundle,
    extraOverrides: <Override>[
      statsFeaturesEnabledProvider.overrideWithValue(true),
    ],
    settle: false,
  );
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _seedMovie(
  TestApiBundle bundle, {
  required List<int> libraries,
  int segmentsPerLibrary = 2,
}) {
  bundle.adapter.setFallbackJson(
    method: 'GET',
    path: '/movies/ABC-001',
    body: _movieJson(
      libraries: libraries,
      segmentsPerLibrary: segmentsPerLibrary,
    ),
  );
}

Map<String, dynamic> _movieJson({
  required List<int> libraries,
  required int segmentsPerLibrary,
}) {
  return <String, dynamic>{
    'id': 5,
    'movie_number': 'ABC-001',
    'title': 'Movie 1',
    'release_date': '2024-01-02',
    'duration_minutes': 120,
    'is_collection': false,
    'is_subscribed': true,
    'can_play': true,
    'summary': '',
    'heat': 123,
    'stats_source': 'legacy:host',
    'actors': const <Map<String, dynamic>>[],
    'tags': const <Map<String, dynamic>>[],
    'plot_images': const <Map<String, dynamic>>[],
    'media_items': <Map<String, dynamic>>[
      for (final libraryId in libraries)
        for (var segment = 0; segment < segmentsPerLibrary; segment++)
          <String, dynamic>{
            'media_id': libraryId * 100 + segment,
            'library_id': libraryId,
            'provider_key': 'cloud115',
            'file_name': 'movie-$libraryId-$segment.mp4',
            'file_size_bytes': 1024 * (libraryId + segment * 2),
            'resolution': '1080P',
            'duration_seconds': 600,
            'video_info': <String, dynamic>{
              'video': <String, dynamic>{
                'codec_name': 'h264',
                'bit_rate': 5000000,
                'frame_rate': 23.976,
              },
            },
            'play_url': 'https://cdn.example.com/movie-$libraryId-$segment.mp4',
            'valid': true,
            'points': const <Map<String, dynamic>>[],
          },
    ],
    'merge_playback_candidates': <Map<String, dynamic>>[
      for (final libraryId in libraries)
        <String, dynamic>{
          'library_id': libraryId,
          'library_name': '媒体库 $libraryId',
          'provider_key': 'cloud115',
          'segment_count': segmentsPerLibrary,
        },
    ],
    'playlists': const <Map<String, dynamic>>[],
  };
}
