import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/relative_time_label.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/controllers/system_diagnostics_controller.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

/// 概览 Hero 右上角的组件诊断入口。
///
/// 未检测 / 正常时只保留一枚状态 chip 和一个动作按钮；异常时 chip 直接切换
/// 为 warning / error 语义色，不再独占页面第一行。详细结果仍进入独立诊断页。
///
/// 通过 autoDispose family provider 持有概览侧自己的诊断会话；诊断页使用另一
/// host 参数，所以两处状态互不共享。
class SystemDiagnosticsStrip extends ConsumerStatefulWidget {
  const SystemDiagnosticsStrip({super.key});

  @override
  ConsumerState<SystemDiagnosticsStrip> createState() =>
      _SystemDiagnosticsStripState();
}

class _SystemDiagnosticsStripState
    extends ConsumerState<SystemDiagnosticsStrip> {
  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(
      systemDiagnosticsProvider(SystemDiagnosticsHost.overviewStrip),
    );
    final status = _statusPresentation(context, state);
    final checkedAt = state.lastRunAt == null
        ? null
        : l10n.lastCheckedRelative(
            formatRelativeTimeLabel(state.lastRunAt!, l10n: l10n),
          );
    final tooltip = <String>[
      l10n.systemDiagnosticsComponentTitle,
      status.label,
      ?checkedAt,
      l10n.systemDiagnosticsOpenPage,
    ].join(' · ');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: tooltip,
          child: AppInteractiveSurface(
            key: const Key('system-diagnostics-strip-open'),
            onTap: () => DesktopRoutes.systemDiagnostics().push(context),
            semanticLabel: l10n.systemDiagnosticsOpenPage,
            child: AppStatusChip(
              key: const Key('system-diagnostics-strip'),
              label: l10n.systemDiagnosticsComponentTitle,
              detail: state.isRunning
                  ? '${state.completedItemCount}/${state.totalItemCount}'
                  : status.label,
              palette: status.palette,
              isBusy: state.isRunning,
              dense: true,
            ),
          ),
        ),
        if (!state.isRunning) ...[
          SizedBox(width: spacing.sm),
          AppButton(
            key: Key(
              state.lastRunAt == null
                  ? 'system-diagnostics-strip-start'
                  : 'system-diagnostics-strip-refresh',
            ),
            label: state.lastRunAt == null
                ? l10n.systemDiagnosticsStartCheck
                : l10n.systemDiagnosticsRerun,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.xSmall,
            onPressed: _runAll,
          ),
        ],
      ],
    );
  }

  void _runAll() {
    ref
        .read(
          systemDiagnosticsProvider(
            SystemDiagnosticsHost.overviewStrip,
          ).notifier,
        )
        .runAll();
  }

  ({AppStatusChipPalette palette, String label}) _statusPresentation(
    BuildContext context,
    SystemDiagnosticsState state,
  ) {
    final l10n = AppLocalizations.of(context);
    if (state.isRunning) {
      return (
        palette: AppStatusChipPalette.forSemantic(
          AppStatusSemantic.neutral,
          icon: Icons.hourglass_top,
        ),
        label: l10n.diagnosticStatusProbing,
      );
    }
    if (state.lastRunAt == null) {
      return (
        palette: AppStatusChipPalette.forSemantic(AppStatusSemantic.neutral),
        label: l10n.systemDiagnosticsStatusNotChecked,
      );
    }
    if (state.unhealthyCount > 0 ||
        state.overallStatus == DiagnosticItemStatus.unhealthy) {
      return (
        palette: AppStatusChipPalette.forSemantic(AppStatusSemantic.error),
        label: l10n.systemDiagnosticsStatusIssues(
          state.unhealthyCount > 0 ? state.unhealthyCount : 1,
        ),
      );
    }
    if (state.overallStatus == DiagnosticItemStatus.warning ||
        state.overallStatus == DiagnosticItemStatus.blocked) {
      return (
        palette: AppStatusChipPalette.forSemantic(AppStatusSemantic.warning),
        label: l10n.systemDiagnosticsStatusWarning,
      );
    }
    if (state.overallStatus == DiagnosticItemStatus.disabled ||
        state.overallStatus == DiagnosticItemStatus.notTested) {
      return (
        palette: AppStatusChipPalette.forSemantic(AppStatusSemantic.neutral),
        label: l10n.systemDiagnosticsStatusPartiallyChecked,
      );
    }
    return (
      palette: AppStatusChipPalette.forSemantic(AppStatusSemantic.success),
      label: l10n.systemDiagnosticsStatusAllPassed,
    );
  }
}
