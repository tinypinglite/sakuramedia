import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_review_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_magnet_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_review_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_thumbnail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

typedef _FetchMovieReviews =
    Future<List<MovieReviewDto>> Function({
      required String movieNumber,
      required int page,
      required int pageSize,
      required MovieReviewSort sort,
    });
typedef _FetchMediaThumbnails =
    Future<List<MovieMediaThumbnailDto>> Function({required int mediaId});
typedef _SearchCandidates =
    Future<List<DownloadCandidateDto>> Function({
      required String movieNumber,
      String? indexerKind,
    });
typedef _CreateDownloadRequest =
    Future<DownloadRequestResponseDto> Function({
      required String movieNumber,
      required int clientId,
      required DownloadCandidateDto candidate,
    });

/// 只覆盖 inspector 需要的两个方法，其余交给 super（走 [ApiClient]，测试里
/// 不会命中）；调用未 stub 的方法应当立即出错以暴露漏 override 的 case。
class _FakeMoviesApi extends MoviesApi {
  _FakeMoviesApi({
    required ApiClient apiClient,
    required this.reviewsHandler,
    required this.thumbnailsHandler,
  }) : super(apiClient: apiClient);

  final _FetchMovieReviews reviewsHandler;
  final _FetchMediaThumbnails thumbnailsHandler;

  @override
  Future<List<MovieReviewDto>> getMovieReviews({
    required String movieNumber,
    int page = 1,
    int pageSize = 20,
    MovieReviewSort sort = MovieReviewSort.recently,
  }) => reviewsHandler(
    movieNumber: movieNumber,
    page: page,
    pageSize: pageSize,
    sort: sort,
  );

  @override
  Future<List<MovieMediaThumbnailDto>> getMediaThumbnails({
    required int mediaId,
  }) => thumbnailsHandler(mediaId: mediaId);
}

class _FakeDownloadsApi extends DownloadsApi {
  _FakeDownloadsApi({
    required ApiClient apiClient,
    required this.searchHandler,
    required this.createHandler,
  }) : super(apiClient: apiClient);

  final _SearchCandidates searchHandler;
  final _CreateDownloadRequest createHandler;

  @override
  Future<List<DownloadCandidateDto>> searchCandidates({
    required String movieNumber,
    String? indexerKind,
  }) => searchHandler(movieNumber: movieNumber, indexerKind: indexerKind);

  @override
  Future<DownloadRequestResponseDto> createDownloadRequest({
    required String movieNumber,
    required int clientId,
    required DownloadCandidateDto candidate,
  }) => createHandler(
    movieNumber: movieNumber,
    clientId: clientId,
    candidate: candidate,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'inspector releases its three providers when the panel unmounts',
    (WidgetTester tester) async {
      final container = await _pumpInspectorPanel(
        tester,
        panelHeight: 480,
        fetchMovieReviews:
            ({
              required String movieNumber,
              required int page,
              required int pageSize,
              required MovieReviewSort sort,
            }) async => const <MovieReviewDto>[],
      );
      await tester.pump();

      // 打开期间三者都被面板收编的 KeepAliveLink 保活：切 Tab 不丢已加载数据。
      expect(container.exists(movieDetailReviewProvider('ABC-001')), isTrue);
      expect(container.exists(movieDetailMagnetProvider('ABC-001')), isTrue);
      expect(
        container.exists(movieDetailThumbnailProvider(mediaId: null)),
        isTrue,
      );

      // 只换掉面板、保留同一个 scope：ProviderScope 卸载时会 cancel 掉 riverpod
      // 的 vsync timer，整棵树拆掉的话待释放队列永远不会结算。
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SizedBox.shrink()),
        ),
      );
      // autoDispose 的实际释放挂在 `Timer(Duration.zero)`，要推进时钟才结算。
      await tester.pump(const Duration(milliseconds: 16));

      // 回归守卫：link 必须由面板在 dispose 里 close。provider 自持 link 而无人
      // close 会形成「link 不关 → 永不 dispose → onDispose 里的 close 永不执行」
      // 的死锁式泄漏，打开过检查器的影片会常驻到登出。
      expect(container.exists(movieDetailReviewProvider('ABC-001')), isFalse);
      expect(container.exists(movieDetailMagnetProvider('ABC-001')), isFalse);
      expect(
        container.exists(movieDetailThumbnailProvider(mediaId: null)),
        isFalse,
      );
    },
  );

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
        fetchMovieReviews:
            ({
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
        fetchMovieReviews:
            ({
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
    'movie detail review sort updates immediately and retains old content while loading',
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
        fetchMovieReviews:
            ({
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

      expect(find.text('hot-review-1'), findsOneWidget);
      expect(find.text('正在更新筛选结果'), findsOneWidget);
      expect(
        find.byKey(
          const Key('movie-detail-review-sort-switch-loading-spinner'),
        ),
        findsNothing,
      );

      final hotButton = tester.widget<AppTextButton>(
        find.byKey(const Key('movie-detail-review-sort-hotly')),
      );
      final recentButton = tester.widget<AppTextButton>(
        find.byKey(const Key('movie-detail-review-sort-recently')),
      );
      expect(hotButton.onPressed, isNotNull);
      expect(recentButton.onPressed, isNotNull);
      expect(recentButton.isSelected, isTrue);
      expect(requestCount, 1);

      await tester.pump(const Duration(milliseconds: 260));
      expect(requestCount, 2);
      expect(find.text('hot-review-1'), findsOneWidget);

      pendingRecently.complete(<MovieReviewDto>[
        _buildReview(prefix: 'recent'),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('recent-review-1'), findsOneWidget);
      expect(find.text('正在更新筛选结果'), findsNothing);
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
    'movie detail review rapid sort changes request only the final value',
    (WidgetTester tester) async {
      final pendingFinal = Completer<List<MovieReviewDto>>();
      var requestCount = 0;
      MovieReviewSort? requestedSort;
      addTearDown(() {
        if (!pendingFinal.isCompleted) {
          pendingFinal.complete(const <MovieReviewDto>[]);
        }
      });

      await _pumpInspectorPanel(
        tester,
        panelHeight: 480,
        platform: TargetPlatform.android,
        fetchMovieReviews:
            ({
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
              requestedSort = sort;
              return pendingFinal.future;
            },
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('movie-detail-review-sort-recently')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('movie-detail-review-sort-hotly')));
      await tester.pump();

      expect(requestCount, 1);
      expect(find.text('hot-review-1'), findsOneWidget);
      final hotButton = tester.widget<AppTextButton>(
        find.byKey(const Key('movie-detail-review-sort-hotly')),
      );
      expect(hotButton.isSelected, isTrue);

      await tester.pump(const Duration(milliseconds: 260));
      expect(requestCount, 2);
      expect(requestedSort, MovieReviewSort.hotly);

      pendingFinal.complete(<MovieReviewDto>[_buildReview(prefix: 'final')]);
      await tester.pumpAndSettle();
      expect(find.text('final-review-1'), findsOneWidget);
    },
  );

  testWidgets(
    'movie detail inspector aligns compact tabs with review toolbar content',
    (WidgetTester tester) async {
      await _pumpInspectorPanel(
        tester,
        panelHeight: 480,
        fetchMovieReviews:
            ({
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
        fetchMovieReviews:
            ({
              required String movieNumber,
              required int page,
              required int pageSize,
              required MovieReviewSort sort,
            }) async {
              return const <MovieReviewDto>[];
            },
        searchCandidates:
            ({required String movieNumber, String? indexerKind}) async {
              return const <DownloadCandidateDto>[
                DownloadCandidateDto(
                  sourceUri: 'provider://torznab/abcdef',
                  indexerName: 'mteam',
                  indexerKind: 'bt',
                  resolvedClientId: 2,
                  resolvedClientName: 'qb-main',
                  movieNumber: 'ABC-001',
                  title: 'ABC-001 4K 中文字幕',
                  sizeBytes: 12884901888,
                  seeders: 35,
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
      sourceUri: 'provider://dmhy/abcdef',
      indexerName: 'dmhy',
      indexerKind: 'bt',
      resolvedClientId: 2,
      resolvedClientName: 'qb-main',
      downloadClients: <DownloadCandidateClientDto>[
        DownloadCandidateClientDto(id: 2, name: 'qb-main'),
        DownloadCandidateClientDto(id: 3, name: '115-main'),
      ],
      movieNumber: 'ABC-001',
      title: 'ABC-001 中文字幕',
      sizeBytes: 1024,
      seeders: 8,
    );
    int? submittedClientId;

    await _pumpInspectorPanel(
      tester,
      panelHeight: 520,
      fetchMovieReviews:
          ({
            required String movieNumber,
            required int page,
            required int pageSize,
            required MovieReviewSort sort,
          }) async => const <MovieReviewDto>[],
      searchCandidates:
          ({required String movieNumber, String? indexerKind}) async =>
              const <DownloadCandidateDto>[candidate],
      createDownloadRequest:
          ({
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
    await tester.tap(
      find.byKey(const Key('movie-detail-magnet-search-button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(Key('movie-detail-magnet-client-${candidate.submitKey}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('115-main').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-detail-magnet-submit-0')));
    await tester.pumpAndSettle();

    expect(submittedClientId, 3);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('magnet candidate shows and copies its source URI', (
    WidgetTester tester,
  ) async {
    const sourceUri = 'provider://dmhy/abcdef?dn=ABC-001';
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
      fetchMovieReviews:
          ({
            required String movieNumber,
            required int page,
            required int pageSize,
            required MovieReviewSort sort,
          }) async => const <MovieReviewDto>[],
      searchCandidates:
          ({required String movieNumber, String? indexerKind}) async =>
              const <DownloadCandidateDto>[
                DownloadCandidateDto(
                  sourceUri: sourceUri,
                  indexerName: 'dmhy',
                  indexerKind: 'bt',
                  resolvedClientId: 2,
                  resolvedClientName: 'qb-main',
                  movieNumber: 'ABC-001',
                  title: 'ABC-001 中文字幕',
                  sizeBytes: 1024,
                  seeders: 8,
                ),
              ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('磁力搜索'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('movie-detail-magnet-search-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('资源地址'), findsOneWidget);
    expect(find.text(sourceUri), findsOneWidget);

    final copyButton = find.byKey(const Key('movie-detail-magnet-copy-0'));
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    await tester.pump();

    expect(clipboardArguments, <String, dynamic>{'text': sourceUri});
    expect(find.text('资源地址已复制'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'movie detail inspector thumbnail tab toggles clip selection mode',
    (WidgetTester tester) async {
      await _pumpInspectorPanel(
        tester,
        panelHeight: 520,
        fetchMovieReviews:
            ({
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

/// 返回承载面板的 [ProviderContainer]（用 [UncontrolledProviderScope] 注入，
/// 容器由本函数持有并在 tearDown 释放），便于断言 provider 的存活/释放。
Future<ProviderContainer> _pumpInspectorPanel(
  WidgetTester tester, {
  required double panelHeight,
  TargetPlatform? platform,
  required _FetchMovieReviews fetchMovieReviews,
  _SearchCandidates? searchCandidates,
  _CreateDownloadRequest? createDownloadRequest,
}) async {
  final sessionStore = SessionStore.inMemory();
  final apiClient = ApiClient(sessionStore: sessionStore);
  addTearDown(apiClient.dispose);
  final fakeMoviesApi = _FakeMoviesApi(
    apiClient: apiClient,
    reviewsHandler: fetchMovieReviews,
    thumbnailsHandler: ({required int mediaId}) async =>
        const <MovieMediaThumbnailDto>[],
  );
  final fakeDownloadsApi = _FakeDownloadsApi(
    apiClient: apiClient,
    searchHandler:
        searchCandidates ??
        ({required String movieNumber, String? indexerKind}) async =>
            const <DownloadCandidateDto>[],
    createHandler:
        createDownloadRequest ??
        ({
          required String movieNumber,
          required int clientId,
          required DownloadCandidateDto candidate,
        }) async => DownloadRequestResponseDto(
          task: _emptyDownloadTask(clientId: clientId),
          created: false,
        ),
  );

  final container = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(sessionStore),
      moviesApiProvider.overrideWithValue(fakeMoviesApi),
      downloadsApiProvider.overrideWithValue(fakeDownloadsApi),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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

  return container;
}

DownloadTaskDto _emptyDownloadTask({required int clientId}) {
  return DownloadTaskDto(
    id: 0,
    clientId: clientId,
    movieNumber: null,
    name: '',
    remoteId: '',
    state: '',
    progress: 0,
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
