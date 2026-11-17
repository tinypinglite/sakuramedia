import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_summary_card.dart';

/// 累计分页女优列表使用的 Sliver 网格版本。
class ActorSummarySliver extends StatelessWidget {
  const ActorSummarySliver({
    super.key,
    required this.items,
    this.errorMessage,
    this.onErrorRetry,
    this.onActorTap,
    this.onActorSubscriptionTap,
    this.isActorSubscriptionUpdating,
    this.emptyMessage,
  });

  final List<ActorListItemDto> items;
  final String? errorMessage;
  final VoidCallback? onErrorRetry;
  final ValueChanged<ActorListItemDto>? onActorTap;
  final ValueChanged<ActorListItemDto>? onActorSubscriptionTap;
  final bool Function(ActorListItemDto actor)? isActorSubscriptionUpdating;

  /// 空态文案；为 `null` 时使用当前语言的默认文案。
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppAdaptiveCardSliver<ActorListItemDto>(
      gridKey: const Key('actor-summary-grid'),
      items: items,
      errorMessage: errorMessage,
      onErrorRetry: onErrorRetry,
      emptyMessage: emptyMessage ?? l10n.widgetActorEmptyList,
      itemBuilder: (context, actor, index) => ActorSummaryCard(
        actor: actor,
        onTap: onActorTap == null ? null : () => onActorTap!(actor),
        onSubscriptionTap: onActorSubscriptionTap == null
            ? null
            : () => onActorSubscriptionTap!(actor),
        isSubscriptionUpdating:
            isActorSubscriptionUpdating?.call(actor) ?? false,
      ),
    );
  }
}
