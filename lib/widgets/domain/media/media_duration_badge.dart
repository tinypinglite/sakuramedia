import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/badges/app_media_badge.dart';

/// 媒体封面右下角的时长角标，与 4K/热度/排名共用烟熏材质。
///
/// 跨切片 / 视频 / 合集等所有「有时长的媒体缩略图」共用。
class MediaDurationBadge extends StatelessWidget {
  const MediaDurationBadge({super.key, required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return AppMediaBadge.duration(seconds: seconds);
  }
}
