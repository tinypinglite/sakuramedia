import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/widgets/actors/actor_filter_sections.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';

/// 弹出移动端演员筛选底部抽屉，确定才生效。返回 `null` 表示取消。
Future<ActorFilterState?> showMobileActorFilterDrawer(
  BuildContext context, {
  required ActorFilterState current,
}) {
  return showAppBottomDrawer<ActorFilterState>(
    context: context,
    drawerKey: const Key('mobile-actors-filter-drawer'),
    maxHeightFactor: 0.6,
    builder: (sheetContext) => _MobileActorFilterDrawerContent(current: current),
  );
}

class _MobileActorFilterDrawerContent extends StatefulWidget {
  const _MobileActorFilterDrawerContent({required this.current});

  final ActorFilterState current;

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

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      title: '筛选',
      resetButtonKey: const Key('mobile-actors-filter-drawer-reset'),
      confirmButtonKey: const Key('mobile-actors-filter-drawer-confirm'),
      onReset: _local.isDefault
          ? null
          : () => setState(() => _local = ActorFilterState.initial),
      onConfirm: () => Navigator.of(context).pop(_local),
      child: ActorFilterSectionGroup(
        filterState: _local,
        onChanged: (next) => setState(() => _local = next),
      ),
    );
  }
}
