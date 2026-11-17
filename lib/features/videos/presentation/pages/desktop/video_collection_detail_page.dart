import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_collection_detail_content.dart';
import 'package:sakuramedia/theme.dart';

/// 桌面视频合集详情：桌面布局与动作弹窗由 content 层根据 `mobile` 选择。
class DesktopVideoCollectionDetailPage extends StatelessWidget {
  const DesktopVideoCollectionDetailPage({
    super.key,
    required this.collectionId,
  });

  final int collectionId;

  @override
  Widget build(BuildContext context) {
    return VideoCollectionDetailContent(
      collectionId: collectionId,
      surfaceColor: context.appColors.surfaceElevated,
      keyPrefix: 'video-collection',
      mobile: false,
    );
  }
}
