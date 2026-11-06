import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_format.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_card_icon.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_card_states.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_surface.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

/// 桌面概览工作台：当前下载 / 导入 / 已导入 / 待索引，以及组件诊断入口。
///
/// 数据是当前任务快照，不展示失败或历史完成率；诊断槽由页面接入现有
/// 系统诊断组件，避免卡片自己依赖路由。
class OverviewWorkQueueCard extends StatelessWidget {
  const OverviewWorkQueueCard({
    super.key,
    required this.downloading,
    required this.importing,
    required this.imported,
    required this.pendingIndexCount,
    required this.diagnostics,
    required this.onAllTasksTap,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.minHeight,
  });

  final int downloading;
  final int importing;
  final int imported;
  final int pendingIndexCount;
  final Widget diagnostics;
  final VoidCallback onAllTasksTap;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final activeCount = downloading + importing;
    final isEmpty = activeCount == 0 && imported == 0 && pendingIndexCount == 0;

    return OverviewSurface(
      key: const Key('overview-workbench-card'),
      minHeight: minHeight,
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const OverviewHeroIcon(icon: Icons.space_dashboard_rounded),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Text(
                      l10n.overviewWorkbenchTitle,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s18,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                  ),
                  if (activeCount > 0) ...<Widget>[
                    _WorkbenchActiveBadge(
                      key: const Key('overview-workbench-active'),
                      label: l10n.overviewWorkbenchActive(
                        formatCount(activeCount),
                      ),
                    ),
                    SizedBox(width: spacing.md),
                  ],
                  _WorkbenchAllTasksAction(
                    label: l10n.activityFilterAllTasks,
                    onTap: onAllTasksTap,
                  ),
                ],
              ),
              SizedBox(height: spacing.md),
              if (errorMessage != null)
                OverviewCardErrorRow(
                  message: errorMessage!,
                  onRetry: onRetry,
                  retryKey: const Key('overview-workbench-retry-button'),
                )
              else if (isEmpty && !isLoading)
                _WorkQueueEmptyState(message: l10n.overviewWorkbenchEmpty)
              else
                AppSkeletonizer(
                  enabled: isLoading,
                  child: _WorkQueueMetricGrid(
                    downloading: downloading,
                    importing: importing,
                    imported: imported,
                    pendingIndexCount: pendingIndexCount,
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Divider(
                height: 1,
                thickness: 1,
                color: context.appColors.divider,
              ),
              SizedBox(height: spacing.md),
              diagnostics,
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkQueueMetricGrid extends StatelessWidget {
  const _WorkQueueMetricGrid({
    required this.downloading,
    required this.importing,
    required this.imported,
    required this.pendingIndexCount,
  });

  final int downloading;
  final int importing;
  final int imported;
  final int pendingIndexCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metrics = <Widget>[
      _WorkQueueMetric(
        key: const Key('overview-workbench-downloading'),
        icon: Icons.download_rounded,
        label: l10n.downloadStateDownloading,
        count: downloading,
        tone: AppTextTone.accent,
      ),
      _WorkQueueMetric(
        key: const Key('overview-workbench-importing'),
        icon: Icons.inventory_2_outlined,
        label: l10n.downloadImportStatusRunning,
        count: importing,
        tone: AppTextTone.info,
      ),
      _WorkQueueMetric(
        key: const Key('overview-workbench-imported'),
        icon: Icons.task_alt_rounded,
        label: l10n.downloadImportStatusCompleted,
        count: imported,
        tone: AppTextTone.success,
      ),
      _WorkQueueMetric(
        key: const Key('overview-workbench-pending-index'),
        icon: Icons.image_search_rounded,
        label: l10n.overviewPendingIndex,
        count: pendingIndexCount,
        tone: AppTextTone.warning,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 340) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: metrics[0]),
                _verticalDivider(context),
                Expanded(child: metrics[1]),
                _verticalDivider(context),
                Expanded(child: metrics[2]),
                _verticalDivider(context),
                Expanded(child: metrics[3]),
              ],
            ),
          );
        }
        return Column(
          children: <Widget>[
            for (var index = 0; index < metrics.length; index += 1) ...<Widget>[
              if (index > 0)
                Divider(
                  height: context.appSpacing.md,
                  thickness: 1,
                  color: context.appColors.divider,
                ),
              metrics[index],
            ],
          ],
        );
      },
    );
  }

  Widget _verticalDivider(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.appSpacing.sm),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: context.appColors.divider,
      ),
    );
  }
}

class _WorkQueueMetric extends StatelessWidget {
  const _WorkQueueMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final int count;
  final AppTextTone tone;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final foreground = resolveAppTextToneColor(context, tone);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.xs,
        vertical: spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: context.appComponentTokens.iconSizeSm,
                color: foreground,
              ),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Text(
            formatCount(count),
            style:
                resolveAppTextStyle(
                  context,
                  size: AppTextSize.s20,
                  weight: AppTextWeight.semibold,
                  tone: count > 0 ? AppTextTone.primary : AppTextTone.muted,
                ).copyWith(
                  height: 1,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}

class _WorkQueueEmptyState extends StatelessWidget {
  const _WorkQueueEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const Key('overview-workbench-empty'),
      constraints: BoxConstraints(
        minHeight: context.appSpacing.xxxl + context.appSpacing.xl,
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.check_circle_outline_rounded,
              size: context.appComponentTokens.iconSizeSm,
              color: context.appTextPalette.success,
            ),
            SizedBox(width: context.appSpacing.md),
            Text(
              message,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.medium,
                tone: AppTextTone.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkbenchActiveBadge extends StatelessWidget {
  const _WorkbenchActiveBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      height: context.appComponentTokens.buttonHeight2xs,
      padding: EdgeInsets.symmetric(horizontal: context.appSpacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.selectionSurface.withValues(alpha: 0.7),
        borderRadius: context.appRadius.pillBorder,
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: context.appSpacing.xs,
            height: context.appSpacing.xs,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          ),
          SizedBox(width: context.appSpacing.xs),
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.medium,
              tone: AppTextTone.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkbenchAllTasksAction extends StatelessWidget {
  const _WorkbenchAllTasksAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppInteractiveSurface(
      key: const Key('overview-workbench-all-tasks'),
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        height: context.appComponentTokens.buttonHeightXs,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.medium,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(width: context.appSpacing.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: context.appComponentTokens.iconSizeXs,
              color: context.appTextPalette.muted,
            ),
          ],
        ),
      ),
    );
  }
}
