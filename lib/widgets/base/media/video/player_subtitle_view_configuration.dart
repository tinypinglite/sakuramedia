import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/core/media/providers/player_subtitle_preference_provider.dart';
import 'package:sakuramedia/theme.dart';

/// media_kit 默认字幕字号；用户倍率在这个基准上叠加。
const double _basePlayerSubtitleFontSize = 32;

/// 把设备级字幕偏好转成 media_kit 的字幕视图配置。
///
/// 字幕不使用整行底色，而是通过双层柔影保证亮暗画面上的可读性；左右保持
/// 无内边距，底部固定在系统安全区上方的合理距离，用户只调字号倍率。
SubtitleViewConfiguration buildPlayerSubtitleViewConfiguration({
  required BuildContext context,
  required PlayerSubtitlePreference preference,
}) {
  final spacing = context.appSpacing;
  return SubtitleViewConfiguration(
    style: TextStyle(
      fontFamily: resolveAppFontFamily(context),
      height: 1.38,
      fontSize: _basePlayerSubtitleFontSize * preference.scale,
      color: Colors.white,
      fontWeight: context.appTextWeights.medium,
      letterSpacing: 0,
      wordSpacing: 0,
      shadows: <Shadow>[
        Shadow(color: Colors.black.withValues(alpha: 0.92), blurRadius: 2),
        Shadow(
          color: Colors.black.withValues(alpha: 0.38),
          blurRadius: 7,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    padding: EdgeInsets.fromLTRB(
      0,
      0,
      0,
      spacing.xl + MediaQuery.paddingOf(context).bottom,
    ),
  );
}
