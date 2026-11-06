import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/media/presentation/pages/shared/media_management_content.dart';
import 'package:sakuramedia/routes/app_routes.dart';

/// 「媒体管理」桌面壳：媒体列表 / 重复媒体 / 多版本影片 / 失效媒体四个 tab 与全部编排逻辑在
/// [MediaManagementContent]，
/// 壳只注入 Key 前缀、根 Key 与跳影片详情的导航回调。
class DesktopMediaManagementPage extends StatelessWidget {
  const DesktopMediaManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaManagementContent(
      keyPrefix: 'media-management',
      rootKey: const Key('desktop-media-management-page'),
      onOpenMovieDetail: (context, movieNumber) =>
          DesktopRoutes.movieDetail(movieNumber: movieNumber).push(context),
      onOpenVideoCollectionDetail: (context, collectionId) =>
          DesktopRoutes.videoCollectionDetail(
            collectionId: collectionId,
          ).push(context),
    );
  }
}
