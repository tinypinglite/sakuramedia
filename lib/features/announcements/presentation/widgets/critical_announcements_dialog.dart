import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/announcements/data/announcement_dto.dart';
import 'package:sakuramedia/features/announcements/presentation/widgets/announcement_level_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

class CriticalAnnouncementsDialog extends StatefulWidget {
  const CriticalAnnouncementsDialog({
    super.key,
    required this.announcements,
    required this.onAcknowledge,
    this.onOpenLink,
  });

  final List<AnnouncementDto> announcements;
  final Future<void> Function() onAcknowledge;
  final Future<void> Function(String url)? onOpenLink;

  @override
  State<CriticalAnnouncementsDialog> createState() =>
      _CriticalAnnouncementsDialogState();
}

class _CriticalAnnouncementsDialogState
    extends State<CriticalAnnouncementsDialog> {
  bool _isSubmitting = false;

  Future<void> _acknowledge() async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await widget.onAcknowledge();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final spacing = context.appSpacing;
    return PopScope(
      canPop: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.error_outline_rounded,
                color: context.appTextPalette.error,
                size: context.appComponentTokens.iconSizeXl,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  l10n.announcementCriticalDialogTitle,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s16,
                    weight: AppTextWeight.semibold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.lg),
          if (AppAdaptiveModalShellScope.maybeIsDrawer(context))
            Flexible(child: _announcementList())
          else
            _announcementList(),
          SizedBox(height: spacing.lg),
          AppButton(
            key: const Key('critical-announcement-acknowledge'),
            label: l10n.announcementAcknowledge,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.large,
            isLoading: _isSubmitting,
            onPressed: _acknowledge,
          ),
        ],
      ),
    );
  }

  Widget _announcementList() {
    final spacing = context.appSpacing;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            for (var index = 0; index < widget.announcements.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == widget.announcements.length - 1
                      ? 0
                      : spacing.md,
                ),
                child: _CriticalAnnouncementCard(
                  announcement: widget.announcements[index],
                  onOpenLink: widget.onOpenLink,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CriticalAnnouncementCard extends StatelessWidget {
  const _CriticalAnnouncementCard({
    required this.announcement,
    required this.onOpenLink,
  });

  final AnnouncementDto announcement;
  final Future<void> Function(String url)? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final locale = Localizations.localeOf(context);
    final spacing = context.appSpacing;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.appColors.errorSurface,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(
          color: context.appTextPalette.error.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  announcement.titleFor(locale),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              AppBadge(
                label: announcement.level.label(l10n),
                tone: AppBadgeTone.error,
                size: AppBadgeSize.compact,
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Text(
            announcement.bodyFor(locale),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
          if (announcement.link != null && onOpenLink != null) ...[
            SizedBox(height: spacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                key: Key('critical-announcement-link-${announcement.id}'),
                label: l10n.announcementReadMore,
                icon: const Icon(Icons.open_in_new_rounded),
                size: AppButtonSize.xSmall,
                variant: AppButtonVariant.secondary,
                onPressed: () => onOpenLink!(announcement.link!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
