import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clips/presentation/pages/desktop/clips_page.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/overview_clips_tab.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clip_mutation_events_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('desktop clips loads the first page and collections once', (
    tester,
  ) async {
    _enqueueInitial(bundle);

    await _pumpDesktop(tester, bundle);
    await _pumpFrames(tester);

    expect(find.byKey(const Key('clips-grid')), findsOneWidget);
    expect(find.byKey(const Key('clip-collection-card-10')), findsOneWidget);
    expect(bundle.adapter.hitCount('GET', '/media-clips'), 1);
    expect(bundle.adapter.hitCount('GET', '/clip-collections'), 1);
    expect(
      _lastRequest(bundle, '/media-clips').uri.queryParameters['sort'],
      'created_at:desc',
    );
    expect(
      _lastRequest(bundle, '/media-clips').uri.queryParameters['page_size'],
      '24',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile clips loads the first page and collections once', (
    tester,
  ) async {
    _enqueueInitial(bundle);

    await _pumpMobile(tester, bundle);
    await _pumpFrames(tester);

    expect(find.byKey(const Key('mobile-clips-grid')), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-clip-collection-card-10')),
      findsOneWidget,
    );
    expect(bundle.adapter.hitCount('GET', '/media-clips'), 1);
    expect(bundle.adapter.hitCount('GET', '/clip-collections'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile sort toggles to ascending and refetches', (tester) async {
    _enqueueInitial(bundle);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      body: _clipsPage(ids: <int>[2], total: 1),
    );

    await _pumpMobile(tester, bundle);
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('mobile-clips-sort-trigger')));
    await _pumpFrames(tester);

    expect(bundle.adapter.hitCount('GET', '/media-clips'), 2);
    expect(
      _lastRequest(bundle, '/media-clips').uri.queryParameters['sort'],
      'created_at:asc',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop single delete uses the dialog and removes the clip', (
    tester,
  ) async {
    _enqueueInitial(bundle);
    _enqueueDelete(bundle, clipId: 1);

    await _pumpDesktop(tester, bundle);
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('clip-grid-card-tap-1')));
    await _pumpFrames(tester);
    expect(find.byKey(const Key('clip-actions-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clip-action-delete')));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('clip-delete-confirm-button')));
    await _pumpFrames(tester);

    expect(bundle.adapter.hitCount('DELETE', '/media-clips/1'), 1);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DesktopClipsPage)),
    );
    expect(
      container
          .read(clipsOverviewProvider)
          .requireValue
          .paged
          .items
          .map((clip) => clip.clipId),
      <int>[2],
    );
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile single delete uses the sheet and removes the clip', (
    tester,
  ) async {
    _enqueueInitial(bundle);
    _enqueueDelete(bundle, clipId: 1);

    await _pumpMobile(tester, bundle);
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('clip-cover-card-1')));
    await _pumpFrames(tester);
    expect(find.byKey(const Key('mobile-clip-actions-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-clip-action-delete')));
    await _pumpFrames(tester);
    await tester.tap(
      find.byKey(const Key('mobile-clip-delete-confirm-button')),
    );
    await _pumpFrames(tester);

    expect(bundle.adapter.hitCount('DELETE', '/media-clips/1'), 1);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MobileOverviewClipsTab)),
    );
    expect(
      container
          .read(clipsOverviewProvider)
          .requireValue
          .paged
          .items
          .map((clip) => clip.clipId),
      <int>[2],
    );
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('clip mutation removes the clip and refreshes the collections', (
    tester,
  ) async {
    _enqueueInitial(bundle);

    await _pumpDesktop(tester, bundle);
    await _pumpFrames(tester);
    expect(bundle.adapter.hitCount('GET', '/clip-collections'), 1);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/clip-collections',
      body: _collectionsBody(ids: <int>[10]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DesktopClipsPage)),
    );
    container.read(clipMutationEventsProvider.notifier).reportDeleted(1);
    await _pumpFrames(tester);

    expect(bundle.adapter.hitCount('GET', '/clip-collections'), 2);
    expect(
      container
          .read(clipsOverviewProvider)
          .requireValue
          .paged
          .items
          .map((clip) => clip.clipId),
      <int>[2],
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDesktop(WidgetTester tester, TestApiBundle bundle) {
  return pumpPreviewApp(
    tester,
    home: const DesktopClipsPage(),
    size: const Size(1100, 760),
    theme: buildSakuraDesktopThemeData(),
    platform: TargetPlatform.macOS,
    appPlatform: AppPlatform.desktop,
    bundle: bundle,
    settle: false,
  );
}

Future<void> _pumpMobile(WidgetTester tester, TestApiBundle bundle) {
  return pumpPreviewApp(
    tester,
    home: const MobileOverviewClipsTab(),
    size: const Size(390, 844),
    theme: buildSakuraMobileThemeData(),
    platform: TargetPlatform.android,
    appPlatform: AppPlatform.mobile,
    bundle: bundle,
    settle: false,
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _enqueueInitial(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-clips',
    body: _clipsPage(ids: <int>[1, 2], total: 2),
  );
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/clip-collections',
    body: _collectionsBody(ids: <int>[10]),
  );
}

void _enqueueDelete(TestApiBundle bundle, {required int clipId}) {
  bundle.adapter.enqueueJson(
    method: 'DELETE',
    path: '/media-clips/$clipId',
    statusCode: 204,
  );
}

Map<String, dynamic> _clipsPage({required List<int> ids, required int total}) {
  return <String, dynamic>{
    'items': ids
        .map(
          (clipId) => <String, dynamic>{
            'clip_id': clipId,
            'media_id': 100 + clipId,
            'movie_number': 'ABC-${clipId.toString().padLeft(3, '0')}',
            'start_offset_seconds': 0,
            'end_offset_seconds': 10,
            'title': 'Clip $clipId',
            'duration_seconds': 10,
            'file_size_bytes': 0,
            'cover_image': null,
            'stream_url': '/media-clips/$clipId/stream',
            'created_at': null,
          },
        )
        .toList(),
    'page': 1,
    'page_size': 24,
    'total': total,
  };
}

List<Map<String, dynamic>> _collectionsBody({required List<int> ids}) {
  return ids
      .map(
        (id) => <String, dynamic>{
          'id': id,
          'name': 'Collection $id',
          'description': '',
          'clip_count': 0,
          'cover_image': null,
          'created_at': null,
          'updated_at': null,
        },
      )
      .toList();
}

dynamic _lastRequest(TestApiBundle bundle, String path) {
  return bundle.adapter.requests.lastWhere((request) => request.path == path);
}
