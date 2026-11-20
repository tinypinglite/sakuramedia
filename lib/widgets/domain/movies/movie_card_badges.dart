import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/core/format/media_technical.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/badges/app_media_badge.dart';

/// 影片卡右上角热度胶囊：火焰图标 + 紧凑数值。
///
/// 影片摘要卡与电视卡共用；Key 前缀由调用方决定，避免两类卡片互相命中。
class MovieHeatBadge extends StatelessWidget {
  const MovieHeatBadge({
    super.key,
    required this.movieNumber,
    required this.heat,
    this.keyPrefix = 'movie-summary-card',
  });

  final String movieNumber;
  final int heat;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return AppMediaBadge(
      key: Key('$keyPrefix-heat-$movieNumber'),
      labelKey: Key('$keyPrefix-heat-text-$movieNumber'),
      label: formatAppCompactCount(heat),
      leading: Icon(
        Icons.local_fire_department_rounded,
        color: context.appColors.movieDetailHeatIcon,
      ),
    );
  }
}

/// 影片卡左上角可播放圆标：4K/8K 清晰度标出现时不再重复显示。
class MoviePlayableBadge extends StatelessWidget {
  const MoviePlayableBadge({
    super.key,
    required this.movieNumber,
    this.keyPrefix = 'movie-summary-card',
  });

  final String movieNumber;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appComponentTokens;
    return Container(
      key: Key('$keyPrefix-status-playable-$movieNumber'),
      width: tokens.movieCardStatusBadgeSize,
      height: tokens.movieCardStatusBadgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.appColors.movieCardPlayableBadgeBackground,
        borderRadius: context.appRadius.pillBorder,
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        size: tokens.iconSizeXl,
        color: context.appTextPalette.onMedia,
      ),
    );
  }
}

/// 影片卡左上角清晰度胶囊：有效媒体最高宽度 ≥7680 为 8K、≥3840 为 4K。
class MovieResolutionBadge extends StatelessWidget {
  const MovieResolutionBadge({
    super.key,
    required this.movieNumber,
    required this.maxMediaWidth,
    this.keyPrefix = 'movie-summary-card',
  });

  final String movieNumber;
  final int maxMediaWidth;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appComponentTokens;
    final spacing = context.appSpacing;
    return IgnorePointer(
      child: AppMediaBadge(
        key: Key('$keyPrefix-resolution-$movieNumber'),
        label: formatMovieResolutionLabel(maxMediaWidth),
        width: tokens.movieCardStatusBadgeSize + spacing.sm,
        height: tokens.movieCardStatusBadgeSize,
        padding: EdgeInsets.zero,
        size: AppMediaBadgeSize.prominent,
      ),
    );
  }
}
