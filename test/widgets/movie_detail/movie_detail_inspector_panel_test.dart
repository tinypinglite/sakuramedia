import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/movies/data/missav_thumbnail_result_dto.dart';
import 'package:sakuramedia/features/movies/data/missav_thumbnail_stream_update.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_review_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_inspector_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'movie detail inspector review loading skeleton keeps at least three items',
    (WidgetTester tester) async {
      final pendingReviews = Completer<List<MovieReviewDto>>();
      addTearDown(() {
        if (!pendingReviews.isCompleted) {
          pendingReviews.complete(const <MovieReviewDto>[]);
        }
      });

      await _pumpInspectorPanel(
        tester,
        panelHeight: 280,
        fetchMovieReviews: ({
          required String movieNumber,
          required int page,
          required int pageSize,
          required MovieReviewSort sort,
        }) {
          return pendingReviews.future;
        },
      );
      await tester.pump();

      final listHeight = tester.getSize(find.byType(ListView)).height;
      final expectedCount = _expectedSkeletonCount(listHeight);

      expect(expectedCount, greaterThanOrEqualTo(3));
      expect(_reviewSkeletonFinder(), findsNWidgets(expectedCount));
      expect(
        tester.widget<ListView>(find.byType(ListView)).semanticChildCount,
        expectedCount,
      );
    },
  );

  testWidgets(
    'movie detail inspector review loading skeleton expands with available height',
    (WidgetTester tester) async {
      final pendingReviews = Completer<List<MovieReviewDto>>();
      addTearDown(() {
        if (!pendingReviews.isCompleted) {
          pendingReviews.complete(const <MovieReviewDto>[]);
        }
      });

      await _pumpInspectorPanel(
        tester,
        panelHeight: 640,
        fetchMovieReviews: ({
          required String movieNumber,
          required int page,
          required int pageSize,
          required MovieReviewSort sort,
        }) {
          return pendingReviews.future;
        },
      );
      await tester.pump();

      final listHeight = tester.getSize(find.byType(ListView)).height;
      final expectedCount = _expectedSkeletonCount(listHeight);

      expect(expectedCount, greaterThan(3));
      expect(_reviewSkeletonFinder(), findsNWidgets(expectedCount));
      expect(
        tester.widget<ListView>(find.byType(ListView)).semanticChildCount,
        expectedCount,
      );
    },
  );

  testWidgets(
    'movie detail inspector clears content and shows cupertino spinner while switching review sort',
    (WidgetTester tester) async {
      final pendingRecently = Completer<List<MovieReviewDto>>();
      var requestCount = 0;
      addTearDown(() {
        if (!pendingRecently.isCompleted) {
          pendingRecently.complete(const <MovieReviewDto>[]);
        }
      });

      await _pumpInspectorPanel(
        tester,
        panelHeight: 480,
        platform: TargetPlatform.macOS,
        fetchMovieReviews: ({
          required String movieNumber,
          required int page,
          required int pageSize,
          required MovieReviewSort sort,
        }) {
          requestCount += 1;
          if (requestCount == 1) {
            return Future<List<MovieReviewDto>>.value(<MovieReviewDto>[
              _buildReview(prefix: 'hot'),
            ]);
          }
          return pendingRecently.future;
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('movie-detail-review-sort-recently')),
      );
      await tester.pump();

      expect(find.text('hot-review-1'), findsNothing);
      expect(
        find.byKey(
          const Key('movie-detail-review-sort-switch-loading-indicator'),
        ),
        findsOneWidget,
      );
      final spinner = tester.widget<CupertinoActivityIndicator>(
        find.byKey(
          const Key('movie-detail-review-sort-switch-loading-spinner'),
        ),
      );
      expect(spinner, isNotNull);

      final hotButton = tester.widget<AppButton>(
        find.byKey(const Key('movie-detail-review-sort-hotly')),
      );
      final recentButton = tester.widget<AppButton>(
        find.byKey(const Key('movie-detail-review-sort-recently')),
      );
      expect(hotButton.onPressed, isNull);
      expect(recentButton.onPressed, isNull);

      pendingRecently.complete(<MovieReviewDto>[
        _buildReview(prefix: 'recent'),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('recent-review-1'), findsOneWidget);
      expect(
        find.byKey(
          const Key('movie-detail-review-sort-switch-loading-indicator'),
        ),
        findsNothing,
      );
      final hotButtonAfter = tester.widget<AppButton>(
        find.byKey(const Key('movie-detail-review-sort-hotly')),
      );
      final recentButtonAfter = tester.widget<AppButton>(
        find.byKey(const Key('movie-detail-review-sort-recently')),
      );
      expect(hotButtonAfter.onPressed, isNotNull);
      expect(recentButtonAfter.onPressed, isNotNull);
    },
  );

  testWidgets(
    'movie detail inspector shows material spinner while switching review sort on android',
    (WidgetTester tester) async {
      final pendingRecently = Completer<List<MovieReviewDto>>();
      var requestCount = 0;
      addTearDown(() {
        if (!pendingRecently.isCompleted) {
          pendingRecently.complete(const <MovieReviewDto>[]);
        }
      });

      await _pumpInspectorPanel(
        tester,
        panelHeight: 480,
        platform: TargetPlatform.android,
        fetchMovieReviews: ({
          required String movieNumber,
          required int page,
          required int pageSize,
          required MovieReviewSort sort,
        }) {
          requestCount += 1;
          if (requestCount == 1) {
            return Future<List<MovieReviewDto>>.value(<MovieReviewDto>[
              _buildReview(prefix: 'hot'),
            ]);
          }
          return pendingRecently.future;
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('movie-detail-review-sort-recently')),
      );
      await tester.pump();

      expect(find.text('hot-review-1'), findsNothing);
      expect(
        find.byKey(
          const Key('movie-detail-review-sort-switch-loading-indicator'),
        ),
        findsOneWidget,
      );
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byKey(
          const Key('movie-detail-review-sort-switch-loading-spinner'),
        ),
      );
      expect(spinner, isNotNull);
    },
  );

  testWidgets(
    'movie detail inspector shows missav tab after thumbnail tab and stays idle before user starts',
    (WidgetTester tester) async {
      var missavRequestCount = 0;

      await _pumpInspectorPanel(
        tester,
        panelHeight: 480,
        fetchMovieReviews: ({
          required String movieNumber,
          required int page,
          required int pageSize,
          required MovieReviewSort sort,
        }) async {
          return const <MovieReviewDto>[];
        },
        fetchMissavThumbnailsStream: ({
          required String movieNumber,
          bool refresh = false,
        }) {
          missavRequestCount += 1;
          return const Stream<MissavThumbnailStreamUpdate>.empty();
        },
      );
      await tester.pumpAndSettle();

      final tabs = tester.widgetList<Tab>(find.byType(Tab)).toList();
      expect(tabs.map((tab) => tab.text), <String?>[
        '评论',
        '磁力搜索',
        '缩略图',
        'Missav缩略图',
      ]);

      await tester.tap(find.text('Missav缩略图'));
      await tester.pumpAndSettle();

      expect(missavRequestCount, 0);
      expect(
        find.byKey(const Key('movie-detail-missav-start-button')),
        findsOneWidget,
      );
      expect(find.text('这是 MissAV 外部来源帧图，首次获取可能耗时较长。'), findsOneWidget);
    },
  );

  testWidgets(
    'movie detail inspector missav tab shows progress and keeps selection without preview on success',
    (WidgetTester tester) async {
      final missavStreamController =
          StreamController<MissavThumbnailStreamUpdate>();
      var missavRequestCount = 0;
      addTearDown(() async {
        if (!missavStreamController.isClosed) {
          await missavStreamController.close();
        }
      });

      await _pumpInspectorPanel(
        tester,
        panelHeight: 520,
        fetchMovieReviews: ({
          required String movieNumber,
          required int page,
          required int pageSize,
          required MovieReviewSort sort,
        }) async {
          return const <MovieReviewDto>[];
        },
        fetchMissavThumbnailsStream: ({
          required String movieNumber,
          bool refresh = false,
        }) {
          missavRequestCount += 1;
          return missavStreamController.stream;
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Missav缩略图'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('movie-detail-missav-start-button')),
      );
      await tester.pump();

      expect(missavRequestCount, 1);
      expect(find.text('正在获取 MissAV 缩略图'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-detail-missav-loading-state')),
        findsOneWidget,
      );

      missavStreamController.add(
        const MissavThumbnailStreamUpdate(
          stage: 'download_progress',
          message: '正在下载 MissAV 缩略图，请不要关闭此页面',
          current: 1,
          total: 3,
        ),
      );
      await tester.pump();

      expect(find.text('正在下载 MissAV 缩略图，请不要关闭此页面'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      final loadingStateSize = tester.getSize(
        find.byKey(const Key('movie-detail-missav-loading-state')),
      );
      final statusCardSize = tester.getSize(
        find.byKey(const Key('catalog-search-stream-status-card')),
      );
      expect(loadingStateSize.height, lessThan(140));
      expect(statusCardSize.height, lessThan(140));
      expect(statusCardSize.width, lessThanOrEqualTo(520));
      expect(statusCardSize.width, lessThan(700));

      missavStreamController.add(
        MissavThumbnailStreamUpdate(
          stage: 'completed',
          message: 'MissAV 缩略图获取完成',
          success: true,
          result: const MissavThumbnailResultDto(
            movieNumber: 'ABC-001',
            source: 'missav',
            total: 6,
            items: <MissavThumbnailItemDto>[
              MissavThumbnailItemDto(index: 0, url: '/missav-0.jpg'),
              MissavThumbnailItemDto(index: 1, url: '/missav-1.jpg'),
              MissavThumbnailItemDto(index: 2, url: '/missav-2.jpg'),
              MissavThumbnailItemDto(index: 3, url: '/missav-3.jpg'),
              MissavThumbnailItemDto(index: 4, url: '/missav-4.jpg'),
              MissavThumbnailItemDto(index: 5, url: '/missav-5.jpg'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-missav-thumbnail-grid')),
        findsOneWidget,
      );
      expect(_thumbnailBorderWidth(tester, 'movie-detail-missav', 0), 1.5);
      expect(_thumbnailBorderWidth(tester, 'movie-detail-missav', 1), 1.0);

      await tester.tap(find.byKey(const Key('movie-detail-missav-thumb-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('movie-plot-preview-dialog')), findsNothing);
      expect(_thumbnailBorderWidth(tester, 'movie-detail-missav', 0), 1.0);
      expect(_thumbnailBorderWidth(tester, 'movie-detail-missav', 1), 1.5);
    },
  );

  testWidgets(
    'movie detail inspector missav tab shows error state and supports retry',
    (WidgetTester tester) async {
      var missavRequestCount = 0;

      await _pumpInspectorPanel(
        tester,
        panelHeight: 520,
        fetchMovieReviews: ({
          required String movieNumber,
          required int page,
          required int pageSize,
          required MovieReviewSort sort,
        }) async {
          return const <MovieReviewDto>[];
        },
        fetchMissavThumbnailsStream: ({
          required String movieNumber,
          bool refresh = false,
        }) {
          missavRequestCount += 1;
          if (missavRequestCount == 1) {
            return Stream<MissavThumbnailStreamUpdate>.fromIterable(
              const <MissavThumbnailStreamUpdate>[
                MissavThumbnailStreamUpdate(
                  stage: 'completed',
                  message: 'MissAV 缩略图获取失败',
                  success: false,
                  detail: 'thumbnail config missing',
                ),
              ],
            );
          }
          return Stream<MissavThumbnailStreamUpdate>.fromIterable(
            <MissavThumbnailStreamUpdate>[
              MissavThumbnailStreamUpdate(
                stage: 'completed',
                message: 'MissAV 缩略图获取完成',
                success: true,
                result: const MissavThumbnailResultDto(
                  movieNumber: 'ABC-001',
                  source: 'missav',
                  total: 1,
                  items: <MissavThumbnailItemDto>[
                    MissavThumbnailItemDto(index: 0, url: '/missav-0.jpg'),
                  ],
                ),
              ),
            ],
          );
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Missav缩略图'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('movie-detail-missav-start-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('thumbnail config missing'), findsOneWidget);
      expect(
        find.byKey(const Key('movie-detail-missav-retry-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('movie-detail-missav-retry-button')),
      );
      await tester.pumpAndSettle();

      expect(missavRequestCount, 2);
      expect(
        find.byKey(const Key('movie-detail-missav-thumbnail-grid')),
        findsOneWidget,
      );
    },
  );
}

Future<void> _pumpInspectorPanel(
  WidgetTester tester, {
  required double panelHeight,
  TargetPlatform? platform,
  required Future<List<MovieReviewDto>> Function({
    required String movieNumber,
    required int page,
    required int pageSize,
    required MovieReviewSort sort,
  })
  fetchMovieReviews,
  Stream<MissavThumbnailStreamUpdate> Function({
    required String movieNumber,
    bool refresh,
  })?
  fetchMissavThumbnailsStream,
}) async {
  final sessionStore = SessionStore.inMemory();
  await tester.pumpWidget(
    ChangeNotifierProvider<SessionStore>.value(
      value: sessionStore,
      child: MaterialApp(
        theme:
            platform == null
                ? sakuraThemeData
                : sakuraThemeData.copyWith(platform: platform),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 960,
              height: panelHeight,
              child: MovieDetailInspectorPanel(
                movieNumber: 'ABC-001',
                selectedMedia: null,
                fetchMovieReviews: fetchMovieReviews,
                fetchMediaThumbnails: ({required int mediaId}) async {
                  return const <MovieMediaThumbnailDto>[];
                },
                fetchMissavThumbnailsStream:
                    fetchMissavThumbnailsStream ??
                    ({required String movieNumber, bool refresh = false}) =>
                        const Stream<MissavThumbnailStreamUpdate>.empty(),
                searchCandidates: ({
                  required String movieNumber,
                  String? indexerKind,
                }) async {
                  return const <DownloadCandidateDto>[];
                },
                createDownloadRequest: ({
                  required String movieNumber,
                  required int clientId,
                  required DownloadCandidateDto candidate,
                }) async {
                  return const DownloadRequestResponseDto(
                    task: DownloadTaskDto(
                      id: 0,
                      clientId: 0,
                      movieNumber: null,
                      name: '',
                      infoHash: '',
                      savePath: '',
                      progress: 0,
                      downloadState: '',
                      importStatus: '',
                      createdAt: null,
                      updatedAt: null,
                    ),
                    created: false,
                  );
                },
                onClose: () {},
                showCloseButton: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

int _expectedSkeletonCount(double availableHeight) {
  const spacingXs = 4.0;
  const spacingSm = 8.0;
  const spacingMd = 12.0;
  const skeletonLineHeight = 12.0;
  const skeletonLineCount = 3;
  const internalGapCount = 2;
  final itemHeight =
      (spacingMd * 2) +
      (skeletonLineHeight * skeletonLineCount) +
      (spacingXs * internalGapCount);
  final estimatedCount =
      ((availableHeight + spacingSm) / (itemHeight + spacingSm)).ceil();
  return estimatedCount < 3 ? 3 : estimatedCount;
}

MovieReviewDto _buildReview({required String prefix}) {
  return MovieReviewDto(
    id: 1,
    score: 5,
    content: '$prefix-review-1',
    createdAt: DateTime.parse('2026-03-10T08:00:00Z'),
    username: '$prefix-user-1',
    likeCount: 11,
    watchCount: 21,
  );
}

Finder _reviewSkeletonFinder() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('movie-detail-review-skeleton-');
  });
}

double _thumbnailBorderWidth(WidgetTester tester, String keyPrefix, int index) {
  final decoration = tester.widget<DecoratedBox>(
    find.byKey(Key('$keyPrefix-thumbnail-tile-$index-decoration')),
  );
  final boxDecoration = decoration.decoration as BoxDecoration;
  return (boxDecoration.border as Border).top.width;
}
