import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_format.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/status/presentation/status_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 移动端「服务健康」卡：移动端没有组件诊断页，连通性状态收敛在这里，
/// 只保留可操作的项（重建索引）。
class ServiceHealthCard extends StatelessWidget {
  const ServiceHealthCard({
    super.key,
    required this.imageSearchStatus,
    required this.isLoading,
    required this.isRebuildingIndex,
    this.onRebuildIndex,
  });

  final StatusImageSearchDto? imageSearchStatus;
  final bool isLoading;
  final bool isRebuildingIndex;
  final VoidCallback? onRebuildIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showSkeleton = isLoading && imageSearchStatus == null;
    final status = showSkeleton
        ? imageSearchStatusPlaceholder()
        : imageSearchStatus;
    final requiresRebuild = status?.indexSpace.requiresRebuild ?? false;
    final isRebuilding =
        isRebuildingIndex || (status?.indexSpace.isRebuilding ?? false);

    // loading 用占位状态渲染真实行，由 [AppSkeletonizer] 灰化。
    return AppSkeletonizer(
      enabled: showSkeleton,
      child: AppContentCard(
        key: const Key('mobile-service-health-card'),
        title: l10n.overviewServiceHealth,
        padding: EdgeInsets.all(context.appSpacing.lg),
        headerBottomSpacing: context.appSpacing.xs,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _HealthRow(
              label: l10n.overviewEmbeddingService,
              value: embeddingServiceHealthLabel(status, l10n),
              valueTone: embeddingServiceHealthTone(status),
              rowKey: const Key('mobile-service-health-embedding'),
            ),
            const _HealthDivider(),
            _HealthRow(
              label: l10n.systemMaintenanceImageSearchTitle,
              value: imageSearchIndexSpaceLabel(status, l10n),
              valueTone: imageSearchIndexSpaceTone(status),
              rowKey: const Key('mobile-service-health-index'),
              action: requiresRebuild || isRebuilding
                  ? AppButton(
                      key: const Key('mobile-service-health-rebuild-button'),
                      label: isRebuilding
                          ? l10n.systemMaintenanceRebuilding
                          : l10n.overviewRebuild,
                      size: AppButtonSize.small,
                      isLoading: isRebuilding,
                      onPressed: isRebuilding ? null : onRebuildIndex,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.rowKey,
    this.value,
    this.valueTone = AppTextTone.primary,
    this.action,
  });

  final String label;
  final Key rowKey;
  final String? value;
  final AppTextTone valueTone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: rowKey,
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.primary,
              ),
            ),
          ),
          SizedBox(width: context.appSpacing.sm),
          Text(
            value ?? '',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.medium,
              tone: valueTone,
            ),
          ),
          if (action != null) ...<Widget>[
            SizedBox(width: context.appSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

class _HealthDivider extends StatelessWidget {
  const _HealthDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: context.appColors.divider);
  }
}
