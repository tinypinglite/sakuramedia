import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_review_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart';

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

      final hotButton = tester.widget<AppTextButton>(
        find.byKey(const Key('movie-detail-review-sort-hotly')),
      );
      final recentButton = tester.widget<AppTextButton>(
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
      final hotButtonAfter = tester.widget<AppTextButton>(
        find.byKey(const Key('movie-detail-review-sort-hotly')),
      );
      final recentButtonAfter = tester.widget<AppTextButton>(
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
    'movie detail inspector aligns compact tabs with review toolbar content',
    (WidgetTester tester) async {
      await _pumpInspectorPanel(
        tester,
        panelHeight: 480,
        fetchMovieReviews: ({
          required String movieNumber,
          required int page,
          required int pageSize,
          required MovieReviewSort sort,
        }) async {
          return <MovieReviewDto>[_buildReview(prefix: 'hot')];
        },
      );
      await tester.pumpAndSettle();

      final firstTabRect = tester.getRect(find.byType(Tab).first);
      final hotSortRect = tester.getRect(
        find.byKey(const Key('movie-detail-review-sort-hotly')),
      );

      expect(firstTabRect.left, hotSortRect.left);
    },
  );

  testWidgets(
    'movie detail inspector magnet tab shows sort controls and updates direction semantics',
    (WidgetTester tester) async {
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
        searchCandidates: ({
          required String movieNumber,
          String? indexerKind,
        }) async {
          return const <DownloadCandidateDto>[
            DownloadCandidateDto(
              source: 'jackett',
              indexerName: 'mteam',
              indexerKind: 'bt',
              resolvedClientId: 2,
              resolvedClientName: 'qb-main',
              movieNumber: 'ABC-001',
              title: 'ABC-001 4K 中文字幕',
              sizeBytes: 12884901888,
              seeders: 35,
              magnetUrl: 'magnet:?xt=urn:btih:abcdef',
              torrentUrl: '',
              tags: <String>['4K', '中字'],
            ),
          ];
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('磁力搜索'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('movie-detail-magnet-search-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-magnet-sort-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('movie-detail-magnet-sort-direction')),
        findsOneWidget,
      );
      expect(find.byTooltip('当前降序，点击切换为升序'), findsOneWidget);
      final sortFieldRect = tester.getRect(
        find.byKey(const Key('movie-detail-magnet-sort-field')),
      );
      final searchButtonRect = tester.getRect(
        find.byKey(const Key('movie-detail-magnet-search-button')),
      );
      expect(sortFieldRect.left, lessThan(searchButtonRect.left));

      await tester.tap(
        find.byKey(const Key('movie-detail-magnet-sort-direction')),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('当前升序，点击切换为降序'), findsOneWidget);
    },
  );

  testWidgets('magnet candidate submits the explicitly selected downloader', (
    WidgetTester tester,
  ) async {
    const candidate = DownloadCandidateDto(
      source: 'jackett',
      indexerName: 'dmhy',
      indexerKind: 'bt',
      resolvedClientId: 2,
      resolvedClientName: 'qb-main',
      downloadClients: <DownloadCandidateClientDto>[
        DownloadCandidateClientDto(
          id: 2,
          name: 'qb-main',
          kind: DownloadClientKind.qbittorrent,
        ),
        DownloadCandidateClientDto(
          id: 3,
          name: '115-main',
          kind: DownloadClientKind.cloud115,
        ),
      ],
      movieNumber: 'ABC-001',
      title: 'ABC-001 中文字幕',
      sizeBytes: 1024,
      seeders: 8,
      magnetUrl: 'magnet:?xt=urn:btih:abcdef',
      torrentUrl: '',
      tags: <String>[],
    );
    int? submittedClientId;

    await _pumpInspectorPanel(
      tester,
      panelHeight: 520,
      fetchMovieReviews: ({
        required String movieNumber,
        required int page,
        required int pageSize,
        required MovieReviewSort sort,
      }) async =>
          const <MovieReviewDto>[],
      searchCandidates: ({
        required String movieNumber,
        String? indexerKind,
      }) async =>
          const <DownloadCandidateDto>[candidate],
      createDownloadRequest: ({
        required String movieNumber,
        required int clientId,
        required DownloadCandidateDto candidate,
      }) async {
        submittedClientId = clientId;
        return DownloadRequestResponseDto(
          task: _emptyDownloadTask(clientId: clientId),
          created: true,
        );
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('磁力搜索'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const Key('movie-detail-magnet-search-button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(Key('movie-detail-magnet-client-${candidate.submitKey}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('115-main · 115 离线').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-detail-magnet-submit-0')));
    await tester.pumpAndSettle();

    expect(submittedClientId, 3);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('magnet candidate shows and copies its full magnet link', (
    WidgetTester tester,
  ) async {
    const magnetUrl = 'magnet:?xt=urn:btih:abcdef&dn=ABC-001';
    Object? clipboardArguments;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardArguments = call.arguments;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await _pumpInspectorPanel(
      tester,
      panelHeight: 640,
      fetchMovieReviews: ({
        required String movieNumber,
        required int page,
        required int pageSize,
        required MovieReviewSort sort,
      }) async =>
          const <MovieReviewDto>[],
      searchCandidates: ({
        required String movieNumber,
        String? indexerKind,
      }) async =>
          const <DownloadCandidateDto>[
        DownloadCandidateDto(
          source: 'jackett',
          indexerName: 'dmhy',
          indexerKind: 'bt',
          resolvedClientId: 2,
          resolvedClientName: 'qb-main',
          movieNumber: 'ABC-001',
          title: 'ABC-001 中文字幕',
          sizeBytes: 1024,
          seeders: 8,
          magnetUrl: magnetUrl,
          torrentUrl: '',
          tags: <String>[],
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('磁力搜索'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const Key('movie-detail-magnet-search-button')));
    await tester.pumpAndSettle();

    expect(find.text('磁力链接'), findsOneWidget);
    expect(find.text(magnetUrl), findsOneWidget);

    final copyButton = find.byKey(const Key('movie-detail-magnet-copy-0'));
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    await tester.pump();

    expect(clipboardArguments, <String, dynamic>{'text': magnetUrl});
    expect(find.text('磁力链接已复制'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'movie detail inspector thumbnail tab toggles clip selection mode',
    (WidgetTester tester) async {
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
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('缩略图'));
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(
        const Key('movie-detail-thumbnail-clip-toggle'),
      );
      expect(toggleFinder, findsOneWidget);
      expect(
        find.byKey(const Key('movie-detail-thumbnail-clip-selection-status')),
        findsNothing,
      );

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-thumbnail-clip-selection-status')),
        findsOneWidget,
      );
      expect(find.text('点击缩略图设为起点'), findsOneWidget);
      // 未选起止点时「创建」按钮禁用。
      final createButton = tester.widget<AppButton>(
        find.byKey(const Key('movie-detail-thumbnail-clip-create')),
      );
      expect(createButton.onPressed, isNull);

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('movie-detail-thumbnail-clip-selection-status')),
        findsNothing,
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
  }) fetchMovieReviews,
  Future<List<DownloadCandidateDto>> Function({
    required String movieNumber,
    String? indexerKind,
  })? searchCandidates,
  Future<DownloadRequestResponseDto> Function({
    required String movieNumber,
    required int clientId,
    required DownloadCandidateDto candidate,
  })? createDownloadRequest,
}) async {
  final sessionStore = SessionStore.inMemory();
  await tester.pumpWidget(
    ChangeNotifierProvider<SessionStore>.value(
      value: sessionStore,
      child: OKToast(
        child: MaterialApp(
          theme: platform == null
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
                  searchCandidates: searchCandidates ??
                      (
                          {required String movieNumber,
                          String? indexerKind}) async {
                        return const <DownloadCandidateDto>[];
                      },
                  createDownloadRequest: createDownloadRequest ??
                      ({
                        required String movieNumber,
                        required int clientId,
                        required DownloadCandidateDto candidate,
                      }) async =>
                          DownloadRequestResponseDto(
                            task: _emptyDownloadTask(clientId: clientId),
                            created: false,
                          ),
                  onClose: () {},
                  showCloseButton: false,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

DownloadTaskDto _emptyDownloadTask({required int clientId}) {
  return DownloadTaskDto(
    id: 0,
    clientId: clientId,
    movieNumber: null,
    name: '',
    infoHash: '',
    savePath: '',
    progress: 0,
    downloadState: '',
    importStatus: '',
    importStatusLabel: '',
    createdAt: null,
    updatedAt: null,
  );
}

int _expectedSkeletonCount(double availableHeight) {
  const spacingXs = 4.0;
  const spacingSm = 8.0;
  const spacingMd = 12.0;
  const skeletonLineHeight = 12.0;
  const skeletonLineCount = 3;
  const internalGapCount = 2;
  final itemHeight = (spacingMd * 2) +
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
