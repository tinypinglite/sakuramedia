import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_stream_status.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

class CatalogSearchStreamStatusCard extends StatelessWidget {
  const CatalogSearchStreamStatusCard({super.key, required this.status});

  final CatalogSearchStreamStatus status;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return AppContentCard(
      key: const Key('catalog-search-stream-status-card'),
      padding: EdgeInsets.all(spacing.md),
      borderRadius: context.appRadius.mdBorder,
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
