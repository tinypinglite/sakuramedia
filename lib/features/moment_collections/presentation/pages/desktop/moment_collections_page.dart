import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/shared/moment_collections_content.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';

class DesktopMomentCollectionsPage extends StatelessWidget {
  const DesktopMomentCollectionsPage({super.key});

  @override
  Widget build(BuildContext context) => MomentCollectionsContent(
    isMobile: false,
    onOpenDetail: (collectionId) =>
        context.pushDesktopMomentCollectionDetail(collectionId: collectionId),
  );
}
