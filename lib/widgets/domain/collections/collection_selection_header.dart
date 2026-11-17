import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';

/// 合集详情页的多选顶栏：桌面内联批量动作，移动端只留退出 / 计数 / 全选。
class CollectionSelectionHeader extends StatelessWidget {
  const CollectionSelectionHeader({
    super.key,
    required this.mobile,
    required this.keyPrefix,
    required this.selectedCount,
    required this.allSelected,
    required this.selectionLabel,
    required this.selectAllLabel,
    required this.deselectAllLabel,
    required this.onToggleAll,
    required this.onExitSelection,
    required this.actions,
    this.countKey,
  });

  final bool mobile;
  final String keyPrefix;
  final int selectedCount;
  final bool allSelected;
  final String selectionLabel;
  final String selectAllLabel;
  final String deselectAllLabel;
  final VoidCallback onToggleAll;
  final VoidCallback onExitSelection;
  final List<AppGlassSelectionAction> actions;
  final Key? countKey;

  @override
  Widget build(BuildContext context) {
    if (mobile) {
      return AppMobileSelectionHeader(
        selectionLabel: selectionLabel,
        countKey: countKey,
        exitKey: Key('$keyPrefix-exit-selection-button'),
        onExitSelection: onExitSelection,
        selectAllKey: Key('$keyPrefix-select-all-button'),
        selectAllTooltip: allSelected ? deselectAllLabel : selectAllLabel,
        onToggleAll: onToggleAll,
      );
    }
    return AppGlassSelectionHeader(
      selectionLabel: selectionLabel,
      countKey: countKey,
      selectAllLabel: allSelected ? deselectAllLabel : selectAllLabel,
      selectAllKey: Key('$keyPrefix-select-all-button'),
      onToggleAll: onToggleAll,
      actions: actions,
      exitKey: Key('$keyPrefix-exit-selection-button'),
      onExitSelection: onExitSelection,
    );
  }
}
