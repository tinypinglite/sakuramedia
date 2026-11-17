import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/shared/clip_collection_play_content.dart';

/// 桌面切片合集连播壳：平台差异只有 `useTouchOptimizedControls: false`（hover 唤出
/// 控制条），全部实现在共享的 [ClipCollectionPlayContent]。
class DesktopClipCollectionPlayPage extends StatelessWidget {
  const DesktopClipCollectionPlayPage({
    super.key,
    required this.collectionId,
    this.startIndex = 0,
  });

  final int collectionId;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    return ClipCollectionPlayContent(
      collectionId: collectionId,
      startIndex: startIndex,
    );
  }
}
