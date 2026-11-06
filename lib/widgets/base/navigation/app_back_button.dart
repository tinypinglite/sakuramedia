import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 共享返回按钮。
///
/// [glass] 为 true 时使用 32 的玻璃圆钮；实色壳层使用普通图标按钮。
/// 高对比度模式下即使传 [glass] 也回退为实色按钮。
///
/// [overlay] 为 true 时实色按钮使用媒体前景色，保证压在封面或播放器内容
/// 上时仍然可读。
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.onPressed,
    this.glass = false,
    this.overlay = false,
  });

  final VoidCallback onPressed;
  final bool glass;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    if (glass && !highContrast) {
      return AppGlassIconButton(
        tooltip: l10n.shellBack,
        semanticLabel: l10n.shellBack,
        icon: Icons.arrow_back_ios_new_rounded,
        iconSize: 16,
        size: 32,
        onPressed: onPressed,
      );
    }
    return AppIconButton(
      tooltip: l10n.shellBack,
      semanticLabel: l10n.shellBack,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        size: context.appComponentTokens.iconSizeXs,
        color: overlay ? context.appTextPalette.onMedia : null,
      ),
    );
  }
}
