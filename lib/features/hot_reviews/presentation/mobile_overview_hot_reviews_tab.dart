import 'package:flutter/widgets.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/desktop_hot_reviews_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';

class MobileOverviewHotReviewsTab extends StatelessWidget {
  const MobileOverviewHotReviewsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('mobile-overview-hot-reviews-tab'),
      child: DesktopHotReviewsPage(
        minColumns: 1,
        maxColumns: 2,
        targetCardWidth: 360,
        onOpenMovieDetail: (context, item) {
          final movieNumber = item.movie.movieNumber.trim();
          if (movieNumber.isEmpty) {
            return;
          }
          context.pushMobileMovieDetail(
            movieNumber: movieNumber,
            fallbackPath: mobileOverviewPath,
          );
        },
      ),
    );
  }
}
