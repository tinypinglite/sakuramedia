import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moment_collections/presentation/pages/shared/moment_collection_detail_content.dart';

class DesktopMomentCollectionDetailPage extends StatelessWidget {
  const DesktopMomentCollectionDetailPage({
    super.key,
    required this.collectionId,
  });

  final int collectionId;

  @override
  Widget build(BuildContext context) => MomentCollectionDetailContent(
    collectionId: collectionId,
    isMobile: false,
  );
}
