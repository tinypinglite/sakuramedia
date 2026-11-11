import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 排行榜加载态占位数据：真实 DTO + [BoneMock] 文案，
/// 供 `AppSkeletonizer` 渲染与真实卡片同形的静态骨架。
List<RankedMovieListItemDto> rankedMoviePlaceholders({int count = 8}) {
  return List<RankedMovieListItemDto>.generate(
    count,
    (index) => RankedMovieListItemDto(
      rank: index + 1,
      movieNumber: 'ABC-${(index + 1).toString().padLeft(3, '0')}',
      title: BoneMock.words(3),
      coverImage: null,
      releaseDate: null,
      durationMinutes: 120,
      heat: 0,
      isSubscribed: false,
      canPlay: false,
    ),
    growable: false,
  );
}

/// 切换来源、榜单列表还在飞时的占位项，供筛选面板的榜单分节渲染骨架。
List<RankingBoardDto> rankingBoardPlaceholders({int count = 3}) {
  return List<RankingBoardDto>.generate(
    count,
    (index) => RankingBoardDto(
      sourceKey: 'placeholder-source',
      boardKey: 'placeholder-board-$index',
      name: BoneMock.words(index.isEven ? 1 : 2),
      supportedPeriods: const <String>[],
      defaultPeriod: null,
    ),
    growable: false,
  );
}

/// 榜单周期占位：真实周期标签长度相近，骨架宽度不跳。
List<String> rankingPeriodPlaceholders() {
  return const <String>['daily', 'weekly', 'monthly'];
}
