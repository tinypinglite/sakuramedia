import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/external_player/data/external_player_selection.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_page.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_page_content.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('mobile page keeps its surface and renders shared content', (
    tester,
  ) async {
    _primeContentRequests(bundle);
    await _pumpPage(tester, bundle, mobile: true, settle: false);
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('mobile-movie-detail-page-surface')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('movie-detail-page')), findsOneWidget);
    expect(
      find.byKey(const Key('movie-detail-hero-overlay-title')),
      findsOneWidget,
    );
    expect(find.byType(MovieDetailErrorState), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop page uses the same content without the mobile surface', (
    tester,
  ) async {
    _primeContentRequests(bundle);
    await _pumpPage(tester, bundle, mobile: false, settle: false);
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('mobile-movie-detail-page-surface')),
      findsNothing,
    );
    expect(find.byKey(const Key('movie-detail-page')), findsOneWidget);
    expect(find.byType(MovieDetailErrorState), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('merged playback lives in the more menu', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _primeSupportingRequests(bundle);
    final movie = _movieJson()
      ..['media_items'] = <Map<String, dynamic>>[
        _mediaJson(mediaId: 10, fileName: 'movie-10.mp4'),
        _mediaJson(mediaId: 11, fileName: 'movie-11.mp4'),
      ];
    _enqueue(bundle, method: 'GET', path: '/movies/ABC-001', body: movie);
    await _pumpPage(tester, bundle, mobile: true, settle: false);
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('movie-detail-merge-playback-button')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('movie-detail-hero-more-actions-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-detail-hero-action-mergePlayback')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('movie-detail-hero-action-mergePlayback')),
    );
    await tester.pump();
    await _pumpFrames(tester);
    expect(
      find.byKey(const Key('movie-merge-playback-drawer')),
      findsOneWidget,
    );

    Navigator.of(
      tester.element(find.byKey(const Key('movie-merge-playback-drawer'))),
    ).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('single-media movie has no merged playback menu item', (
    tester,
  ) async {
    _primeContentRequests(bundle);
    await _pumpPage(tester, bundle, mobile: true, settle: false);
    await _pumpFrames(tester);

    await tester.tap(
      find.byKey(const Key('movie-detail-hero-more-actions-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-detail-hero-action-mergePlayback')),
      findsNothing,
    );
  });

  testWidgets('merged playback waits for external player preference', (
    tester,
  ) async {
    final preferenceGate = Completer<ExternalPlayerSelection>();
    _primeSupportingRequests(bundle);
    final movie = _movieJson()
      ..['media_items'] = <Map<String, dynamic>>[
        _mediaJson(mediaId: 10, fileName: 'movie-10.mp4'),
        _mediaJson(mediaId: 11, fileName: 'movie-11.mp4'),
      ];
    _enqueue(bundle, method: 'GET', path: '/movies/ABC-001', body: movie);
    await _pumpPage(
      tester,
      bundle,
      mobile: true,
      settle: false,
      extraOverrides: <Override>[
        externalPlayerPreferenceProvider.overrideWith(
          () => _GatedExternalPlayerPreference(preferenceGate),
        ),
      ],
    );
    await _pumpFrames(tester);

    await tester.tap(
      find.byKey(const Key('movie-detail-hero-more-actions-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-detail-hero-action-mergePlayback')),
      findsNothing,
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    preferenceGate.complete(const ExternalPlayerSelection());
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('movie-detail-hero-more-actions-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-detail-hero-action-mergePlayback')),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  });

  testWidgets('loading renders the placeholder through the shared view model', (
    tester,
  ) async {
    final detailGate = Completer<ResponseBody>();
    _primeSupportingRequests(bundle);
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/movies/ABC-001',
      responder: (_, _) => detailGate.future,
    );

    await _pumpPage(tester, bundle, mobile: true, settle: false);
    await _pumpFrames(tester);

    expect(find.byType(AppSkeletonizer), findsOneWidget);
    expect(find.byType(MovieDetailErrorState), findsNothing);

    detailGate.complete(_jsonResponse(_movieJson()));
    await _pumpFrames(tester);
    expect(find.byKey(const Key('movie-detail-page')), findsOneWidget);
  });

  testWidgets('detail failure renders the shared error state and retries', (
    tester,
  ) async {
    _primeSupportingRequests(bundle);
    _enqueue(
      bundle,
      method: 'GET',
      path: '/movies/ABC-001',
      statusCode: 500,
      body: const <String, dynamic>{'detail': 'boom'},
    );

    await _pumpPage(tester, bundle, mobile: true, settle: false);
    await _pumpFrames(tester);

    expect(find.byType(MovieDetailErrorState), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    _enqueue(
      bundle,
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieJson(),
    );
    _enqueue(
      bundle,
      method: 'GET',
      path: '/movies/ABC-001/similar',
      body: const <dynamic>[],
    );
    await tester.tap(find.text('重试'));
    await _pumpFrames(tester);

    expect(find.byType(MovieDetailErrorState), findsNothing);
    expect(find.byKey(const Key('movie-detail-page')), findsOneWidget);
  });

  testWidgets('without a review source the review action is hidden', (
    tester,
  ) async {
    _primeContentRequests(bundle);
    await _pumpPage(tester, bundle, mobile: false, settle: false);
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('movie-detail-hero-review-icon')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('movie-detail-hero-thumbnail-icon')),
      findsOneWidget,
    );
  });

  testWidgets('bound review source shows the review action', (tester) async {
    _primeContentRequests(bundle);
    await _pumpPage(
      tester,
      bundle,
      mobile: false,
      settle: false,
      extraOverrides: [reviewFeaturesEnabledProvider.overrideWithValue(true)],
    );
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('movie-detail-hero-review-icon')),
      findsOneWidget,
    );
  });

  testWidgets('stats and comment count follow their source capabilities', (
    tester,
  ) async {
    _primeContentRequests(bundle);
    await _pumpPage(
      tester,
      bundle,
      mobile: false,
      settle: false,
      extraOverrides: [
        statsFeaturesEnabledProvider.overrideWithValue(true),
        reviewFeaturesEnabledProvider.overrideWithValue(false),
      ],
    );
    await _pumpFrames(tester);

    expect(find.byKey(const Key('movie-detail-meta-heat')), findsOneWidget);
    expect(
      find.byKey(const Key('movie-detail-meta-stat-score')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-detail-meta-stat-comment_count')),
      findsNothing,
    );
  });

  testWidgets('without a stats source heat and interaction stats are hidden', (
    tester,
  ) async {
    _primeContentRequests(bundle);
    await _pumpPage(tester, bundle, mobile: false, settle: false);
    await _pumpFrames(tester);

    expect(find.byKey(const Key('movie-detail-meta-heat')), findsNothing);
    expect(find.byKey(const Key('movie-detail-meta-stat-score')), findsNothing);
  });

  testWidgets('refresh metadata action confirms and applies returned detail', (
    tester,
  ) async {
    _primeContentRequests(bundle);
    _enqueue(
      bundle,
      method: 'POST',
      path: '/movies/ABC-001/metadata-refresh',
      body: _movieJson(title: 'Refreshed movie'),
    );
    await _pumpPage(tester, bundle, mobile: false, settle: false);
    await _pumpFrames(tester);

    await tester.tap(
      find.byKey(const Key('movie-detail-hero-more-actions-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('movie-detail-hero-action-refreshMetadata')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('movie-detail-refresh-metadata-confirm')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('movie-detail-refresh-metadata-confirm')),
    );
    await _pumpFrames(tester);

    expect(
      bundle.adapter.hitCount('POST', '/movies/ABC-001/metadata-refresh'),
      1,
    );
    expect(find.text('Refreshed movie'), findsWidgets);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  TestApiBundle bundle, {
  required bool mobile,
  required bool settle,
  List<Override> extraOverrides = const <Override>[],
}) {
  return pumpPreviewApp(
    tester,
    home: MovieDetailPage(movieNumber: 'ABC-001', mobile: mobile),
    size: mobile ? const Size(390, 844) : const Size(1100, 760),
    theme: mobile
        ? buildSakuraMobileThemeData()
        : buildSakuraDesktopThemeData(),
    platform: mobile ? TargetPlatform.android : TargetPlatform.macOS,
    appPlatform: mobile ? AppPlatform.mobile : AppPlatform.desktop,
    bundle: bundle,
    settle: settle,
    extraOverrides: extraOverrides,
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _primeContentRequests(TestApiBundle bundle) {
  _primeSupportingRequests(bundle);
  _enqueue(bundle, method: 'GET', path: '/movies/ABC-001', body: _movieJson());
}

void _primeSupportingRequests(TestApiBundle bundle) {
  _enqueue(
    bundle,
    method: 'GET',
    path: '/movies/ABC-001/similar',
    body: const <dynamic>[],
  );
  _enqueue(
    bundle,
    method: 'GET',
    path: '/movies/ABC-001/subtitles',
    body: <String, dynamic>{
      'movie_number': 'ABC-001',
      'items': const <dynamic>[],
    },
  );
  _enqueue(
    bundle,
    method: 'GET',
    path: '/movies/ABC-001/collection-status',
    body: <String, dynamic>{'movie_number': 'ABC-001', 'is_collection': false},
  );
  _enqueue(
    bundle,
    method: 'GET',
    path: '/movies/ABC-001/rating',
    body: <String, dynamic>{
      'movie_number': 'ABC-001',
      'rated': false,
      'values': const <dynamic>[],
    },
  );
  _enqueue(
    bundle,
    method: 'GET',
    path: '/movie-rating-dimensions',
    body: const <dynamic>[],
  );
}

void _enqueue(
  TestApiBundle bundle, {
  required String method,
  required String path,
  int statusCode = 200,
  Object? body,
}) {
  bundle.adapter.enqueueResponder(
    method: method,
    path: path,
    responder: (_, _) async => _jsonResponse(
      body ?? const <String, dynamic>{},
      statusCode: statusCode,
    ),
  );
}

ResponseBody _jsonResponse(Object body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: const <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> _movieJson({String title = 'Movie 1'}) {
  return <String, dynamic>{
    'id': 5,
    'movie_number': 'ABC-001',
    'title': title,
    'release_date': '2024-01-02',
    'duration_minutes': 120,
    'is_collection': false,
    'is_subscribed': true,
    'can_play': true,
    'summary': '',
    'heat': 123,
    'stats_source': 'legacy:host',
    'interaction_stats': <String, dynamic>{'score': 4.5, 'comment_count': 3},
    'actors': const <Map<String, dynamic>>[],
    'tags': const <Map<String, dynamic>>[],
    'plot_images': const <Map<String, dynamic>>[],
    'media_items': <Map<String, dynamic>>[
      <String, dynamic>{
        'media_id': 10,
        'file_name': 'movie-10.mp4',
        'file_size_bytes': 1024,
        'duration_seconds': 60,
        'play_url': 'https://cdn.example.com/movie-10.mp4',
        'valid': true,
        'points': const <Map<String, dynamic>>[],
      },
    ],
    'playlists': const <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _mediaJson({
  required int mediaId,
  required String fileName,
}) {
  return <String, dynamic>{
    'media_id': mediaId,
    'file_name': fileName,
    'file_size_bytes': 1024,
    'duration_seconds': 60,
    'play_url': 'https://cdn.example.com/$fileName',
    'valid': true,
    'library_id': 7,
    'library_name': '主媒体库',
    'points': const <Map<String, dynamic>>[],
  };
}

class _GatedExternalPlayerPreference extends ExternalPlayerPreference {
  _GatedExternalPlayerPreference(this.gate);

  final Completer<ExternalPlayerSelection> gate;

  @override
  Future<ExternalPlayerSelection> build() => gate.future;
}
