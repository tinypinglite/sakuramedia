import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_collection_play_content.dart';

/// 桌面视频合集连播壳：平台差异只有 `useTouchOptimizedControls: false`（hover 唤出
/// 控制条），全部实现在共享的 [VideoCollectionPlayContent]。
class DesktopVideoCollectionPlayPage extends StatelessWidget {
  const DesktopVideoCollectionPlayPage({
    super.key,
    required this.collectionId,
    this.startIndex = 0,
    this.sort,
  });

  final int collectionId;
  final int startIndex;
  final String? sort;

  @override
  Widget build(BuildContext context) {
    return VideoCollectionPlayContent(
      collectionId: collectionId,
      startIndex: startIndex,
      sort: sort,
    );
  }
}
