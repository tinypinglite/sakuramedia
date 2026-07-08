export 'package:sakuramedia/features/movies/presentation/controllers/movie_filter_state.dart'
    show SortDirection, SortDirectionX;

enum RankingSortField { rank, heat }

extension RankingSortFieldX on RankingSortField {
  String get apiValue => switch (this) {
        RankingSortField.rank => 'rank',
        RankingSortField.heat => 'heat',
      };

  String get label => switch (this) {
        RankingSortField.rank => '榜单名次',
        RankingSortField.heat => '热度',
      };
}
