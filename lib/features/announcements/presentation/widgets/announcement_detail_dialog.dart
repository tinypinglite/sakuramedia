import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/announcements/data/announcement_dto.dart';
import 'package:sakuramedia/features/announcements/presentation/announcement_link_opener.dart';
import 'package:sakuramedia/features/announcements/presentation/widgets/announcement_level_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

Future<void> showAnnouncementDetailDialog({
  required BuildContext context,
  required AnnouncementDto announcement,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    modalKey: const Key('announcement-detail-dialog'),
    desktopWidth: 460,
    mobileHeightFactor: 0.72,
    builder: (_) => _AnnouncementDetailBody(announcement: announcement),
  );
}

class _AnnouncementDetailBody extends ConsumerWidget {
  const _AnnouncementDetailBody({required this.announcement});

  final AnnouncementDto announcement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = appL10n(context);
    final locale = Localizations.localeOf(context);
    final spacing = context.appSpacing;
    final link = announcement.link;
    final body = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: SingleChildScrollView(
        child: Text(
          announcement.bodyFor(locale),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                announcement.titleFor(locale),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s16,
                  weight: AppTextWeight.semibold,
                ),
              ),
            ),
            SizedBox(width: spacing.sm),
            AppBadge(
              label: announcement.level.label(l10n),
              tone: announcement.level.badgeTone,
              size: AppBadgeSize.compact,
            ),
          ],
        ),
        SizedBox(height: spacing.md),
        if (AppAdaptiveModalShellScope.maybeIsDrawer(context))
          Flexible(child: body)
        else
          body,
        if (link != null) ...[
          SizedBox(height: spacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              key: const Key('announcement-detail-link'),
              label: l10n.announcementReadMore,
              icon: const Icon(Icons.open_in_new_rounded),
              variant: AppButtonVariant.secondary,
              onPressed: () {
                unawaited(openAnnouncementLink(context, ref, link));
              },
            ),
          ),
        ],
      ],
    );
  }
}
