import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_filter_sections.dart';

/// 弹出移动端演员筛选底部抽屉。内容与行为对齐桌面女优页 `AppListHeader` 的就地
/// 浮层面板（同一个 `ActorFilterSectionGroup`），见 `showMobileMovieFilterDrawer`
/// 的说明。
Future<void> showMobileActorFilterDrawer(
  BuildContext context, {
  required ActorFilterState current,
  required ValueChanged<ActorFilterState> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-actors-filter-drawer'),
    maxHeightFactor: 0.6,
    builder:
        (sheetContext) => _MobileActorFilterDrawerContent(
          current: current,
          onChanged: onChanged,
        ),
  );
}

class _MobileActorFilterDrawerContent extends StatefulWidget {
  const _MobileActorFilterDrawerContent({
    required this.current,
    required this.onChanged,
  });

  final ActorFilterState current;
  final ValueChanged<ActorFilterState> onChanged;

  @override
  State<_MobileActorFilterDrawerContent> createState() =>
      _MobileActorFilterDrawerContentState();
}

class _MobileActorFilterDrawerContentState
    extends State<_MobileActorFilterDrawerContent> {
  late ActorFilterState _local;

  @override
  void initState() {
    super.initState();
    _local = widget.current;
  }

  void _apply(ActorFilterState next) {
    setState(() => _local = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      scrollViewKey: const Key('mobile-actors-filter-scroll-view'),
      footer: AppFilterPanelFooter(
        isDefault: _local.isDefault,
        onReset: () => _apply(ActorFilterState.initial),
      ),
      child: ActorFilterSectionGroup(filterState: _local, onChanged: _apply),
    );
  }
}
