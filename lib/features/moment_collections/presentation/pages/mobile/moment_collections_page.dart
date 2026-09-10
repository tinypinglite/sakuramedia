import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/shared/moment_collections_content.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';

class MobileMomentCollectionsPage extends StatelessWidget {
  const MobileMomentCollectionsPage({super.key});

  @override
  Widget build(BuildContext context) => MomentCollectionsContent(
    isMobile: true,
    onOpenDetail: (collectionId) => MobileMomentCollectionDetailRouteData(
      collectionId: collectionId,
    ).push(context),
  );
}
