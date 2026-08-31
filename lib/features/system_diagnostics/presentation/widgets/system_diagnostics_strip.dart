import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/relative_time_label.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_category_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/controllers/system_diagnostics_controller.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/diagnostic_status_badge.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 概览页顶部一条紧凑横条：
/// - notTested：显示 CTA「开始检测」
/// - probing：显示进度 + "取消"（第一期 disabled）
/// - healthy/warning/unhealthy：显示 6 个分组徽章 + 上次检测时间 + 「刷新」/「进入诊断页」
///
/// Strip 通过 autoDispose family provider 持有自己的诊断会话；诊断页使用另一
/// host 参数，所以两处状态互不共享。用户可以在 strip 看一眼，再进入诊断页运行
/// 独立的一次完整检测。
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
    final controller = ref.watch(
      systemDiagnosticsProvider(SystemDiagnosticsHost.overviewStrip),
    );
    final overall = controller.overallStatus;
    final hasRun = controller.lastRunAt != null;

    return AppContentCard(
      key: const Key('system-diagnostics-strip'),
      title: '组件诊断',
      headerBottomSpacing: spacing.md,
      headerTrailing: _buildHeaderTrailing(
        context,
        controller,
        hasRun,
        overall,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.xl,
        vertical: spacing.lg,
      ),
      child: _buildBody(context, controller),
    );
  }

  Widget _buildHeaderTrailing(
    BuildContext context,
    SystemDiagnosticsState controller,
    bool hasRun,
    DiagnosticItemStatus overall,
  ) {
    if (controller.isRunning || !hasRun) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconButton(
          key: const Key('system-diagnostics-strip-refresh'),
          tooltip: '重新检测',
          semanticLabel: '重新检测',
          size: AppIconButtonSize.mini,
          icon: const Icon(Icons.refresh),
          onPressed:
              ref
                  .read(
                    systemDiagnosticsProvider(
                      SystemDiagnosticsHost.overviewStrip,
                    ).notifier,
                  )
                  .runAll,
        ),
        SizedBox(width: context.appSpacing.xs),
        AppIconButton(
          key: const Key('system-diagnostics-strip-open'),
          tooltip: '打开组件诊断页',
          semanticLabel: '打开组件诊断页',
          size: AppIconButtonSize.mini,
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => context.pushDesktopSystemDiagnostics(),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, SystemDiagnosticsState c) {
    final spacing = context.appSpacing;
    if (c.isRunning) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: context.appComponentTokens.iconSizeSm,
            height: context.appComponentTokens.iconSizeSm,
            child: CircularProgressIndicator(
              strokeWidth:
                  context.appComponentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Text(
              '正在检测组件 ${c.completedItemCount}/${c.totalItemCount}…',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
        ],
      );
    }

    if (c.lastRunAt == null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              '一键检测媒体库、下载器、索引器、外部数据源与 JoyTag 的连通性。',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
          SizedBox(width: spacing.md),
          AppButton(
            key: const Key('system-diagnostics-strip-start'),
            label: '开始检测',
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            icon: const Icon(Icons.radar_rounded),
            onPressed:
                ref
                    .read(
                      systemDiagnosticsProvider(
                        SystemDiagnosticsHost.overviewStrip,
                      ).notifier,
                    )
                    .runAll,
          ),
        ],
      );
    }

    // 已完成一次。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: <Widget>[
            for (final cat in c.categories)
              DiagnosticStatusBadge(
                key: Key('system-diagnostics-strip-badge-${cat.label}'),
                label: cat.label,
                status: cat.aggregate,
                dense: true,
                detail: _detailForCategory(cat),
              ),
          ],
        ),
        SizedBox(height: spacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                _buildFooterLine(c),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone:
                      c.unhealthyCount > 0
                          ? AppTextTone.error
                          : AppTextTone.muted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String? _detailForCategory(DiagnosticCategoryState cat) {
    final unhealthy =
        cat.items
            .where((i) => i.status == DiagnosticItemStatus.unhealthy)
            .length;
    if (unhealthy > 0) return '$unhealthy';
    return null;
  }

  String _buildFooterLine(SystemDiagnosticsState c) {
    final rel = formatRelativeTimeLabel(c.lastRunAt!, suffix: '检测');
    if (c.unhealthyCount > 0) {
      return '$rel · ${c.unhealthyCount} 项异常';
    }
    return '$rel · 全部通过';
  }
}
