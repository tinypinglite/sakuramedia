import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/moments/presentation/desktop_moments_page.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
  });

  testWidgets('desktop moments page loads latest moments and shows total', (
    WidgetTester tester,
  ) async {
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:desc');

    await _pumpMomentsApp(tester, bundle: bundle, sessionStore: sessionStore);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('moments-page')), findsOneWidget);
    expect(find.byKey(const Key('moments-page-total')), findsOneWidget);
    expect(find.text('1 个时刻'), findsOneWidget);
    expect(find.text('最新'), findsOneWidget);
    expect(find.text('最早'), findsOneWidget);
    expect(find.text('ABC-001'), findsOneWidget);
    expect(find.text('02:00'), findsOneWidget);
    expect(_mediaPointsQueryValue(bundle, 0, 'sort'), 'created_at:desc');
  });

  testWidgets('desktop moments page reloads with earliest sort', (
    WidgetTester tester,
  ) async {
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:desc');
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:asc');

    await _pumpMomentsApp(tester, bundle: bundle, sessionStore: sessionStore);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('moments-sort-earliest')));
    await tester.pumpAndSettle();

    expect(_mediaPointsQueryValue(bundle, 1, 'sort'), 'created_at:asc');
  });

  testWidgets('desktop moments page opens shared preview dialog on card tap', (
    WidgetTester tester,
  ) async {
    _enqueueMomentsPageResponses(bundle, sort: 'created_at:desc');

    await _pumpMomentsApp(tester, bundle: bundle, sessionStore: sessionStore);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('moment-card-10')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('image-search-result-preview-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('相似度'), findsNothing);
    expect(find.textContaining('番号 ABC-001'), findsOneWidget);
    expect(find.textContaining('时间点 02:00'), findsOneWidget);
    expect(find.text('相似图片'), findsOneWidget);
    expect(find.text('保存到本地'), findsOneWidget);
    expect(find.text('删除标记'), findsOneWidget);
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('影片详情'), findsOneWidget);

    final previewHeroImage = tester.widget<MaskedImage>(
      find.descendant(
        of: find.byKey(const Key('image-search-result-preview-hero')),
        matching: find.byType(MaskedImage),
      ),
    );
    expect(previewHeroImage.fit, BoxFit.contain);
  });
}

Future<void> _pumpMomentsApp(
  WidgetTester tester, {
  required TestApiBundle bundle,
  required SessionStore sessionStore,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: DesktopMomentsPage()),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => const Scaffold(body: Text('player')),
      ),
      GoRoute(
        path: '/movie',
        builder: (context, state) => const Scaffold(body: Text('movie')),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ApiClient>.value(value: bundle.apiClient),
        Provider<MoviesApi>.value(value: bundle.moviesApi),
        Provider<MediaApi>(
          create: (_) => MediaApi(apiClient: bundle.apiClient),
        ),
      ],
      child: OKToast(
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    ),
  );
}

void _enqueueMomentsPageResponses(
  TestApiBundle bundle, {
  required String sort,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-points',
    body: <String, dynamic>{
      'items': [
        <String, dynamic>{
          'point_id': 10,
          'media_id': 456,
          'movie_number': 'ABC-001',
          'offset_seconds': 120,
          'created_at': '2026-03-12T10:00:00Z',
        },
      ],
      'page': 1,
      'page_size': 20,
      'total': 1,
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media/456/thumbnails',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'thumbnail_id': 1,
        'media_id': 456,
        'offset_seconds': 120,
        'image': <String, dynamic>{
          'id': 10,
          'origin': '/thumb-1.webp',
          'small': '/thumb-1.webp',
          'medium': '/thumb-1.webp',
          'large': '/thumb-1.webp',
        },
      },
    ],
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/movies/ABC-001',
    body: <String, dynamic>{
      'javdb_id': 'MovieA1',
      'movie_number': 'ABC-001',
      'title': 'Movie 1',
      'series_name': '',
      'cover_image': <String, dynamic>{
        'id': 1,
        'origin': '/cover.jpg',
        'small': '/cover.jpg',
        'medium': '/cover.jpg',
        'large': '/cover.jpg',
      },
      'release_date': null,
      'duration_minutes': 0,
      'score': 0,
      'watched_count': 0,
      'want_watch_count': 0,
      'comment_count': 0,
      'score_number': 0,
      'is_collection': false,
      'is_subscribed': false,
      'can_play': true,
      'summary': '',
      'thin_cover_image': null,
      'plot_images': const <Map<String, dynamic>>[],
      'actors': const <Map<String, dynamic>>[],
      'tags': const <Map<String, dynamic>>[],
      'media_items': [
        <String, dynamic>{
          'media_id': 456,
          'library_id': 1,
          'play_url': '/files/media/movies/ABC-001/video.mp4',
          'path': '/library/main/ABC-001/video.mp4',
          'storage_mode': 'hardlink',
          'resolution': '1920x1080',
          'file_size_bytes': 1073741824,
          'duration_seconds': 7200,
          'special_tags': '普通',
          'valid': true,
          'progress': null,
          'points': [
            <String, dynamic>{'point_id': 10, 'offset_seconds': 120},
          ],
        },
      ],
    },
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media/456/points',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'point_id': 10,
        'media_id': 456,
        'offset_seconds': 120,
        'created_at': '2026-03-12T10:00:00Z',
      },
    ],
  );
  expect(sort, isNotEmpty);
}

String? _mediaPointsQueryValue(
  TestApiBundle bundle,
  int requestIndex,
  String key,
) {
  final requests = bundle.adapter.requests
      .where((request) => request.path == '/media-points')
      .toList(growable: false);
  if (requestIndex >= requests.length) {
    return null;
  }
  return requests[requestIndex].uri.queryParameters[key];
}
