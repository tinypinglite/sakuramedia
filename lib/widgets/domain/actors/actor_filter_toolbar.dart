import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_filter_sections.dart';

class ActorFilterToolbar extends StatelessWidget {
  const ActorFilterToolbar({
    super.key,
    required this.filterState,
    required this.onChanged,
    required this.onReset,
  });

  final ActorFilterState filterState;
  final ValueChanged<ActorFilterState> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return AppFilterPopover(
      triggerLabel: filterState.triggerLabel,
      labelKey: const Key('actors-filter-trigger-label'),
      panelKey: const Key('actors-filter-panel'),
      isSelected: !filterState.isDefault,
      panelExtraWidth: 180,
      panelBuilder: (_) => ActorFilterSectionGroup(
        filterState: filterState,
        onChanged: onChanged,
      ),
      footer: AppFilterPanelFooter(
        isDefault: filterState.isDefault,
        onReset: onReset,
      ),
    );
  }
}
