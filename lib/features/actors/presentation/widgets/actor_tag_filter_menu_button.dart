import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_tag_filter_provider.dart';
import 'package:sakuramedia/features/actors/presentation/widgets/actor_tag_filter_panel.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';

/// 女优详情作品区的独立标签筛选入口。
///
/// 标签不参与影片条件面板：桌面在操作区展开锚定浮层并显示当前选择摘要，
/// 移动端与排序入口一致，只显示标签图标，点开底部抽屉。
class ActorTagFilterMenuButton extends ConsumerWidget {
  const ActorTagFilterMenuButton({
    super.key,
    required this.actorId,
    this.useDrawer = false,
    this.glassGrouped = false,
    this.triggerKey,
    this.panelKey,
    this.drawerKey,
  });

  final int actorId;
  final bool useDrawer;
  final bool glassGrouped;
  final Key? triggerKey;
  final Key? panelKey;
  final Key? drawerKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (useDrawer) {
      return AppGlassIconButton(
        key: triggerKey,
        tooltip: l10n.widgetTagSelectorTitle,
        icon: Icons.sell_outlined,
        onPressed: () => showAppBottomDrawer<void>(
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
    return AppGlassFilterPopover(
      panelKey: panelKey ?? const Key('actor-tag-filter-panel'),
      scrollable: true,
      showResetFooter: false,
      triggerBuilder: (context, toggle) {
        final trigger = AppGlassHeaderButton(
          key: triggerKey,
          icon: Icons.sell_outlined,
          label: label,
          trailingIcon: Icons.expand_more_rounded,
          tooltip: l10n.widgetTagSelectorTitle,
          onTap: toggle,
        );
        return glassGrouped
            ? trigger
            : AppGlassHeaderGroup(children: <Widget>[trigger]);
      },
      panelBuilder: (context) => ActorTagFilterPanel(actorId: actorId),
    );
  }
}
