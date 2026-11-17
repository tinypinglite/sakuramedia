import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/image_search/presentation/pages/shared/image_search_content.dart';
import 'package:sakuramedia/theme.dart';

import '../../../support/pump_with_providers.dart';
import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore session;
  late TestApiBundle bundle;
  late RiverpodPageCache pageCache;

  setUp(() async {
    session = SessionStore.inMemory();
    await session.saveBaseUrl('https://api.example.com');
    await session.saveTokens(
      accessToken: 'test',
      refreshToken: 'test',
      expiresAt: DateTime(2099),
    );
    bundle = await createTestApiBundle(session);
    pageCache = RiverpodPageCache();
    _enqueueSession(bundle, '/image-search/sessions');
  });

  tearDown(() {
    bundle.dispose();
    session.dispose();
    pageCache.dispose();
  });

  testWidgets('desktop filter edits are applied and reset explicitly', (
    tester,
  ) async {
    await _pumpImageSearch(tester, bundle, pageCache);
    expect(
      bundle.adapter.hitCount('POST', '/image-search/sessions'),
      1,
      reason: bundle.adapter.requests
          .map((request) => '${request.method} ${request.path}')
          .join(', '),
    );

    await tester.tap(
      find.byKey(const Key('desktop-image-search-toggle-filter')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('desktop-image-search-filter-panel')),
      findsOneWidget,
    );

    await tester.tap(find.text('剧情图'));
    await tester.pumpAndSettle();
    expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 1);
    expect(bundle.adapter.hitCount('POST', '/image-search/plot-sessions'), 0);

    await tester.tap(find.byKey(const Key('image-search-filter-apply')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('desktop-image-search-filter-panel')),
      findsNothing,
    );
    expect(bundle.adapter.hitCount('POST', '/image-search/plot-sessions'), 1);
    expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 1);

    await tester.tap(
      find.byKey(const Key('desktop-image-search-toggle-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('image-search-filter-reset')));
    await tester.pumpAndSettle();
    expect(bundle.adapter.hitCount('POST', '/image-search/plot-sessions'), 1);

    await tester.tap(find.byKey(const Key('image-search-filter-apply')));
    await tester.pumpAndSettle();
    expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 2);
    expect(bundle.adapter.hitCount('POST', '/image-search/plot-sessions'), 1);
  });

  testWidgets('actor selection stays in the draft until apply', (tester) async {
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/actors',
      responder: (_, _) async => _jsonResponse(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'name': '演员 A',
            'alias_name': '演员 A',
            'profile_image': null,
            'is_subscribed': true,
          },
        ],
        'page': 1,
        'page_size': 200,
        'total': 1,
      }),
    );
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/actors/1/movie-ids',
      responder: (_, _) async => _jsonResponse(<int>[789]),
    );
    _enqueueSession(bundle, '/image-search/sessions');

    await _pumpImageSearch(tester, bundle, pageCache);
    expect(
      bundle.adapter.hitCount('POST', '/image-search/sessions'),
      1,
      reason: bundle.adapter.requests
          .map((request) => '${request.method} ${request.path}')
          .join(', '),
    );

    await tester.tap(
      find.byKey(const Key('desktop-image-search-toggle-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('仅包含所选'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('image-search-filter-select-actors')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('image-search-actor-picker-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('image-search-actor-option-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('image-search-actor-close-button')));
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 1);
    expect(find.byKey(const Key('image-search-filter-apply')), findsOneWidget);

    await tester.tap(find.byKey(const Key('image-search-filter-apply')));
    await tester.pumpAndSettle();
    expect(bundle.adapter.hitCount('GET', '/actors/1/movie-ids'), 1);
    expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 2);
    expect(
      find.byKey(const Key('desktop-image-search-filter-panel')),
      findsNothing,
    );
  });
}

Future<void> _pumpImageSearch(
  WidgetTester tester,
  TestApiBundle bundle,
  RiverpodPageCache pageCache,
) async {
  await pumpWithProviders(
    tester,
    home: ImageSearchContent(
      surfaceColor: Colors.transparent,
      fallbackPath: '/desktop/image-search',
      initialFileName: 'query.png',
      initialFileBytes: Uint8List.fromList(const <int>[1, 2, 3]),
      initialMimeType: 'image/png',
      imagePicker: (_) async => null,
    ),
    bundle: bundle,
    overrides: [riverpodPageCacheProvider.overrideWithValue(pageCache)],
    theme: buildSakuraDesktopThemeData(),
    physicalSize: const Size(1100, 760),
  );
  await tester.pumpAndSettle();
}

void _enqueueSession(TestApiBundle bundle, String path) {
  bundle.adapter.enqueueResponder(
    method: 'POST',
    path: path,
    responder: (_, _) async => _jsonResponse(<String, dynamic>{
      'session_id': 'session-${bundle.adapter.hitCount('POST', path)}',
      'status': 'ready',
      'page_size': 20,
      'next_cursor': null,
      'expires_at': '2099-01-01T00:00:00Z',
      'items': <dynamic>[],
    }),
  );
}

ResponseBody _jsonResponse(Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: const <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
