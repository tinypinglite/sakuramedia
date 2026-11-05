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
                  const OverviewCardIcon(
                    icon: Icons.space_dashboard_rounded,
                    onDark: true,
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Text(
                      l10n.overviewWorkbenchTitle,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s16,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.onMedia,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  _WorkbenchAllTasksAction(
                    label: l10n.activityFilterAllTasks,
                    onTap: onAllTasksTap,
                  ),
                ],
              ),
              SizedBox(height: spacing.md),
              if (activeCount > 0) ...<Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: _WorkbenchActiveBadge(
                    key: const Key('overview-workbench-active'),
                    label: l10n.overviewWorkbenchActive(
                      formatCount(activeCount),
                    ),
                  ),
                ),
                SizedBox(height: spacing.sm),
              ],
              if (errorMessage != null)
                OverviewCardErrorRow(
                  message: errorMessage!,
                  onRetry: onRetry,
                  retryKey: const Key('overview-workbench-retry-button'),
                  onDark: true,
                )
              else if (isEmpty && !isLoading)
                _WorkQueueEmptyState(message: l10n.overviewWorkbenchEmpty)
              else
                AppSkeletonizer(
                  enabled: isLoading,
                  child: _WorkQueueRows(
                    downloading: downloading,
                    importing: importing,
                    imported: imported,
                    pendingIndexCount: pendingIndexCount,
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Divider(
                height: 1,
                thickness: 1,
                color: context.appTextPalette.onMedia.withValues(alpha: 0.14),
              ),
              SizedBox(height: spacing.md),
              Theme(data: _diagnosticsTheme(context), child: diagnostics),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkQueueRows extends StatelessWidget {
  const _WorkQueueRows({
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
    final rows = <Widget>[
      _WorkQueueRow(
        key: const Key('overview-workbench-downloading'),
        icon: Icons.download_rounded,
        label: l10n.downloadStateDownloading,
        count: downloading,
        tone: AppTextTone.accent,
      ),
      _WorkQueueRow(
        key: const Key('overview-workbench-importing'),
        icon: Icons.inventory_2_outlined,
        label: l10n.downloadImportStatusRunning,
        count: importing,
        tone: AppTextTone.accent,
      ),
      _WorkQueueRow(
        key: const Key('overview-workbench-imported'),
        icon: Icons.task_alt_rounded,
        label: l10n.downloadImportStatusCompleted,
        count: imported,
        tone: AppTextTone.success,
      ),
      _WorkQueueRow(
        key: const Key('overview-workbench-pending-index'),
        icon: Icons.image_search_rounded,
        label: l10n.overviewPendingIndex,
        count: pendingIndexCount,
        tone: AppTextTone.accent,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var index = 0; index < rows.length; index += 1) ...<Widget>[
                if (index > 0) SizedBox(width: context.appSpacing.lg),
                Expanded(child: rows[index]),
              ],
            ],
          );
        }
        return Column(
          children: <Widget>[
            for (var index = 0; index < rows.length; index += 1) ...<Widget>[
              if (index > 0) SizedBox(height: context.appSpacing.xs),
              rows[index],
            ],
          ],
        );
      },
    );
  }
}

class _WorkQueueRow extends StatelessWidget {
  const _WorkQueueRow({
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
    final iconColor = context.appTextPalette.onMedia.withValues(
      alpha: tone == AppTextTone.success ? 0.92 : 0.78,
    );
    return SizedBox(
      height: context.appComponentTokens.buttonHeightXs,
      child: Row(
        children: <Widget>[
          Container(
            width: context.appComponentTokens.buttonHeightXs,
            height: context.appComponentTokens.buttonHeightXs,
            decoration: BoxDecoration(
              color: context.appTextPalette.onMedia.withValues(alpha: 0.10),
              borderRadius: context.appRadius.smBorder,
            ),
            child: Icon(
              icon,
              size: context.appComponentTokens.iconSizeXs,
              color: iconColor,
            ),
          ),
          SizedBox(width: context.appSpacing.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.onMedia,
                  ).copyWith(
                    color: context.appTextPalette.onMedia.withValues(
                      alpha: 0.68,
                    ),
                  ),
            ),
          ),
          Text(
            formatCount(count),
            style:
                resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.onMedia,
                ).copyWith(
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
    return Row(
      key: const Key('overview-workbench-empty'),
      children: <Widget>[
        Icon(
          Icons.check_circle_outline_rounded,
          size: context.appComponentTokens.iconSizeXs,
          color: context.appTextPalette.onMedia.withValues(alpha: 0.76),
        ),
        SizedBox(width: context.appSpacing.sm),
        Expanded(
          child: Text(
            message,
            style:
                resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.onMedia,
                ).copyWith(
                  color: context.appTextPalette.onMedia.withValues(alpha: 0.68),
                ),
          ),
        ),
      ],
    );
  }
}

class _WorkbenchActiveBadge extends StatelessWidget {
  const _WorkbenchActiveBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final onMedia = context.appTextPalette.onMedia;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.sm,
        vertical: context.appSpacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: onMedia.withValues(alpha: 0.12),
        borderRadius: context.appRadius.pillBorder,
        border: Border.all(color: onMedia.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s10,
          weight: AppTextWeight.medium,
          tone: AppTextTone.onMedia,
        ).copyWith(color: onMedia.withValues(alpha: 0.82)),
      ),
    );
  }
}

ThemeData _diagnosticsTheme(BuildContext context) {
  final theme = Theme.of(context);
  final onMedia = context.appTextPalette.onMedia;
  final colors = context.appColors.copyWith(
    surfaceMuted: onMedia.withValues(alpha: 0.10),
    borderSubtle: onMedia.withValues(alpha: 0.12),
    selectionSurface: onMedia.withValues(alpha: 0.12),
    selectionBorder: onMedia.withValues(alpha: 0.22),
  );
  final textPalette = context.appTextPalette.copyWith(
    primary: onMedia,
    secondary: onMedia.withValues(alpha: 0.78),
    tertiary: onMedia.withValues(alpha: 0.70),
    muted: onMedia.withValues(alpha: 0.64),
    accent: onMedia,
  );
  final extensions = Map<Object, ThemeExtension<dynamic>>.from(
    theme.extensions,
  );
  extensions[AppColors] = colors;
  extensions[AppTextPalette] = textPalette;
  return theme.copyWith(extensions: extensions.values);
}

class _WorkbenchAllTasksAction extends StatelessWidget {
  const _WorkbenchAllTasksAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onMedia = context.appTextPalette.onMedia;
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
                tone: AppTextTone.onMedia,
              ).copyWith(color: onMedia.withValues(alpha: 0.72)),
            ),
            SizedBox(width: context.appSpacing.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: context.appComponentTokens.iconSizeXs,
              color: onMedia.withValues(alpha: 0.52),
            ),
          ],
        ),
      ),
    );
  }
}
