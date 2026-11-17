import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/features/subscriptions/presentation/movie_subscription_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/navigation/app_sort_menu_button.dart';

/// 订阅管理列表的排序入口适配器。
///
/// 「没找到次数」只有多到少，选中时隐藏方向分节。
class MovieSubscriptionSortMenuButton extends StatelessWidget {
  const MovieSubscriptionSortMenuButton({
    super.key,
    required this.filterState,
    required this.onChanged,
    this.useDrawer = false,
    this.glassGrouped = false,
    this.iconOnly = false,
    this.keyPrefix = 'movie-subscriptions',
    this.triggerKey,
    this.panelKey,
    this.drawerKey,
  });

  final MovieSubscriptionFilterState filterState;
  final ValueChanged<MovieSubscriptionFilterState> onChanged;
  final bool useDrawer;
  final bool glassGrouped;
  final bool iconOnly;
  final String keyPrefix;
  final Key? triggerKey;
  final Key? panelKey;
  final Key? drawerKey;

  @override
  Widget build(BuildContext context) {
    return AppSortMenuButton<MovieSubscriptionSortField>(
      fields: MovieSubscriptionSortField.values,
      selectedField: filterState.sortField,
      fieldLabelBuilder: (value) => value.label(AppLocalizations.of(context)),
      onFieldChanged: (value) => onChanged(filterState.withSortField(value!)),
      selectedDirection: filterState.sortDirection,
      onDirectionChanged: (value) =>
          onChanged(filterState.withSortDirection(value)),
      directionVisibleWhen: (field) => field?.supportsDirection ?? false,
      useDrawer: useDrawer,
      glassGrouped: glassGrouped,
      iconOnly: iconOnly,
      triggerKey: triggerKey,
      panelKey: panelKey,
      drawerKey: drawerKey,
      fieldKeyBuilder: (value) => Key('$keyPrefix-sort-field-${value.name}'),
      directionKeyBuilder: (value) =>
          Key('$keyPrefix-sort-direction-${value.name}'),
    );
  }
}
