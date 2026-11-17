import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_collections_content.dart';

/// 桌面视频合集列表壳：桌面布局差异收在共享内容层内。
class DesktopVideoCollectionsPage extends StatelessWidget {
  const DesktopVideoCollectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VideoCollectionsContent(mobile: false);
  }
}
