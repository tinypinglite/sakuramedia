import 'package:flutter/material.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_stream_status.dart';
import 'package:sakuramedia/theme.dart';

class CatalogSearchStreamStatusCard extends StatelessWidget {
  const CatalogSearchStreamStatusCard({super.key, required this.status});

  final CatalogSearchStreamStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;

    return Container(
      key: const Key('catalog-search-stream-status-card'),
      width: double.infinity,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            status.isRunning
                ? Icons.public_rounded
                : status.isFailure
                ? Icons.cloud_off_outlined
                : Icons.cloud_done_outlined,
            color: status.isRunning ? colors.textPrimary : colors.textMuted,
            size: componentTokens.iconSizeSm,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                if (status.progressLabel != null) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    status.progressLabel!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
                if (status.statsLabel != null) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    status.statsLabel!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
