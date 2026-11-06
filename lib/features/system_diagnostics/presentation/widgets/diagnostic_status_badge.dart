import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';

/// 7 态状态徽章 —— 覆盖单项和大类聚合两种使用场景。
///
/// 这里独立成组件是因为多了 `blocked` 一态，且不需要 chip 的点击/tooltip
/// 交互。
class DiagnosticStatusBadge extends StatelessWidget {
  const DiagnosticStatusBadge({
    super.key,
    required this.label,
    required this.status,
    this.detail,
    this.dense = false,
  });

  final String label;
  final DiagnosticItemStatus status;
  final String? detail;

  /// [dense]=true 用在横条 chip 阵列（矮一点、字更紧）。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AppStatusChip(
      label: label,
      palette: _resolvePalette(status),
      isBusy: status == DiagnosticItemStatus.probing,
      detail: detail,
      dense: dense,
    );
  }

  AppStatusChipPalette _resolvePalette(DiagnosticItemStatus status) {
    switch (status) {
      case DiagnosticItemStatus.disabled:
      case DiagnosticItemStatus.notTested:
        return AppStatusChipPalette.forSemantic(AppStatusSemantic.neutral);
      case DiagnosticItemStatus.probing:
        return AppStatusChipPalette.forSemantic(
          AppStatusSemantic.neutral,
          icon: Icons.hourglass_top,
        );
      case DiagnosticItemStatus.healthy:
        return AppStatusChipPalette.forSemantic(AppStatusSemantic.success);
      case DiagnosticItemStatus.warning:
        return AppStatusChipPalette.forSemantic(AppStatusSemantic.warning);
      case DiagnosticItemStatus.unhealthy:
        return AppStatusChipPalette.forSemantic(AppStatusSemantic.error);
      case DiagnosticItemStatus.blocked:
        return AppStatusChipPalette.forSemantic(AppStatusSemantic.muted);
    }
  }
}
