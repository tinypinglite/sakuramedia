import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import '../../../../support/test_api_bundle.dart';

const resultItem = ImageSearchResultItemDto(
  thumbnailId: 1,
  mediaId: 2,
  movieId: 3,
  movieNumber: 'ABC-001',
  offsetSeconds: 120,
  score: 0.93,
  image: MovieImageDto(id: 1, origin: '', small: '', medium: '', large: ''),
);

ResponseBody jsonResponse(Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: const <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

class PendingPreviewRequests {
  final Completer<ResponseBody> movieDetail = Completer<ResponseBody>();
  final Completer<ResponseBody> mediaPoints = Completer<ResponseBody>();

  void completeMovieDetail() {
    movieDetail.complete(
      jsonResponse({
        'movie_number': 'ABC-001',
        'title': '测试影片',
        'actors': [
          {'id': 7, 'name': '测试演员', 'gender': 1},
          {'id': 0, 'name': '未知演员'},
        ],
      }),
    );
  }

  void completeMediaPoints() {
    mediaPoints.complete(ResponseBody.fromString('[]', 200));
  }
}

Future<void> pumpResultPreview(
  WidgetTester tester, {
  required MediaPreviewPresentation presentation,
  bool failDetail = false,
  PendingPreviewRequests? pendingRequests,
  bool settle = true,
  ValueChanged<int>? onActorSelected,
  ValueChanged<MediaPreviewAction?>? onClosed,
}) async {
  final session = SessionStore.inMemory();
  await session.saveBaseUrl('https://api.example.com');
  final bundle = await createTestApiBundle(session);
  addTearDown(bundle.dispose);
  if (pendingRequests == null) {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      statusCode: failDetail ? 500 : 200,
      body: {
        'movie_number': 'ABC-001',
        'title': '测试影片',
        'actors': [
          {'id': 7, 'name': '测试演员', 'gender': 1},
          {'id': 0, 'name': '未知演员'},
        ],
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/2/points',
      body: [],
    );
  } else {
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/movies/ABC-001',
      responder: (_, __) => pendingRequests.movieDetail.future,
    );
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/media/2/points',
      responder: (_, __) => pendingRequests.mediaPoints.future,
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('open'),
              onPressed: () async {
                final action = await showMediaPreviewOverlay(
                  context: context,
                  presentation: presentation,
                  builder: (_) => MediaPreviewDialog(
                    item: MediaPreviewItem(
                      imageUrl: resultItem.image.resolvedUrl,
                      fileName: 'image-search.webp',
                      mediaId: resultItem.mediaId,
                      movieNumber: resultItem.movieNumber,
                      thumbnailId: resultItem.thumbnailId,
                      offsetSeconds: resultItem.offsetSeconds,
                      scoreText: '93%',
                    ),
                    availableActions: {
                      MediaPreviewAction.searchSimilar,
                      MediaPreviewAction.play,
                      MediaPreviewAction.openMovieDetail,
                    },
                    presentation: presentation,
                    useInlineNavigation: true,
                    onActorSelected: onActorSelected,
                  ),
                );
                onClosed?.call(action);
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  for (final presentation in [
    MediaPreviewPresentation.dialog,
    MediaPreviewPresentation.bottomDrawer,
  ]) {
    testWidgets(
      '$presentation cover opens detail and removes duplicate actions',
      (tester) async {
        MediaPreviewAction? selected;
        await pumpResultPreview(
          tester,
          presentation: presentation,
          onClosed: (action) => selected = action,
        );
        expect(find.text('影片详情'), findsNothing);
        expect(find.text('播放'), findsNothing);
        expect(
          find.byKey(const Key('media-preview-center-play')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('image-search-result-preview-movie-cover')),
        );
        await tester.pumpAndSettle();
        expect(selected, MediaPreviewAction.openMovieDetail);
        expect(find.byType(MediaPreviewDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$presentation actor name selects valid actor and closes overlay',
      (tester) async {
        int? selected;
        var closed = false;
        await pumpResultPreview(
          tester,
          presentation: presentation,
          onActorSelected: (id) => selected = id,
          onClosed: (_) => closed = true,
        );
        await tester.tap(find.text('未知演员'));
        await tester.pumpAndSettle();
        expect(selected, isNull);
        expect(closed, isFalse);
        await tester.tap(find.text('测试演员'));
        await tester.pumpAndSettle();
        expect(selected, 7);
        expect(closed, isTrue);
        expect(find.byType(MediaPreviewDialog), findsNothing);
      },
    );
    testWidgets('$presentation central play still returns play action', (
      tester,
    ) async {
      MediaPreviewAction? selected;
      await pumpResultPreview(
        tester,
        presentation: presentation,
        onClosed: (action) => selected = action,
      );
      await tester.tap(find.byKey(const Key('media-preview-center-play')));
      await tester.pumpAndSettle();
      expect(selected, MediaPreviewAction.play);
    });
    testWidgets(
      '$presentation keeps actions as skeletons until all data loads',
      (tester) async {
        final pendingRequests = PendingPreviewRequests();
        await pumpResultPreview(
          tester,
          presentation: presentation,
          pendingRequests: pendingRequests,
          settle: false,
        );

        expect(find.text('影片详情'), findsNothing);
        expect(
          find.byKey(const Key('media-preview-action-skeleton-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('media-preview-action-skeleton-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('media-preview-action-skeleton-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('image-search-result-preview-movie-info-skeleton'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('image-search-result-preview-movie-cover-skeleton'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('image-search-result-preview-actor-skeleton-0'),
          ),
          findsOneWidget,
        );

        pendingRequests.completeMovieDetail();
        await tester.pump();
        expect(
          find.byKey(const Key('media-preview-action-skeleton-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('image-search-result-preview-movie-info-skeleton'),
          ),
          findsOneWidget,
        );
        expect(find.text('相似图片'), findsNothing);

        pendingRequests.completeMediaPoints();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('media-preview-action-skeleton-0')),
          findsNothing,
        );
        expect(
          find.byKey(
            const Key('image-search-result-preview-movie-info-skeleton'),
          ),
          findsNothing,
        );
        expect(find.text('相似图片'), findsOneWidget);
        expect(find.text('影片详情'), findsNothing);
      },
    );
    testWidgets('$presentation detail failure retains detail entry', (
      tester,
    ) async {
      MediaPreviewAction? selected;
      await pumpResultPreview(
        tester,
        presentation: presentation,
        failDetail: true,
        onClosed: (action) => selected = action,
      );
      expect(find.text('影片详情'), findsOneWidget);
      await tester.ensureVisible(find.text('影片详情'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('影片详情'));
      await tester.pumpAndSettle();
      expect(selected, MediaPreviewAction.openMovieDetail);
    });
  }
}
