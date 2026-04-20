import 'package:flutter/material.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_stream_status.dart';
import 'package:sakuramedia/theme.dart';

class CatalogSearchStreamStatusCard extends StatelessWidget {
  const CatalogSearchStreamStatusCard({super.key, required this.status});

  final CatalogSearchStreamStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    return Container(
      key: const Key('catalog-search-stream-status-card'),
      width: double.infinity,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Center(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            key: const Key('catalog-search-stream-status-content'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.message,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.primary,
                ),
              ),
              if (status.progressLabel != null) ...[
                SizedBox(height: spacing.xs),
                Text(
                  status.progressLabel!,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
              if (status.statsLabel != null) ...[
                SizedBox(height: spacing.xs),
                Text(
                  status.statsLabel!,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
