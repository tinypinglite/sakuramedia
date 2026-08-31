import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/image_search/data/image_search_target.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_scope.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const scope = ImageSearchScope('desktop:image-search:test');
  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late ProviderContainer container;
  late ProviderSubscription<ImageSearchState> subscription;
  late ImageSearch notifier;
  var containerDisposed = false;

  ImageSearchState readState() => container.read(imageSearchProvider(scope));

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    container = ProviderContainer(overrides: bundle.riverpodOverrides());
    subscription = container.listen(
      imageSearchProvider(scope),
      (_, __) {},
      fireImmediately: true,
    );
    notifier = container.read(imageSearchProvider(scope).notifier);
  });

  tearDown(() {
    if (!containerDisposed) {
      subscription.close();
      container.dispose();
    }
    bundle.dispose();
  });

  test('search populates items and next cursor', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: _sessionBody(nextCursor: 'cursor-1', thumbnailId: 123),
    );

    _setSource(notifier);
    await notifier.search();

    expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 1);
    expect(readState().errorMessage, isNull);
    expect(readState().items.map((item) => item.thumbnailId), contains(123));
    expect(readState().nextCursor, 'cursor-1');
  });

  test('text source creates a text search session', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/text-sessions',
      body: _sessionBody(nextCursor: null, thumbnailId: 123),
    );

    notifier.setTextSource('白色连衣裙');
    await notifier.search();

    expect(readState().inputKind, ImageSearchInputKind.text);
    expect(readState().items.single.thumbnailId, 123);
    final formData = bundle.adapter.requests.single.body as FormData;
    expect(Map<String, String>.fromEntries(formData.fields)['text'], '白色连衣裙');
  });

  test('input mode can start as text and switch without a stale source', () {
    notifier.initialize(
      ImageSearchCurrentMovieScope.all,
      initialInputKind: ImageSearchInputKind.text,
    );

    expect(readState().inputKind, ImageSearchInputKind.text);
    expect(readState().hasSource, isFalse);

    notifier.setTextSource('海边');
    notifier.selectInputKind(ImageSearchInputKind.image);

    expect(readState().inputKind, ImageSearchInputKind.image);
    expect(readState().textQuery, isNull);
    expect(readState().hasSource, isFalse);
  });

  test('plot target uses dedicated paths for search and pagination', () async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/plot-sessions',
      body: _plotSessionBody(nextCursor: 'plot-cursor-1', plotImageId: 101),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/image-search/plot-sessions/plot-session-1/results',
      body: _plotSessionBody(plotImageId: 102),
    );

    _setSource(notifier);
    await notifier.search(
      filter: const ImageSearchFilterState(
        searchTarget: ImageSearchTarget.plot,
      ),
    );
    notifier.updateFilter(const ImageSearchFilterState());
    await notifier.loadMore();

    expect(bundle.adapter.requests.map((request) => request.path), <String>[
      '/image-search/plot-sessions',
      '/image-search/plot-sessions/plot-session-1/results',
    ]);
    expect(readState().items.map((item) => item.plotImageId), <int?>[101, 102]);
  });

  test('ensureSubscribedActorsLoaded requests all genders', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'id': 1,
            'javdb_id': 'ActorA1',
            'name': '三上悠亚',
            'alias_name': '三上悠亚',
            'profile_image': null,
            'is_subscribed': true,
          },
        ],
        'page': 1,
        'page_size': 200,
        'total': 1,
      },
    );

    await notifier.ensureSubscribedActorsLoaded();

    expect(readState().subscribedActors.single.id, 1);
    final request = bundle.adapter.requests.single;
    expect(request.path, '/actors');
    expect(request.uri.queryParameters['subscription_status'], 'subscribed');
    expect(request.uri.queryParameters['gender'], 'all');
    expect(request.uri.queryParameters['page_size'], '200');
  });

  test('actor loading failure keeps a retryable error state', () async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      statusCode: 500,
      body: const <String, dynamic>{},
    );

    await notifier.ensureSubscribedActorsLoaded();

    expect(readState().isLoadingSubscribedActors, isFalse);
    expect(readState().subscribedActors, isEmpty);
    expect(readState().subscribedActorsErrorMessage, '加载已订阅女优失败');
  });

  test(
    'search failure clears the session and exposes the stable message',
    () async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        statusCode: 500,
        body: const <String, dynamic>{},
      );

      _setSource(notifier);
      await notifier.search();

      expect(readState().isSearching, isFalse);
      expect(readState().sessionId, isNull);
      expect(readState().items, isEmpty);
      expect(readState().errorMessage, '以图搜图失败，请稍后重试');
    },
  );

  test(
    'space mismatch tells the user to rebuild the image-search index',
    () async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        statusCode: 409,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'image_search_index_rebuild_required',
            'message': 'Image search index must be rebuilt',
          },
        },
      );

      _setSource(notifier);
      await notifier.search();

      expect(readState().errorMessage, '嵌入空间已变更，请先重建图搜索索引');
      expect(readState().sessionId, isNull);
    },
  );

  test(
    'loadMore stops pagination when backend returns repeated next cursor',
    () async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: _sessionBody(nextCursor: 'cursor-1'),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/image-search/sessions/session-1/results',
        body: _sessionBody(nextCursor: 'cursor-1'),
      );

      _setSource(notifier);
      await notifier.search();
      await notifier.loadMore();
      await notifier.loadMore();

      expect(
        bundle.adapter.hitCount(
          'GET',
          '/image-search/sessions/session-1/results',
        ),
        1,
      );
      expect(readState().nextCursor, isNull);
      expect(readState().hasMore, isFalse);
    },
  );

  test(
    'loadMore failure preserves existing results and cursor for retry',
    () async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: _sessionBody(nextCursor: 'cursor-1', thumbnailId: 1),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/image-search/sessions/session-1/results',
        statusCode: 500,
        body: const <String, dynamic>{},
      );

      _setSource(notifier);
      await notifier.search();
      await notifier.loadMore();

      expect(readState().items.map((item) => item.thumbnailId), <int>[1]);
      expect(readState().nextCursor, 'cursor-1');
      expect(readState().isLoadingMore, isFalse);
      expect(readState().errorMessage, '加载更多失败，请稍后重试');
    },
  );

  test(
    'actor filter resolves movie ids and filters current movie results',
    () async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors/7/movie-ids',
        body: <int>[22, 11, 22],
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: <String, dynamic>{
          ..._sessionBody(nextCursor: null),
          'items': <Map<String, dynamic>>[
            _itemBody(thumbnailId: 1, movieNumber: 'ABC-001'),
            _itemBody(thumbnailId: 2, movieNumber: 'ABC-002'),
          ],
        },
      );
      const actor = ActorListItemDto(
        id: 7,
        javdbId: 'actor-7',
        name: '女优',
        aliasName: '',
        profileImage: null,
        isSubscribed: true,
      );

      _setSource(notifier);
      await notifier.search(
        filter: const ImageSearchFilterState(
          currentMovieScope: ImageSearchCurrentMovieScope.onlyCurrent,
          actorFilterMode: ImageSearchActorFilterMode.includeSelected,
          selectedActors: <ActorListItemDto>[actor],
        ),
        currentMovieNumber: ' ABC-001 ',
      );

      expect(readState().errorMessage, isNull);
      expect(readState().items.map((item) => item.thumbnailId), <int>[1]);
      expect(bundle.adapter.requests.map((request) => request.path), <String>[
        '/actors/7/movie-ids',
        '/image-search/sessions',
      ]);
    },
  );

  test(
    'different route scopes keep source, filters and results isolated',
    () async {
      const otherScope = ImageSearchScope('mobile:image-search:test');
      final otherSubscription = container.listen(
        imageSearchProvider(otherScope),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(otherSubscription.close);

      notifier.initialize(ImageSearchCurrentMovieScope.onlyCurrent);
      _setSource(notifier);

      final otherState = container.read(imageSearchProvider(otherScope));
      expect(readState().hasSource, isTrue);
      expect(
        readState().filterState.currentMovieScope,
        ImageSearchCurrentMovieScope.onlyCurrent,
      );
      expect(otherState.hasSource, isFalse);
      expect(
        otherState.filterState.currentMovieScope,
        ImageSearchCurrentMovieScope.all,
      );
    },
  );

  test('replacing source discards a delayed search response', () async {
    final response = Completer<ResponseBody>();
    bundle.adapter.enqueueResponder(
      method: 'POST',
      path: '/image-search/sessions',
      responder: (_, __) => response.future,
    );
    _setSource(notifier);
    final searchFuture = notifier.search();
    await _waitForRequest(bundle, 'POST', '/image-search/sessions');

    notifier.setSource(
      fileBytes: Uint8List.fromList(const <int>[9, 8, 7]),
      fileName: 'replacement.png',
      mimeType: 'image/png',
    );
    response.complete(_jsonResponse(_sessionBody(thumbnailId: 999)));
    await searchFuture;

    expect(readState().fileName, 'replacement.png');
    expect(readState().items, isEmpty);
    expect(readState().sessionId, isNull);
    expect(readState().isSearching, isFalse);
  });

  test('container disposal ignores a delayed response', () async {
    final response = Completer<ResponseBody>();
    bundle.adapter.enqueueResponder(
      method: 'POST',
      path: '/image-search/sessions',
      responder: (_, __) => response.future,
    );
    _setSource(notifier);
    final searchFuture = notifier.search();
    await _waitForRequest(bundle, 'POST', '/image-search/sessions');

    subscription.close();
    container.dispose();
    containerDisposed = true;
    response.complete(_jsonResponse(_sessionBody(thumbnailId: 777)));

    await expectLater(searchFuture, completes);
  });
}

void _setSource(ImageSearch notifier) {
  notifier.setSource(
    fileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
    fileName: 'query.png',
    mimeType: 'image/png',
  );
}

Map<String, dynamic> _sessionBody({String? nextCursor, int? thumbnailId}) {
  return <String, dynamic>{
    'session_id': 'session-1',
    'status': 'ready',
    'page_size': 20,
    'next_cursor': nextCursor,
    'expires_at': '2026-03-08T10:10:00Z',
    'items': <Map<String, dynamic>>[
      if (thumbnailId != null) _itemBody(thumbnailId: thumbnailId),
    ],
  };
}

Map<String, dynamic> _itemBody({
  required int thumbnailId,
  String movieNumber = 'ABC-001',
}) {
  return <String, dynamic>{
    'thumbnail_id': thumbnailId,
    'media_id': 456,
    'movie_id': 789,
    'movie_number': movieNumber,
    'offset_seconds': 120,
    'score': 0.91,
    'image': <String, dynamic>{
      'id': 10,
      'origin': '/thumb-$thumbnailId.webp',
      'small': '/thumb-$thumbnailId.webp',
      'medium': '/thumb-$thumbnailId.webp',
      'large': '/thumb-$thumbnailId.webp',
    },
  };
}

Map<String, dynamic> _plotSessionBody({
  String? nextCursor,
  required int plotImageId,
}) {
  return <String, dynamic>{
    'session_id': 'plot-session-1',
    'status': 'ready',
    'page_size': 20,
    'next_cursor': nextCursor,
    'expires_at': '2026-03-08T10:10:00Z',
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'plot_image_id': plotImageId,
        'movie_id': 789,
        'movie_number': 'ABC-001',
        'score': 0.91,
        'image': <String, dynamic>{
          'id': 10,
          'origin': '/plot-$plotImageId.webp',
          'small': '/plot-$plotImageId.webp',
          'medium': '/plot-$plotImageId.webp',
          'large': '/plot-$plotImageId.webp',
        },
      },
    ],
  };
}

ResponseBody _jsonResponse(Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: const <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

Future<void> _waitForRequest(
  TestApiBundle bundle,
  String method,
  String path,
) async {
  for (var attempt = 0; attempt < 20; attempt += 1) {
    if (bundle.adapter.hitCount(method, path) > 0) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('request $method $path was not issued');
}
