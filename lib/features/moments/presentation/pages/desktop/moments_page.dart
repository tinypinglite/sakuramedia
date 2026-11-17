import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/moments/presentation/pages/shared/moments_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';

/// 桌面时刻列表壳：导航四分支（图搜 / 快播 / 播放器 / 详情）由共享预览流程
/// [MomentsContent] 内部按桌面分支处理，这里只保留合集入口与 Key。
class DesktopMomentsPage extends StatelessWidget {
  const DesktopMomentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MomentsContent(
      keyPrefix: 'moments',
      rootKey: const Key('moments-page'),
      previewFallbackPath: desktopMomentsPath,
      onOpenCollections: () => DesktopRoutes.momentCollections().push(context),
      onOpenCollectionDetail: (collectionId) =>
          DesktopRoutes.momentCollectionDetail(
            collectionId: collectionId,
          ).push(context),
    );
  }
}
