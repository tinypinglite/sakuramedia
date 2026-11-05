import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';

/// 概览页内容区页头；不涉及桌面壳顶栏。
class OverviewPageHeader extends StatelessWidget {
  const OverviewPageHeader({
    super.key,
    required this.isConnected,
    required this.onImportTap,
  });

  final bool isConnected;
  final VoidCallback onImportTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          l10n.overviewLibraryTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s20,
            weight: AppTextWeight.semibold,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          l10n.overviewLibrarySubtitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isConnected) ...<Widget>[
          AppStatusChip(
            key: const Key('overview-connection-status'),
            label: l10n.overviewConnected,
            palette: AppStatusChipPalette.success(),
            dense: true,
          ),
          SizedBox(width: spacing.md),
        ],
        AppButton(
          key: const Key('overview-import-media'),
          label: l10n.overviewImportMedia,
          icon: const Icon(Icons.add_rounded),
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          onPressed: onImportTap,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              title,
              SizedBox(height: spacing.md),
              actions,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: title),
            SizedBox(width: spacing.lg),
            actions,
          ],
        );
      },
    );
  }
}
