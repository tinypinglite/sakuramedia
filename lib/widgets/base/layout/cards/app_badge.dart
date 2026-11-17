import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_pill.dart';

enum AppBadgeTone { neutral, primary, info, warning, error, success }

enum AppBadgeSize { compact, regular }

/// 静态徽章：短状态/计数文字。
///
/// 视觉由 [AppPill] 统一承载；这里只保留业务侧使用的 tone/size API。
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.size = AppBadgeSize.regular,
  });

  final String label;
  final AppBadgeTone tone;
  final AppBadgeSize size;

  @override
  Widget build(BuildContext context) {
    return AppPill(
      label: label,
      tone: switch (tone) {
        AppBadgeTone.neutral => AppPillTone.neutral,
        AppBadgeTone.primary => AppPillTone.primary,
        AppBadgeTone.info => AppPillTone.info,
        AppBadgeTone.warning => AppPillTone.warning,
        AppBadgeTone.error => AppPillTone.error,
        AppBadgeTone.success => AppPillTone.success,
      },
      size: switch (size) {
        AppBadgeSize.compact => AppPillSize.compact,
        AppBadgeSize.regular => AppPillSize.regular,
      },
    );
  }
}
