import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_error_dto.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_subscription_batch_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PagedMovieSummaryController', () {
    test(
      'initialize loads the first page and exposes pagination state',
      () async {
        final controller = PagedMovieSummaryController(
          subscribeMovie: ({required movieNumber}) async {},
          unsubscribeMovie:
              ({required movieNumber, deleteMedia = false}) async {},
          fetchPage: (page, pageSize) async {
            expect(page, 1);
            expect(pageSize, 24);
            return PaginatedResponseDto<MovieListItemDto>(
              items: _movies(1, 2),
              page: 1,
              pageSize: 24,
              total: 5,
            );
          },
        );

        await controller.initialize();

        expect(controller.items, hasLength(2));
        expect(controller.currentPage, 1);
        expect(controller.total, 5);
        expect(controller.hasLoadedOnce, isTrue);
        expect(controller.isInitialLoading, isFalse);
        expect(controller.isLoadingMore, isFalse);
        expect(controller.hasMore, isTrue);
        expect(controller.initialErrorMessage, isNull);
        expect(controller.loadMoreErrorMessage, isNull);

        controller.dispose();
      },
    );

    test('loadMore appends items until total is exhausted', () async {
      final requestedPages = <int>[];
      final controller = PagedMovieSummaryController(
        pageSize: 2,
        subscribeMovie: ({required movieNumber}) async {},
        unsubscribeMovie:
            ({required movieNumber, deleteMedia = false}) async {},
        fetchPage: (page, pageSize) async {
          requestedPages.add(page);
          if (page == 1) {
            return PaginatedResponseDto<MovieListItemDto>(
              items: _movies(1, 2),
              page: 1,
              pageSize: 2,
              total: 3,
            );
          }
          return PaginatedResponseDto<MovieListItemDto>(
            items: _movies(3, 1),
            page: 2,
            pageSize: 2,
            total: 3,
          );
        },
      );

      await controller.initialize();
      await controller.loadMore();
      await controller.loadMore();

      expect(requestedPages, <int>[1, 2]);
      expect(controller.items, hasLength(3));
      expect(controller.currentPage, 2);
      expect(controller.hasMore, isFalse);

      controller.dispose();
    });

    test(
      'initialize stores an initial load error when the first page fails',
      () async {
        final controller = PagedMovieSummaryController(
          subscribeMovie: ({required movieNumber}) async {},
          unsubscribeMovie:
              ({required movieNumber, deleteMedia = false}) async {},
          fetchPage:
              (_, __) => Future<PaginatedResponseDto<MovieListItemDto>>.error(
                Exception('boom'),
              ),
        );

        await controller.initialize();

        expect(controller.items, isEmpty);
        expect(controller.hasLoadedOnce, isFalse);
        expect(controller.initialErrorMessage, '最新入库影片加载失败，请稍后重试');
        expect(controller.loadMoreErrorMessage, isNull);

        controller.dispose();
      },
    );

    test('controller uses custom error messages when configured', () async {
      final controller = PagedMovieSummaryController(
        initialLoadErrorText: '影片列表加载失败，请稍后重试',
        loadMoreErrorText: '影片列表加载更多失败',
        pageSize: 2,
        subscribeMovie: ({required movieNumber}) async {},
        unsubscribeMovie:
            ({required movieNumber, deleteMedia = false}) async {},
        fetchPage: (page, pageSize) async {
          if (page == 1) {
            throw Exception('initial failed');
          }
          return PaginatedResponseDto<MovieListItemDto>(
            items: _movies(1, 2),
            page: 2,
            pageSize: 2,
            total: 4,
          );
        },
      );

      await controller.initialize();
      expect(controller.initialErrorMessage, '影片列表加载失败，请稍后重试');

      final retryController = PagedMovieSummaryController(
        initialLoadErrorText: '影片列表加载失败，请稍后重试',
        loadMoreErrorText: '影片列表加载更多失败',
        pageSize: 2,
        subscribeMovie: ({required movieNumber}) async {},
        unsubscribeMovie:
            ({required movieNumber, deleteMedia = false}) async {},
        fetchPage: (page, pageSize) async {
          if (page == 1) {
            return PaginatedResponseDto<MovieListItemDto>(
              items: _movies(1, 2),
              page: 1,
              pageSize: 2,
              total: 4,
            );
          }
          throw Exception('load more failed');
        },
      );

      await retryController.initialize();
      await retryController.loadMore();

      expect(retryController.loadMoreErrorMessage, '影片列表加载更多失败');

      controller.dispose();
      retryController.dispose();
    });

    test('loadMore keeps existing items when a later page fails', () async {
      final controller = PagedMovieSummaryController(
        pageSize: 2,
        subscribeMovie: ({required movieNumber}) async {},
        unsubscribeMovie:
            ({required movieNumber, deleteMedia = false}) async {},
        fetchPage: (page, pageSize) async {
          if (page == 1) {
            return PaginatedResponseDto<MovieListItemDto>(
              items: _movies(1, 2),
              page: 1,
              pageSize: 2,
              total: 4,
            );
          }
          throw Exception('next page failed');
        },
      );

      await controller.initialize();
      await controller.loadMore();

      expect(controller.items, hasLength(2));
      expect(controller.currentPage, 1);
      expect(controller.hasMore, isTrue);
      expect(controller.initialErrorMessage, isNull);
      expect(controller.loadMoreErrorMessage, '加载更多失败，请点击重试');

      controller.dispose();
    });

    test(
      'reload resets pagination state and fetches the first page again',
      () async {
        var cycle = 0;
        final controller = PagedMovieSummaryController(
          pageSize: 2,
          subscribeMovie: ({required movieNumber}) async {},
          unsubscribeMovie:
              ({required movieNumber, deleteMedia = false}) async {},
          fetchPage: (page, pageSize) async {
            cycle += 1;
            if (cycle == 1) {
              return PaginatedResponseDto<MovieListItemDto>(
                items: _movies(1, 2),
                page: 1,
                pageSize: 2,
                total: 4,
              );
            }
            return PaginatedResponseDto<MovieListItemDto>(
              items: _movies(101, 1),
              page: 1,
              pageSize: 2,
              total: 1,
            );
          },
        );

        await controller.initialize();
        await controller.reload();

        expect(cycle, 2);
        expect(controller.currentPage, 1);
        expect(controller.total, 1);
        expect(controller.items.single.movieNumber, 'ABC-101');
        expect(controller.hasMore, isFalse);
        expect(controller.initialErrorMessage, isNull);
        expect(controller.loadMoreErrorMessage, isNull);

        controller.dispose();
      },
    );

    test(
      'refresh replaces first page items without resetting state first',
      () async {
        var cycle = 0;
        final controller = PagedMovieSummaryController(
          pageSize: 2,
          subscribeMovie: ({required movieNumber}) async {},
          unsubscribeMovie:
              ({required movieNumber, deleteMedia = false}) async {},
          fetchPage: (page, pageSize) async {
            cycle += 1;
            if (cycle == 1) {
              return PaginatedResponseDto<MovieListItemDto>(
                items: _movies(1, 2),
                page: 1,
                pageSize: 2,
                total: 4,
              );
            }
            return PaginatedResponseDto<MovieListItemDto>(
              items: _movies(201, 1),
              page: 1,
              pageSize: 2,
              total: 1,
            );
          },
        );

        await controller.initialize();
        await controller.refresh();

        expect(controller.items.single.movieNumber, 'ABC-201');
        expect(controller.currentPage, 1);
        expect(controller.total, 1);
        expect(controller.hasMore, isFalse);
        expect(controller.initialErrorMessage, isNull);
        expect(controller.loadMoreErrorMessage, isNull);

        controller.dispose();
      },
    );

    test('refresh rethrows and keeps existing items on failure', () async {
      var cycle = 0;
      final controller = PagedMovieSummaryController(
        pageSize: 2,
        subscribeMovie: ({required movieNumber}) async {},
        unsubscribeMovie:
            ({required movieNumber, deleteMedia = false}) async {},
        fetchPage: (page, pageSize) async {
          cycle += 1;
          if (cycle == 1) {
            return PaginatedResponseDto<MovieListItemDto>(
              items: _movies(1, 2),
              page: 1,
              pageSize: 2,
              total: 4,
            );
          }
          throw Exception('refresh failed');
        },
      );

      await controller.initialize();

      await expectLater(controller.refresh(), throwsException);

      expect(controller.items, hasLength(2));
      expect(controller.items.first.movieNumber, 'ABC-001');
      expect(controller.currentPage, 1);
      expect(controller.total, 4);
      expect(controller.initialErrorMessage, isNull);
      expect(controller.loadMoreErrorMessage, isNull);

      controller.dispose();
    });

    test(
      'toggleSubscription subscribes movie and updates item in place',
      () async {
        final controller = PagedMovieSummaryController(
          subscribeMovie: ({required movieNumber}) async {
            expect(movieNumber, 'ABC-001');
          },
          unsubscribeMovie: ({
            required movieNumber,
            deleteMedia = false,
          }) async {
            fail('unsubscribeMovie should not be called');
          },
          fetchPage:
              (_, __) async => PaginatedResponseDto<MovieListItemDto>(
                items: <MovieListItemDto>[_movie(1, isSubscribed: false)],
                page: 1,
                pageSize: 24,
                total: 1,
              ),
        );

        await controller.initialize();
        final result = await controller.toggleSubscription(
          movieNumber: 'ABC-001',
        );

        expect(result.status, MovieSubscriptionToggleStatus.subscribed);
        expect(controller.items.single.isSubscribed, isTrue);
        expect(controller.isSubscriptionUpdating('ABC-001'), isFalse);

        controller.dispose();
      },
    );

    test(
      'toggleSubscription maps movie media conflict to blockedByMedia',
      () async {
        final controller = PagedMovieSummaryController(
          subscribeMovie: ({required movieNumber}) async {},
          unsubscribeMovie: ({
            required movieNumber,
            deleteMedia = false,
          }) async {
            throw const ApiException(
              statusCode: 409,
              message: '影片存在媒体文件，若需取消订阅请传 delete_media=true',
              error: ApiErrorDto(
                code: 'movie_subscription_has_media',
                message: '影片存在媒体文件，若需取消订阅请传 delete_media=true',
              ),
            );
          },
          fetchPage:
              (_, __) async => PaginatedResponseDto<MovieListItemDto>(
                items: <MovieListItemDto>[_movie(1, isSubscribed: true)],
                page: 1,
                pageSize: 24,
                total: 1,
              ),
        );

        await controller.initialize();
        final result = await controller.toggleSubscription(
          movieNumber: 'ABC-001',
        );

        expect(result.status, MovieSubscriptionToggleStatus.blockedByMedia);
        expect(controller.items.single.isSubscribed, isTrue);

        controller.dispose();
      },
    );

    test('applySubscriptionChange updates matched movie state', () async {
      final controller = PagedMovieSummaryController(
        subscribeMovie: ({required movieNumber}) async {},
        unsubscribeMovie:
            ({required movieNumber, deleteMedia = false}) async {},
        fetchPage:
            (_, __) async => PaginatedResponseDto<MovieListItemDto>(
              items: <MovieListItemDto>[_movie(1, isSubscribed: false)],
              page: 1,
              pageSize: 24,
              total: 1,
            ),
      );

      await controller.initialize();
      controller.applySubscriptionChange(
        movieNumber: 'ABC-001',
        isSubscribed: true,
      );

      expect(controller.items.single.isSubscribed, isTrue);

      controller.dispose();
    });

    test(
      'batchToggleSubscription subscribes matched items, broadcasts once, '
      'and reports full-success result',
      () async {
        final broadcasts = <List<MovieSubscriptionChange>>[];
        var notifyCount = 0;
        final controller = PagedMovieSummaryController(
          subscribeMovie: ({required movieNumber}) async {},
          unsubscribeMovie:
              ({required movieNumber, deleteMedia = false}) async {},
          batchSubscribeMovies: ({required movieNumbers}) async {
            expect(movieNumbers, <String>['ABC-001', 'ABC-002']);
            return const MovieSubscriptionBatchResultDto(
              requestedCount: 2,
              updatedCount: 2,
              skippedCount: 0,
              skipped: <MovieSubscriptionSkippedItemDto>[],
            );
          },
          batchUnsubscribeMovies: ({required movieNumbers}) async {
            fail('unsubscribe should not be called');
          },
          onSubscriptionsBatchChanged: broadcasts.add,
          fetchPage: (_, __) async => PaginatedResponseDto<MovieListItemDto>(
            items: <MovieListItemDto>[
              _movie(1, isSubscribed: false),
              _movie(2, isSubscribed: false),
            ],
            page: 1,
            pageSize: 24,
            total: 2,
          ),
        );

        await controller.initialize();
        controller.addListener(() => notifyCount += 1);

        final result = await controller.batchToggleSubscription(
          movieNumbers: const <String>['ABC-001', 'ABC-002'],
          subscribe: true,
        );

        expect(result.updatedCount, 2);
        expect(result.skippedCount, 0);
        expect(result.hasError, isFalse);
        expect(
          controller.items.map((movie) => movie.isSubscribed),
          <bool>[true, true],
        );
        expect(broadcasts, hasLength(1));
        expect(
          broadcasts.single.map((change) => change.movieNumber),
          <String>['ABC-001', 'ABC-002'],
        );
        // 只有乐观更新触发的那一次通知；请求成功且无 skip 时不再额外 notify。
        expect(notifyCount, 1);

        controller.dispose();
      },
    );

    test(
      'batchToggleSubscription rolls back skipped items to their original '
      'state and broadcasts only the accepted ones',
      () async {
        final broadcasts = <List<MovieSubscriptionChange>>[];
        final controller = PagedMovieSummaryController(
          subscribeMovie: ({required movieNumber}) async {},
          unsubscribeMovie:
              ({required movieNumber, deleteMedia = false}) async {},
          batchUnsubscribeMovies: ({required movieNumbers}) async =>
              const MovieSubscriptionBatchResultDto(
                requestedCount: 3,
                updatedCount: 1,
                skippedCount: 2,
                skipped: <MovieSubscriptionSkippedItemDto>[
                  MovieSubscriptionSkippedItemDto(
                    movieNumber: 'ABC-002',
                    reason: MovieSubscriptionSkipReason.hasMedia,
                    rawReason: 'has_media',
                  ),
                  MovieSubscriptionSkippedItemDto(
                    movieNumber: 'ABC-003',
                    reason: MovieSubscriptionSkipReason.movieNotFound,
                    rawReason: 'movie_not_found',
                  ),
                ],
              ),
          onSubscriptionsBatchChanged: broadcasts.add,
          fetchPage: (_, __) async => PaginatedResponseDto<MovieListItemDto>(
            items: <MovieListItemDto>[
              _movie(1, isSubscribed: true),
              _movie(2, isSubscribed: true),
            ],
            page: 1,
            pageSize: 24,
            total: 2,
          ),
        );

        await controller.initialize();

        final result = await controller.batchToggleSubscription(
          movieNumbers: const <String>['ABC-001', 'ABC-002', 'ABC-003'],
          subscribe: false,
        );

        expect(result.updatedCount, 1);
        expect(result.skippedHasMediaNumbers, <String>['ABC-002']);
        expect(result.skippedMovieNotFoundNumbers, <String>['ABC-003']);
        // 被 has_media 跳过的 ABC-002 应回滚到 isSubscribed:true。
        expect(controller.items[0].isSubscribed, isFalse);
        expect(controller.items[1].isSubscribed, isTrue);
        // 广播只包含真正被后端接受的项。
        expect(broadcasts, hasLength(1));
        expect(
          broadcasts.single.map((c) => c.movieNumber),
          <String>['ABC-001'],
        );
        expect(broadcasts.single.single.isSubscribed, isFalse);

        controller.dispose();
      },
    );

    test(
      'batchToggleSubscription rolls all optimistic changes back and '
      'returns error message when the request itself fails',
      () async {
        final broadcasts = <List<MovieSubscriptionChange>>[];
        final controller = PagedMovieSummaryController(
          subscribeMovie: ({required movieNumber}) async {},
          unsubscribeMovie:
              ({required movieNumber, deleteMedia = false}) async {},
          batchSubscribeMovies: ({required movieNumbers}) async {
            throw Exception('network boom');
          },
          onSubscriptionsBatchChanged: broadcasts.add,
          fetchPage: (_, __) async => PaginatedResponseDto<MovieListItemDto>(
            items: <MovieListItemDto>[
              _movie(1, isSubscribed: false),
              _movie(2, isSubscribed: false),
            ],
            page: 1,
            pageSize: 24,
            total: 2,
          ),
        );

        await controller.initialize();

        final result = await controller.batchToggleSubscription(
          movieNumbers: const <String>['ABC-001', 'ABC-002'],
          subscribe: true,
        );

        expect(result.hasError, isTrue);
        expect(result.errorMessage, isNotNull);
        expect(result.updatedCount, 0);
        expect(
          controller.items.map((movie) => movie.isSubscribed),
          <bool>[false, false],
        );
        expect(broadcasts, isEmpty);

        controller.dispose();
      },
    );

    test(
      'batchToggleSubscription skips duplicate numbers and short-circuits '
      'without hitting the network when nothing is left',
      () async {
        var called = false;
        final controller = PagedMovieSummaryController(
          subscribeMovie: ({required movieNumber}) async {},
          unsubscribeMovie:
              ({required movieNumber, deleteMedia = false}) async {},
          batchSubscribeMovies: ({required movieNumbers}) async {
            called = true;
            return const MovieSubscriptionBatchResultDto(
              requestedCount: 0,
              updatedCount: 0,
              skippedCount: 0,
              skipped: <MovieSubscriptionSkippedItemDto>[],
            );
          },
          fetchPage: (_, __) async => PaginatedResponseDto<MovieListItemDto>(
            items: const <MovieListItemDto>[],
            page: 1,
            pageSize: 24,
            total: 0,
          ),
        );

        await controller.initialize();

        final result = await controller.batchToggleSubscription(
          movieNumbers: const <String>['', ''],
          subscribe: true,
        );

        expect(called, isFalse);
        expect(result.requestedCount, 0);
        expect(result.updatedCount, 0);

        controller.dispose();
      },
    );

    test(
      'batchToggleSubscription does not broadcast items that were already in '
      'the target state before the call',
      () async {
        final broadcasts = <List<MovieSubscriptionChange>>[];
        final controller = PagedMovieSummaryController(
          subscribeMovie: ({required movieNumber}) async {},
          unsubscribeMovie:
              ({required movieNumber, deleteMedia = false}) async {},
          batchSubscribeMovies: ({required movieNumbers}) async {
            expect(movieNumbers, <String>['ABC-001', 'ABC-002']);
            return const MovieSubscriptionBatchResultDto(
              requestedCount: 2,
              updatedCount: 1,
              skippedCount: 0,
              skipped: <MovieSubscriptionSkippedItemDto>[],
            );
          },
          onSubscriptionsBatchChanged: broadcasts.add,
          fetchPage: (_, __) async => PaginatedResponseDto<MovieListItemDto>(
            items: <MovieListItemDto>[
              _movie(1, isSubscribed: true), // 已订阅，等价空操作
              _movie(2, isSubscribed: false),
            ],
            page: 1,
            pageSize: 24,
            total: 2,
          ),
        );

        await controller.initialize();

        await controller.batchToggleSubscription(
          movieNumbers: const <String>['ABC-001', 'ABC-002'],
          subscribe: true,
        );

        expect(broadcasts, hasLength(1));
        expect(
          broadcasts.single.map((c) => c.movieNumber),
          <String>['ABC-002'],
        );

        controller.dispose();
      },
    );

    test(
      'applySubscriptionChange removes movie when unsubscribed filter requires removal',
      () async {
        final controller = PagedMovieSummaryController(
          subscribeMovie: ({required movieNumber}) async {},
          unsubscribeMovie:
              ({required movieNumber, deleteMedia = false}) async {},
          fetchPage:
              (_, __) async => PaginatedResponseDto<MovieListItemDto>(
                items: <MovieListItemDto>[
                  _movie(1, isSubscribed: true),
                  _movie(2, isSubscribed: true),
                ],
                page: 1,
                pageSize: 24,
                total: 2,
              ),
        );

        await controller.initialize();
        controller.applySubscriptionChange(
          movieNumber: 'ABC-001',
          isSubscribed: false,
          removeIfUnsubscribed: true,
        );

        expect(controller.items.map((movie) => movie.movieNumber), <String>[
          'ABC-002',
        ]);
        expect(controller.total, 1);

        controller.dispose();
      },
    );
  });
}

List<MovieListItemDto> _movies(int start, int count) {
  return List<MovieListItemDto>.generate(
    count,
    (index) => MovieListItemDto(
      javdbId: 'movie-${start + index}',
      movieNumber: 'ABC-${(start + index).toString().padLeft(3, '0')}',
      title: 'Movie ${start + index}',
      coverImage: null,
      releaseDate: null,
      durationMinutes: 120,
      heat: start + index,
      canPlay: true,
      isSubscribed: index.isEven,
    ),
    growable: false,
  );
}

MovieListItemDto _movie(int index, {required bool isSubscribed}) {
  return MovieListItemDto(
    javdbId: 'movie-$index',
    movieNumber: 'ABC-${index.toString().padLeft(3, '0')}',
    title: 'Movie $index',
    coverImage: null,
    releaseDate: null,
    durationMinutes: 120,
    heat: index,
    canPlay: true,
    isSubscribed: isSubscribed,
  );
}
