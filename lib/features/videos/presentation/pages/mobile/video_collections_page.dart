import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_collections_content.dart';

/// 移动视频合集列表壳：移动布局差异收在共享内容层内。
class MobileVideoCollectionsPage extends StatelessWidget {
  const MobileVideoCollectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VideoCollectionsContent(mobile: true);
  }
}
