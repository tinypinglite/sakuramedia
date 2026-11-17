import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_scroll_rail.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_card.dart';

/// 时刻的横向 rail 版本：发现预览区专用，16:9 卡片。
///
/// 空态 / 错误态由调用方自行处理。
class MomentRail extends StatelessWidget {
  const MomentRail({
    super.key,
    required this.items,
    required this.onItemTap,
    this.onItemPlay,
    this.onItemOpenMovie,
    this.onItemAddToCollection,
  });

  final List<MomentListItem> items;
  final ValueChanged<MomentListItem> onItemTap;

  /// 卡片悬停面板里的播放回调（跳播到该时刻）；不传则 hover 不显示播放键。
  final ValueChanged<MomentListItem>? onItemPlay;

  /// 卡片悬停面板里的「影片」回调；不传则不显示。
  final ValueChanged<MomentListItem>? onItemOpenMovie;

  /// 卡片悬停面板里的「加入合集」回调；不传则不显示。
  final ValueChanged<MomentListItem>? onItemAddToCollection;

  static const double _mobileCardWidth = 200;
  static const double _desktopCardWidth = 240;
  static const double _cardAspectRatio = 16 / 9;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final cardWidth = isMobile ? _mobileCardWidth : _desktopCardWidth;
    return AppScrollRail(
      height: cardWidth / _cardAspectRatio,
      itemCount: items.length,
      scrollViewKey: const Key('moment-rail'),
      itemBuilder: (context, index) {
        final item = items[index];
        return SizedBox(
          width: cardWidth,
          child: MomentCard(
            item: item,
            onTap: () => onItemTap(item),
            onPlay: onItemPlay == null ? null : () => onItemPlay!(item),
            onOpenMovie: onItemOpenMovie == null
                ? null
                : () => onItemOpenMovie!(item),
            onAddToCollection: onItemAddToCollection == null
                ? null
                : () => onItemAddToCollection!(item),
          ),
        );
      },
    );
  }
}
