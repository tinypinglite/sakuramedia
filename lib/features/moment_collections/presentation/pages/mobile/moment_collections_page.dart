import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/shared/moment_collections_content.dart';
import 'package:sakuramedia/routes/app_routes.dart';

class MobileMomentCollectionsPage extends StatelessWidget {
  const MobileMomentCollectionsPage({super.key});

  @override
  Widget build(BuildContext context) => MomentCollectionsContent(
    isMobile: true,
    onOpenDetail: (collectionId) => MobileRoutes.momentCollectionDetail(
      collectionId: collectionId,
    ).push(context),
  );
}
