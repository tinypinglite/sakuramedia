import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/missav_thumbnail_result_dto.dart';
import 'package:sakuramedia/features/movies/data/missav_thumbnail_stream_update.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_missav_thumbnail_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('controller starts idle before user requests missav thumbnails', () {
    final controller = MovieDetailMissavThumbnailController(
      movieNumber: 'SSNI-888',
      fetchMissavThumbnailsStream:
          ({required movieNumber, refresh = false}) => const Stream.empty(),
    );
    addTearDown(controller.dispose);

    expect(controller.state, MovieDetailMissavThumbnailState.idle);
    expect(controller.items, isEmpty);
    expect(controller.status, isNull);
    expect(
      controller.selectedIntervalSeconds,
      MovieDetailMissavThumbnailController.defaultIntervalSeconds,
    );
  });

  test('load resolves success state with missav items', () async {
    final controller = MovieDetailMissavThumbnailController(
      movieNumber: 'SSNI-888',
      fetchMissavThumbnailsStream:
          ({required movieNumber, refresh = false}) =>
              Stream.fromIterable(<MissavThumbnailStreamUpdate>[
                const MissavThumbnailStreamUpdate(
                  stage: 'search_started',
                  message: '正在获取 MissAV 缩略图',
                ),
                MissavThumbnailStreamUpdate(
                  stage: 'completed',
                  message: 'MissAV 缩略图获取完成',
                  success: true,
                  result: const MissavThumbnailResultDto(
                    movieNumber: 'SSNI-888',
                    source: 'missav',
                    total: 2,
                    items: <MissavThumbnailItemDto>[
                      MissavThumbnailItemDto(index: 0, url: '/missav-0.jpg'),
                      MissavThumbnailItemDto(index: 1, url: '/missav-1.jpg'),
                    ],
                  ),
                ),
              ]),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state, MovieDetailMissavThumbnailState.success);
    expect(controller.items, hasLength(1));
    expect(controller.items.single.index, 0);
    expect(controller.activeIndex, 0);
    expect(controller.errorMessage, isNull);
  });

  test(
    'load resolves empty state when completed result has no items',
    () async {
      final controller = MovieDetailMissavThumbnailController(
        movieNumber: 'SSNI-888',
        fetchMissavThumbnailsStream:
            ({required movieNumber, refresh = false}) =>
                Stream.fromIterable(<MissavThumbnailStreamUpdate>[
                  MissavThumbnailStreamUpdate(
                    stage: 'completed',
                    message: 'MissAV 缩略图获取完成',
                    success: true,
                    result: const MissavThumbnailResultDto(
                      movieNumber: 'SSNI-888',
                      source: 'missav',
                      total: 0,
                      items: <MissavThumbnailItemDto>[],
                    ),
                  ),
                ]),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state, MovieDetailMissavThumbnailState.empty);
      expect(controller.items, isEmpty);
      expect(controller.activeIndex, isNull);
    },
  );

  test('load resolves completed failure into error state', () async {
    final controller = MovieDetailMissavThumbnailController(
      movieNumber: 'SSNI-888',
      fetchMissavThumbnailsStream:
          ({required movieNumber, refresh = false}) =>
              Stream.fromIterable(<MissavThumbnailStreamUpdate>[
                const MissavThumbnailStreamUpdate(
                  stage: 'completed',
                  message: 'MissAV 缩略图获取失败',
                  success: false,
                  reason: 'missav_thumbnail_not_found',
                  detail: 'thumbnail config missing',
                ),
              ]),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state, MovieDetailMissavThumbnailState.error);
    expect(controller.items, isEmpty);
    expect(controller.errorMessage, 'thumbnail config missing');
  });

  test('load maps stream exception into error state', () async {
    final controller = MovieDetailMissavThumbnailController(
      movieNumber: 'SSNI-888',
      fetchMissavThumbnailsStream:
          ({required movieNumber, refresh = false}) =>
              Stream<MissavThumbnailStreamUpdate>.error(Exception('boom')),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state, MovieDetailMissavThumbnailState.error);
    expect(controller.errorMessage, 'MissAV 缩略图获取失败，请稍后重试。');
  });

  test(
    'load ignores duplicate requests while current stream is running',
    () async {
      final streamController = StreamController<MissavThumbnailStreamUpdate>();
      var requestCount = 0;
      final controller = MovieDetailMissavThumbnailController(
        movieNumber: 'SSNI-888',
        fetchMissavThumbnailsStream: ({required movieNumber, refresh = false}) {
          requestCount += 1;
          return streamController.stream;
        },
      );
      addTearDown(() async {
        await streamController.close();
        controller.dispose();
      });

      unawaited(controller.load());
      await Future<void>.delayed(Duration.zero);
      unawaited(controller.load());
      await Future<void>.delayed(Duration.zero);

      expect(requestCount, 1);
      expect(controller.state, MovieDetailMissavThumbnailState.loading);

      streamController.add(
        MissavThumbnailStreamUpdate(
          stage: 'completed',
          message: 'MissAV 缩略图获取完成',
          success: true,
          result: const MissavThumbnailResultDto(
            movieNumber: 'SSNI-888',
            source: 'missav',
            total: 1,
            items: <MissavThumbnailItemDto>[
              MissavThumbnailItemDto(index: 0, url: '/missav-0.jpg'),
            ],
          ),
        ),
      );
      await streamController.close();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state, MovieDetailMissavThumbnailState.success);
    },
  );

  test(
    'setIntervalSeconds filters missav thumbnails from the first frame by stride',
    () async {
      final controller = MovieDetailMissavThumbnailController(
        movieNumber: 'SSNI-888',
        fetchMissavThumbnailsStream:
            ({required movieNumber, refresh = false}) =>
                Stream.fromIterable(<MissavThumbnailStreamUpdate>[
                  MissavThumbnailStreamUpdate(
                    stage: 'completed',
                    message: 'MissAV 缩略图获取完成',
                    success: true,
                    result: MissavThumbnailResultDto(
                      movieNumber: 'SSNI-888',
                      source: 'missav',
                      total: 12,
                      items: List<MissavThumbnailItemDto>.generate(
                        12,
                        (index) => MissavThumbnailItemDto(
                          index: index,
                          url: '/missav-$index.jpg',
                        ),
                      ),
                    ),
                  ),
                ]),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.items.map((item) => item.index).toList(), <int>[
        0,
        5,
        10,
      ]);

      controller.setIntervalSeconds(20);

      expect(controller.selectedIntervalSeconds, 20);
      expect(controller.items.map((item) => item.index).toList(), <int>[0, 10]);
    },
  );

  test(
    'setIntervalSeconds resets active index when current missav item is filtered out',
    () async {
      final controller = MovieDetailMissavThumbnailController(
        movieNumber: 'SSNI-888',
        fetchMissavThumbnailsStream:
            ({required movieNumber, refresh = false}) =>
                Stream.fromIterable(<MissavThumbnailStreamUpdate>[
                  MissavThumbnailStreamUpdate(
                    stage: 'completed',
                    message: 'MissAV 缩略图获取完成',
                    success: true,
                    result: MissavThumbnailResultDto(
                      movieNumber: 'SSNI-888',
                      source: 'missav',
                      total: 12,
                      items: List<MissavThumbnailItemDto>.generate(
                        12,
                        (index) => MissavThumbnailItemDto(
                          index: index,
                          url: '/missav-$index.jpg',
                        ),
                      ),
                    ),
                  ),
                ]),
      );
      addTearDown(controller.dispose);

      await controller.load();
      controller.selectIndex(1);

      controller.setIntervalSeconds(20);

      expect(controller.activeIndex, 0);
      expect(controller.items.first.index, 0);
    },
  );
}
