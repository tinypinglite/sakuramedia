import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/media/presentation/pages/shared/media_management_content.dart';
import 'package:sakuramedia/routes/app_routes.dart';

/// 「媒体管理」移动端壳：媒体列表 / 重复媒体 / 多版本影片 / 失效媒体四个 tab 与全部编排逻辑在
/// [MediaManagementContent]，
/// 壳只注入 Key 前缀、根 Key、移动端布局开关与跳影片详情的导航回调。
class MobileMediaManagementPage extends StatelessWidget {
  const MobileMediaManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaManagementContent(
      keyPrefix: 'mobile-media-management',
      rootKey: const Key('mobile-media-management-page'),
      mobile: true,
      onOpenMovieDetail: (context, movieNumber) =>
          MobileRoutes.movieDetail(movieNumber: movieNumber).push(context),
      onOpenVideoCollectionDetail: (context, collectionId) =>
          MobileRoutes.videoCollectionDetail(
            collectionId: collectionId,
          ).push(context),
    );
  }
}
