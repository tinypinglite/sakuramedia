import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/announcements/data/announcement_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';

extension AnnouncementLevelUi on AnnouncementLevel {
  String label(AppLocalizations l10n) {
    return switch (this) {
      AnnouncementLevel.info => l10n.announcementLevelInfo,
      AnnouncementLevel.warning => l10n.announcementLevelWarning,
      AnnouncementLevel.critical => l10n.announcementLevelCritical,
    };
  }

  AppBadgeTone get badgeTone {
    return switch (this) {
      AnnouncementLevel.info => AppBadgeTone.info,
      AnnouncementLevel.warning => AppBadgeTone.warning,
      AnnouncementLevel.critical => AppBadgeTone.error,
    };
  }

  IconData get icon {
    return switch (this) {
      AnnouncementLevel.info => Icons.info_outline_rounded,
      AnnouncementLevel.warning => Icons.warning_amber_rounded,
      AnnouncementLevel.critical => Icons.error_outline_rounded,
    };
  }
}
