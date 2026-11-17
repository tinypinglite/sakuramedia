import 'package:sakuramedia/l10n/app_localizations.dart';

export 'package:sakuramedia/features/shared/data/sort_direction.dart'
    show SortDirection, SortDirectionX;

enum RankingSortField {
  rank,
  heat,
}

extension RankingSortFieldX on RankingSortField {
  String get apiValue => switch (this) {
    RankingSortField.rank => 'rank',
    RankingSortField.heat => 'heat',
  };

  /// 排序字段的展示文案，按当前语言渲染。
  String label(AppLocalizations l10n) => switch (this) {
    RankingSortField.rank => l10n.rankingSortFieldRank,
    RankingSortField.heat => l10n.sharedInteractionHeat,
  };
}
