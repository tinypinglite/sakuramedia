import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_collection_detail_content.dart';
import 'package:sakuramedia/theme.dart';

/// 移动视频合集详情：移动网格、吸顶栏和动作抽屉由 content 层根据 `mobile` 选择。
class MobileVideoCollectionDetailPage extends StatelessWidget {
  const MobileVideoCollectionDetailPage({
    super.key,
    required this.collectionId,
  });

  final int collectionId;

  @override
  Widget build(BuildContext context) {
    return VideoCollectionDetailContent(
      collectionId: collectionId,
      surfaceColor: context.appColors.surfaceCard,
      keyPrefix: 'mobile-video-collection',
      mobile: true,
    );
  }
}
