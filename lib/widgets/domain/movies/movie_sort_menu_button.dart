import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/navigation/app_sort_menu_button.dart';

/// 影片筛选状态的排序入口适配器。
///
/// 影片库、标签结果、女优详情作品共用同一套字段与「切字段时清空个人评分维度」
/// 规则；外层交互完全交给 [AppSortMenuButton]。
class MovieSortMenuButton extends StatelessWidget {
  const MovieSortMenuButton({
    super.key,
    required this.filterState,
    required this.onChanged,
    this.useDrawer = false,
    this.glassGrouped = false,
    this.iconOnly = false,
    this.triggerKey,
    this.panelKey,
    this.drawerKey,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieFilterState> onChanged;
  final bool useDrawer;
  final bool glassGrouped;
  final bool iconOnly;
  final Key? triggerKey;
  final Key? panelKey;
  final Key? drawerKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppSortMenuButton<MovieSortField>(
      fields: MovieSortField.values,
      selectedField: filterState.sortField,
      fieldLabelBuilder: (value) => value.labelWith(l10n),
      onFieldChanged: (value) => onChanged(
        filterState.copyWith(sortField: value!, dimensionSortId: null),
      ),
      selectedDirection: filterState.sortDirection,
      onDirectionChanged: (value) =>
          onChanged(filterState.copyWith(sortDirection: value)),
      useDrawer: useDrawer,
      glassGrouped: glassGrouped,
      iconOnly: iconOnly,
      triggerKey: triggerKey,
      panelKey: panelKey,
      drawerKey: drawerKey,
      fieldKeyBuilder: (value) => Key('movie-sort-field-${value.name}'),
      directionKeyBuilder: (value) => Key('movie-sort-direction-${value.name}'),
    );
  }
}
