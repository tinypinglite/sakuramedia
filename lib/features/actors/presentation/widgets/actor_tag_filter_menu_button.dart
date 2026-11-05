import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_tag_filter_provider.dart';
import 'package:sakuramedia/features/actors/presentation/widgets/actor_tag_filter_panel.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/navigation/app_filter_entry_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';

/// 女优详情作品区的独立标签筛选入口。
///
/// 标签不参与影片条件面板：桌面在操作区展开锚定浮层并显示当前选择摘要，
/// 移动端与排序入口一致，只显示标签图标，点开底部抽屉。
class ActorTagFilterMenuButton extends ConsumerWidget {
  const ActorTagFilterMenuButton({
    super.key,
    required this.actorId,
    this.useDrawer = false,
    this.triggerKey,
    this.panelKey,
    this.drawerKey,
  });

  final int actorId;
  final bool useDrawer;
  final Key? triggerKey;
  final Key? panelKey;
  final Key? drawerKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (useDrawer) {
      return AppFilterEntryButton(
        key: triggerKey,
        icon: Icons.sell_outlined,
        tooltip: l10n.widgetTagSelectorTitle,
        onTap: () => showAppBottomDrawer<void>(
          context: context,
          drawerKey: drawerKey,
          maxHeightFactor: 0.6,
          builder: (sheetContext) => AppMobileFilterDrawerScaffold(
            child: ActorTagFilterPanel(actorId: actorId),
          ),
        ),
      );
    }

    final selection = ref.watch(actorTagFilterProvider(actorId));
    final label = selection.hasSelection
        ? l10n.actorTagFilterLabel(selection.selectedCount)
        : l10n.widgetTagFilterTitle;
    return AppFilterPopover(
      triggerLabel: label,
      panelKey: panelKey ?? const Key('actor-tag-filter-panel'),
      panelExtraWidth: 260,
      triggerBuilder: (context, isOpen, toggle) => AppFilterEntryButton(
        key: triggerKey,
        icon: Icons.sell_outlined,
        label: label,
        tooltip: l10n.widgetTagSelectorTitle,
        trailingIcon: isOpen
            ? Icons.expand_less_rounded
            : Icons.expand_more_rounded,
        onTap: toggle,
      ),
      panelBuilder: (context) => ActorTagFilterPanel(actorId: actorId),
    );
  }
}
