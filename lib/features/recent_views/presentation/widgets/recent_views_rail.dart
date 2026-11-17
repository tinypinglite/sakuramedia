import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/recent_views/data/dto/recent_view_dto.dart';
import 'package:sakuramedia/features/recent_views/presentation/widgets/recent_view_card.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_scroll_rail.dart';

/// 「最近浏览」横向 rail：影片/女优混排，卡宽与其他预览 rail 同档
/// （移动 `mobileLatestMovieCardWidth`，桌面 `movieCardTargetWidth` 的 0.75）。
///
/// 卡片直接复用 [RecentViewCard]：订阅心、热度角标、ⓘ 检查器与悬停面板都随
/// 卡片自带。
class RecentViewsRail extends StatelessWidget {
  const RecentViewsRail({
    super.key,
    required this.entries,
    required this.onMovieTap,
    required this.onActorTap,
  });

  final List<RecentViewEntryDto> entries;
  final ValueChanged<String> onMovieTap;
  final ValueChanged<int> onActorTap;

  static const double _desktopCardWidthFactor = 0.75;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appComponentTokens;
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final cardWidth = isMobile
        ? tokens.mobileLatestMovieCardWidth
        : tokens.movieCardTargetWidth * _desktopCardWidthFactor;
    final cardHeight = cardWidth / tokens.movieCardAspectRatio;
    return AppScrollRail(
      scrollViewKey: const Key('recent-views-rail'),
      height: cardHeight,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return SizedBox(
          width: cardWidth,
          child: RecentViewCard(
            entry: entries[index],
            onMovieTap: onMovieTap,
            onActorTap: onActorTap,
          ),
        );
      },
    );
  }
}
