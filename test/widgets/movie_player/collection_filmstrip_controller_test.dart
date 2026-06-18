import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/widgets/movie_player/collection_filmstrip_controller.dart';

MovieImageDto _img(int id) => MovieImageDto(
  id: id,
  origin: '/f$id.webp',
  small: '/f$id-s.webp',
  medium: '/f$id-m.webp',
  large: '/f$id-l.webp',
);

/// 构造「每集帧」：传入每集的 offset 列表，按集生成 (offset, image)。
CollectionEpisodeFrameLoader _loaderFrom(
  List<List<int>> offsetsPerEpisode, {
  Set<int> failEpisodes = const <int>{},
}) {
  return (episodeIndex) async {
    if (failEpisodes.contains(episodeIndex)) {
      throw Exception('boom $episodeIndex');
    }
    final offsets = offsetsPerEpisode[episodeIndex];
    var imageId = episodeIndex * 100;
    return offsets
        .map(
          (offset) =>
              (offsetSeconds: offset, image: _img(imageId++)),
        )
        .toList();
  };
}

void main() {
  test('按集顺序无缝拼接全局帧序列（升序追加）', () async {
    final controller = CollectionFilmstripController(
      episodeCount: 3,
      frameLoader: _loaderFrom(<List<int>>[
        <int>[0, 10, 20],
        <int>[0, 15],
        <int>[0, 30, 60, 90],
      ]),
    );
    addTearDown(controller.dispose);

    await controller.start();

    // 3 + 2 + 4 = 9 帧，按 (集, offset) 顺序拼接。
    expect(controller.thumbnails, hasLength(9));
    expect(controller.loadedEpisodeCount, 3);
    expect(controller.isLoading, isFalse);

    // 第 2 集（index 1）的两帧落在全局 3、4；第 3 集起始全局 5。
    expect(controller.resolveTarget(3)?.episodeIndex, 1);
    expect(controller.resolveTarget(3)?.offsetSeconds, 0);
    expect(controller.resolveTarget(4)?.offsetSeconds, 15);
    expect(controller.resolveTarget(5)?.episodeIndex, 2);
    expect(controller.resolveTarget(5)?.offsetSeconds, 0);
    expect(controller.resolveTarget(8)?.offsetSeconds, 90);
    expect(controller.resolveTarget(9), isNull);
  });

  test('start(priorityEpisode) 优先加载起播集，其余集再按下标补齐', () async {
    final loadOrder = <int>[];
    final controller = CollectionFilmstripController(
      episodeCount: 4,
      frameLoader: (episodeIndex) async {
        loadOrder.add(episodeIndex);
        return <({int offsetSeconds, MovieImageDto image})>[
          (offsetSeconds: 0, image: _img(episodeIndex)),
        ];
      },
    );
    addTearDown(controller.dispose);

    await controller.start(priorityEpisode: 2);

    // 起播集 2 最先加载，其余按 0,1,3 补齐。
    expect(loadOrder, <int>[2, 0, 1, 3]);
    // 全局序列仍按集下标排列（与加载顺序解耦）。
    expect(controller.thumbnails, hasLength(4));
    expect(controller.resolveTarget(2)?.episodeIndex, 2);
  });

  test('播放位置早于该集首帧 offset 时不高亮（无满足项）', () async {
    final controller = CollectionFilmstripController(
      episodeCount: 1,
      frameLoader: _loaderFrom(<List<int>>[
        <int>[30, 60, 90],
      ]),
    );
    addTearDown(controller.dispose);
    await controller.start();

    // 位置 5 早于首帧 offset 30 → 无满足项，activeIndex 为 null。
    controller.updatePosition(0, 5);
    expect(controller.activeIndex.value, isNull);

    // 位置到达首帧后正常高亮。
    controller.updatePosition(0, 30);
    expect(controller.activeIndex.value, 0);
  });

  test('updatePosition 在所属集帧段内取 offset<=position 的最后一帧', () async {
    final controller = CollectionFilmstripController(
      episodeCount: 3,
      frameLoader: _loaderFrom(<List<int>>[
        <int>[0, 10, 20],
        <int>[0, 15],
        <int>[0, 30, 60, 90],
      ]),
    );
    addTearDown(controller.dispose);
    await controller.start();

    // 第 1 集（全局 0..2）位置 12 → offset<=12 的最后一帧是 offset 10（全局 1）。
    controller.updatePosition(0, 12);
    expect(controller.activeIndex.value, 1);

    // 位置 25 → 最后一帧 offset 20（全局 2）。
    controller.updatePosition(0, 25);
    expect(controller.activeIndex.value, 2);

    // 第 3 集（全局 5..8）位置 65 → offset 60（全局 5+2=7）。
    controller.updatePosition(2, 65);
    expect(controller.activeIndex.value, 7);

    // 位置 0 落在该集首帧。
    controller.updatePosition(2, 0);
    expect(controller.activeIndex.value, 5);
  });

  test('单集失败/空帧静默跳过，不计入帧段但占一个 episode', () async {
    final controller = CollectionFilmstripController(
      episodeCount: 3,
      frameLoader: _loaderFrom(
        <List<int>>[
          <int>[0, 10],
          <int>[], // 空帧（如来源已删切片）
          <int>[0, 30],
        ],
        failEpisodes: <int>{}, // 不用异常，直接给空
      ),
    );
    addTearDown(controller.dispose);
    await controller.start();

    // 2 + 0 + 2 = 4 帧；第 3 集帧紧接第 1 集（中间空集不占全局位置）。
    expect(controller.thumbnails, hasLength(4));
    expect(controller.resolveTarget(2)?.episodeIndex, 2);
    expect(controller.resolveTarget(2)?.offsetSeconds, 0);

    // 当前播放停在空帧的中间集 → 无活动帧。
    controller.updatePosition(1, 5);
    expect(controller.activeIndex.value, isNull);
  });

  test('loader 抛异常的集等价于空帧段，不影响其它集', () async {
    final controller = CollectionFilmstripController(
      episodeCount: 2,
      frameLoader: _loaderFrom(
        <List<int>>[
          <int>[0, 10],
          <int>[0, 20],
        ],
        failEpisodes: <int>{0},
      ),
    );
    addTearDown(controller.dispose);
    await controller.start();

    // 第 1 集抛错 → 仅第 2 集 2 帧。
    expect(controller.thumbnails, hasLength(2));
    expect(controller.resolveTarget(0)?.episodeIndex, 1);
    expect(controller.loadedEpisodeCount, 2);
    expect(controller.isLoading, isFalse);
  });

  test('空合集：无帧、非 loading', () async {
    final controller = CollectionFilmstripController(
      episodeCount: 0,
      frameLoader: _loaderFrom(const <List<int>>[]),
    );
    addTearDown(controller.dispose);
    await controller.start();

    expect(controller.thumbnails, isEmpty);
    expect(controller.isLoading, isFalse);
    expect(controller.resolveTarget(0), isNull);
  });

  test('列数自动/手动与滚动锁切换', () async {
    final controller = CollectionFilmstripController(
      episodeCount: 1,
      frameLoader: _loaderFrom(<List<int>>[
        <int>[0],
      ]),
    );
    addTearDown(controller.dispose);

    expect(controller.usesAutoColumns, isTrue);
    expect(controller.isScrollLocked, isTrue);

    controller.applyAutoColumns(4);
    expect(controller.columns, 4);
    expect(controller.usesAutoColumns, isTrue);

    controller.setColumns(3);
    expect(controller.columns, 3);
    expect(controller.usesAutoColumns, isFalse);
    // 手动后自动解析不再覆盖。
    controller.applyAutoColumns(5);
    expect(controller.columns, 3);

    controller.toggleScrollLock();
    expect(controller.isScrollLocked, isFalse);
  });
}
