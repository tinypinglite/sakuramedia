import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_controller.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/use_selection_controller.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';

/// 重复媒体 / 多版本影片共用的组内多选。
///
/// 组卡里每个文件都可独立选，但任何一组都必须至少保留一个文件。范围选择同样
/// 受这条约束限制，避免 Shift 一次勾掉整组。
SelectionController<int> useMediaGroupSelection<T>({
  required List<T> Function() currentGroups,
  required List<MediaListItemDto> Function(T group) itemsOf,
}) {
  final controller = useSelectionController<int>(
    orderedIds: () => currentGroups()
        .expand(itemsOf)
        .map((item) => item.id)
        .toList(growable: false),
    policy: SelectionPolicy<int>(
      canSelect: (id, selected) {
        for (final group in currentGroups()) {
          final ids = itemsOf(
            group,
          ).map((item) => item.id).toList(growable: false);
          if (!ids.contains(id)) continue;
          final selectedInGroup = ids.where(selected.contains).length;
          return selectedInGroup < ids.length - 1;
        }
        return false;
      },
    ),
  );
  useListenable(controller);
  return controller;
}

List<MediaListItemDto> selectedMediaGroupItems<T>({
  required Iterable<T> groups,
  required List<MediaListItemDto> Function(T group) itemsOf,
  required Set<int> selectedIds,
}) {
  return [
    for (final group in groups)
      for (final item in itemsOf(group))
        if (selectedIds.contains(item.id)) item,
  ];
}

/// 重复媒体 / 多版本影片共用的多选态与批量删除。
typedef MediaGroupBatchSelection = ({
  bool selectionMode,
  Set<int> selectedIds,
  int selectedCount,
  bool deleting,
  String keyBase,
  VoidCallback enterSelection,
  VoidCallback clearSelection,
  VoidCallback exitSelection,
  ValueChanged<MediaListItemDto> toggle,
  Future<void> Function() deleteSelected,
});

extension MediaGroupBatchSelectionUi on MediaGroupBatchSelection {
  bool get canAct => !deleting && selectedCount > 0;

  Widget buildHeader(BuildContext context, {required bool mobile}) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.mediaListSelectedCopies(selectedCount);
    if (mobile) {
      return AppMobileSelectionHeader(
        selectionLabel: label,
        countKey: Key('$keyBase-selected-count'),
        selectAllTooltip: l10n.mediaListClearSelection,
        selectAllKey: Key('$keyBase-clear-selection'),
        onToggleAll: canAct ? clearSelection : null,
        exitKey: Key('$keyBase-exit-selection'),
        onExitSelection: deleting ? null : exitSelection,
      );
    }
    return AppGlassSelectionHeader(
      selectionLabel: label,
      countKey: Key('$keyBase-selected-count'),
      selectAllLabel: l10n.mediaListClearSelection,
      selectAllKey: Key('$keyBase-clear-selection'),
      onToggleAll: canAct ? clearSelection : null,
      exitKey: Key('$keyBase-exit-selection'),
      onExitSelection: deleting ? null : exitSelection,
      actions: [
        AppGlassSelectionAction(
          key: Key('$keyBase-batch-delete'),
          label: l10n.mediaListBatchDeleteSelected,
          icon: Icons.delete_outline_rounded,
          foregroundColor: context.appTextPalette.error,
          onTap: canAct ? () => unawaited(deleteSelected()) : null,
        ),
      ],
    );
  }

  Widget buildBottomBar(BuildContext context) => AppSelectionBottomBar(
    actions: [
      AppButton(
        key: Key('$keyBase-batch-delete'),
        label: AppLocalizations.of(context).mediaListBatchDeleteSelected,
        icon: const Icon(Icons.delete_outline_rounded),
        variant: AppButtonVariant.danger,
        isLoading: deleting,
        onPressed: canAct ? () => unawaited(deleteSelected()) : null,
      ),
    ],
  );
}

MediaGroupBatchSelection useMediaGroupBatchSelection<T>({
  required BuildContext context,
  required WidgetRef ref,
  required List<T> groups,
  required List<MediaListItemDto> Function(T group) itemsOf,
  required List<T> Function() currentGroups,
  required String keyBase,
  required String confirmTitle,
  required String Function(int count) confirmMessage,
  required String changedMessage,
}) {
  final selection = useMediaGroupSelection<T>(
    currentGroups: currentGroups,
    itemsOf: itemsOf,
  );
  final busy = useState(false);
  final picked = selectedMediaGroupItems(
    groups: groups,
    itemsOf: itemsOf,
    selectedIds: selection.selectedIds,
  );

  Future<void> deleteSelected() async {
    if (busy.value || picked.isEmpty) return;
    final confirmed = await showAppConfirmDialog(
      context,
      title: confirmTitle,
      message: confirmMessage(picked.length),
      confirmLabel: AppLocalizations.of(context).commonDelete,
      danger: true,
      dialogKey: Key('$keyBase-batch-confirm-dialog'),
      confirmKey: Key('$keyBase-batch-confirm'),
    );
    if (!confirmed || !context.mounted) return;
    final latest = currentGroups();
    final targets = picked.map((item) => item.id).toSet();
    final latestIds = latest.expand(itemsOf).map((i) => i.id).toSet();
    bool allIn(T group) => itemsOf(group).every((i) => targets.contains(i.id));
    if (!latestIds.containsAll(targets) || latest.any(allIn)) {
      selection.exitSelection();
      showToast(changedMessage, tone: AppToastTone.success);
      return;
    }
    busy.value = true;
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.mediaDelete,
      ids: targets.toList(growable: false),
    );
    if (!context.mounted) return;
    busy.value = false;
    if (submitted) selection.exitSelection();
  }

  return (
    selectionMode: selection.active,
    selectedIds: selection.selectedIds,
    selectedCount: picked.length,
    deleting: busy.value,
    keyBase: keyBase,
    enterSelection: selection.enterSelection,
    clearSelection: selection.clearSelection,
    exitSelection: selection.exitSelection,
    toggle: (item) => selection.handleSelectionTap(item.id),
    deleteSelected: deleteSelected,
  );
}
