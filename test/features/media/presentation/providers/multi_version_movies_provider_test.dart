import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/presentation/providers/multi_version_movies_provider.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore session;
  late TestApiBundle bundle;
  late ProviderContainer container;
  setUp(() async {
    session = SessionStore.inMemory();
    await session.saveBaseUrl('https://api.example.com');
    await session.saveTokens(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime(2030),
    );
    bundle = await createTestApiBundle(session);
    container = ProviderContainer(overrides: bundle.riverpodOverrides());
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/media',
      body: page([]),
    );
  });
  tearDown(() {
    container.dispose();
    bundle.dispose();
    session.dispose();
  });

  test(
    'paginates by movie and resets pagination after removing a group',
    () async {
      final provider = multiVersionMoviesProvider(
        includeVr: true,
        includeFc2: true,
        includeProcessed: true,
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        body: page([
          group('A', [1, 2]),
        ], total: 3),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        body: page(
          [
            group('B', [3, 4]),
          ],
          total: 3,
          number: 2,
        ),
      );
      container.listen(provider, (_, __) {});
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);
      await container.read(provider.notifier).loadMore();
      expect(
        container.read(provider).requireValue.items.map((g) => g.movieNumber),
        ['A', 'B'],
      );
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/media/1',
        statusCode: 204,
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        body: page([
          group('B', [3, 4]),
        ], total: 2),
      );
      await notifier.deleteVersion(
        container.read(provider).requireValue.items.first.mediaItems.first,
      );
      expect(container.read(provider).requireValue.currentPage, 1);
      expect(container.read(provider).requireValue.total, 2);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        body: page(
          [
            group('C', [5, 6]),
          ],
          total: 2,
          number: 2,
        ),
      );
      await container.read(provider.notifier).loadMore();
      expect(
        container.read(provider).requireValue.items.map((g) => g.movieNumber),
        ['B', 'C'],
      );
      final requests = bundle.adapter.requests
          .where((r) => r.path == '/media/multi-version-movies')
          .toList();
      expect(requests.map((r) => r.uri.queryParameters['page']), [
        '1',
        '2',
        '1',
        '2',
      ]);
      expect(requests.first.uri.queryParameters.containsKey('kind'), isFalse);
      expect(
        requests.every(
          (r) =>
              r.uri.queryParameters['include_vr'] == 'true' &&
              r.uri.queryParameters['include_fc2'] == 'true' &&
              r.uri.queryParameters['include_processed'] == 'true',
        ),
        isTrue,
      );
    },
  );

  test(
    'deleting one version updates the group before silent refresh',
    () async {
      final provider = multiVersionMoviesProvider(includeProcessed: true);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        body: page([
          group('A', [1, 2, 3], isProcessed: true),
        ]),
      );
      container.listen(provider, (_, __) {});
      await container.read(provider.future);
      final item = container
          .read(provider)
          .requireValue
          .items
          .single
          .mediaItems
          .first;
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/media/1',
        statusCode: 204,
      );
      final pendingRefresh = Completer<ResponseBody>();
      final refreshStarted = Completer<void>();
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/media/multi-version-movies',
        responder: (_, __) {
          refreshStarted.complete();
          return pendingRefresh.future;
        },
      );
      final deletion = container.read(provider.notifier).deleteVersion(item);
      await refreshStarted.future;
      final state = container.read(provider);
      expect(state.hasValue, isTrue);
      expect(state.isLoading, isFalse);
      final groupState = state.requireValue.items.single;
      expect(groupState.mediaCount, 2);
      expect(groupState.mediaItems.map((item) => item.id), [2, 3]);
      expect(groupState.isProcessed, isFalse);
      pendingRefresh.complete(
        _responseBody(
          page([
            group('A', [2, 3]),
          ]),
        ),
      );
      await deletion;
      expect(container.read(provider).requireValue.items.single.mediaCount, 2);
    },
  );

  test(
    'failed deletion keeps the existing versions and does not reload',
    () async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        body: page([
          group('A', [1, 2]),
        ]),
      );
      container.listen(multiVersionMoviesProvider(), (_, __) {});
      await container.read(multiVersionMoviesProvider().future);
      final before = container.read(multiVersionMoviesProvider()).requireValue;
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/media/1',
        statusCode: 503,
        body: {
          'error': {'code': 'provider_unavailable', 'message': '存储暂不可用'},
        },
      );
      await expectLater(
        container
            .read(multiVersionMoviesProvider().notifier)
            .deleteVersion(before.items.first.mediaItems.first),
        throwsA(anything),
      );
      expect(
        container.read(multiVersionMoviesProvider()).requireValue,
        same(before),
      );
      expect(bundle.adapter.hitCount('GET', '/media/multi-version-movies'), 1);
    },
  );

  test('an old refresh cannot restore a version after deletion', () async {
    final before = page([
      group('A', [1, 2]),
    ]);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/multi-version-movies',
      body: before,
    );
    container.listen(multiVersionMoviesProvider(), (_, __) {});
    await container.read(multiVersionMoviesProvider().future);
    final notifier = container.read(multiVersionMoviesProvider().notifier);
    final item = container
        .read(multiVersionMoviesProvider())
        .requireValue
        .items
        .first
        .mediaItems
        .first;
    final pending = Completer<ResponseBody>();
    final started = Completer<void>();
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/media/multi-version-movies',
      responder: (_, __) {
        started.complete();
        return pending.future;
      },
    );
    final refresh = notifier.refresh();
    await started.future;
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/media/1',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/multi-version-movies',
      body: page([]),
    );
    final deletion = notifier.deleteVersion(item);
    expect(bundle.adapter.hitCount('DELETE', '/media/1'), 0);
    pending.complete(
      ResponseBody.fromString(
        jsonEncode(before),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    await refresh;
    await deletion;
    expect(
      container.read(multiVersionMoviesProvider()).requireValue.items,
      isEmpty,
    );
  });

  test(
    'successful deletion with failed refresh keeps the local group removal',
    () async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        body: page([
          group('A', [1, 2]),
        ]),
      );
      container.listen(multiVersionMoviesProvider(), (_, __) {});
      await container.read(multiVersionMoviesProvider().future);
      final item = container
          .read(multiVersionMoviesProvider())
          .requireValue
          .items
          .first
          .mediaItems
          .first;
      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/media/1',
        statusCode: 204,
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        statusCode: 503,
        body: {
          'error': {'message': '暂不可用'},
        },
      );
      await container
          .read(multiVersionMoviesProvider().notifier)
          .deleteVersion(item);
      final state = container.read(multiVersionMoviesProvider());
      expect(state.hasError, isFalse);
      expect(state.requireValue.items, isEmpty);
      expect(state.requireValue.total, 0);
    },
  );

  test('mark removes a group without collapsing loaded pages', () async {
    final provider = multiVersionMoviesProvider();
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/multi-version-movies',
      body: page([
        group('A', [1, 2]),
        group('B', [3, 4]),
      ], total: 3),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/multi-version-movies',
      body: page(
        [
          group('C', [5, 6]),
        ],
        total: 3,
        number: 2,
      ),
    );
    container.listen(provider, (_, __) {});
    await container.read(provider.future);
    final notifier = container.read(provider.notifier);
    await notifier.loadMore();
    final pending = container.read(provider).requireValue.items.first;
    final getCount = bundle.adapter.hitCount(
      'GET',
      '/media/multi-version-movies',
    );

    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/media/multi-version-movies/A/processed',
      statusCode: 204,
      body: null,
    );
    await notifier.markProcessed(pending);

    final state = container.read(provider).requireValue;
    expect(
      bundle.adapter.hitCount('GET', '/media/multi-version-movies'),
      getCount,
    );
    expect(state.currentPage, 2);
    expect(state.items.map((group) => group.movieNumber), ['B', 'C']);
    expect(state.total, 2);
    expect(
      bundle.adapter.requests
          .firstWhere((request) => request.method == 'PUT')
          .body,
      {
        'media_ids': [1, 2],
      },
    );
  });

  test(
    'mark and clear patch a loaded group without replacing later pages',
    () async {
      final provider = multiVersionMoviesProvider(includeProcessed: true);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        body: page([
          group('B', [3, 4]),
          group('C', [5, 6]),
        ], total: 3),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        body: page(
          [
            group('D', [7, 8]),
          ],
          total: 3,
          number: 2,
        ),
      );
      container.listen(provider, (_, __) {});
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);
      await notifier.loadMore();
      final pendingGroup = container.read(provider).requireValue.items.first;

      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/media/multi-version-movies/B/processed',
        statusCode: 204,
        body: null,
      );
      final getCount = bundle.adapter.hitCount(
        'GET',
        '/media/multi-version-movies',
      );
      await notifier.markProcessed(pendingGroup);
      final marked = container.read(provider).requireValue;
      expect(marked.items.map((group) => group.movieNumber), ['B', 'C', 'D']);
      expect(marked.currentPage, 2);
      expect(marked.items.first.isProcessed, isTrue);
      expect(
        bundle.adapter.hitCount('GET', '/media/multi-version-movies'),
        getCount,
      );
      final processedGroup = marked.items.first;

      bundle.adapter.enqueueJson(
        method: 'DELETE',
        path: '/media/multi-version-movies/B/processed',
        statusCode: 204,
        body: null,
      );
      await notifier.clearProcessed(processedGroup);
      final cleared = container.read(provider).requireValue;
      expect(cleared.items.map((group) => group.movieNumber), ['B', 'C', 'D']);
      expect(cleared.currentPage, 2);
      expect(cleared.items.first.isProcessed, isFalse);
      expect(
        bundle.adapter.hitCount('GET', '/media/multi-version-movies'),
        getCount,
      );
    },
  );
}

Map<String, dynamic> page(List<dynamic> items, {int? total, int number = 1}) =>
    {
      'items': items,
      'total': total ?? items.length,
      'page': number,
      'page_size': 20,
    };
Map<String, dynamic> group(
  String number,
  List<int> ids, {
  bool isProcessed = false,
}) => {
  'movie_number': number,
  'media_count': ids.length,
  'is_processed': isProcessed,
  'media_items': ids
      .map(
        (id) => {
          'id': id,
          'kind': 'jav',
          'movie_number': number,
          'file_name': '$id.mp4',
          'valid': true,
        },
      )
      .toList(),
};

ResponseBody _responseBody(Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
