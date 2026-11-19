import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/core/media/providers/player_subtitle_preference_provider.dart';
import 'package:sakuramedia/theme.dart';

/// media_kit 默认字幕字号；用户倍率在这个基准上叠加。
const double _basePlayerSubtitleFontSize = 32;

/// 把设备级字幕偏好转成 media_kit 的字幕视图配置。
///
/// 水平留白与底部基准间距走主题 token；用户只调字号倍率和底部偏移。
SubtitleViewConfiguration buildPlayerSubtitleViewConfiguration({
  required BuildContext context,
  required PlayerSubtitlePreference preference,
}) {
  final spacing = context.appSpacing;
  return SubtitleViewConfiguration(
    style: TextStyle(
      height: 1.4,
      fontSize: _basePlayerSubtitleFontSize * preference.scale,
      color: Colors.white,
      backgroundColor: Colors.black.withValues(alpha: 0.66),
      fontWeight: FontWeight.normal,
      letterSpacing: 0,
      wordSpacing: 0,
    ),
    padding: EdgeInsets.fromLTRB(
      spacing.lg,
      0,
      spacing.lg,
      spacing.xl + preference.bottomOffset,
    ),
  );
}
