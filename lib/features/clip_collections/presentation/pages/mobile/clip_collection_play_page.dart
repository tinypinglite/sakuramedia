import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/shared/clip_collection_play_content.dart';
import 'package:sakuramedia/widgets/domain/movies/player/landscape_player_system_ui.dart';

/// 移动端切片合集连播壳：横屏沉浸式 `SystemChrome` 是唯一有状态职责，
/// 播放器全部实现在共享的 [ClipCollectionPlayContent]（`useTouchOptimizedControls: true`）。
class MobileClipCollectionPlayPage extends StatefulWidget {
  const MobileClipCollectionPlayPage({
    super.key,
    required this.collectionId,
    this.startIndex = 0,
  });

  final int collectionId;
  final int startIndex;

  @override
  State<MobileClipCollectionPlayPage> createState() =>
      _MobileClipCollectionPlayPageState();
}

class _MobileClipCollectionPlayPageState
    extends State<MobileClipCollectionPlayPage>
    with PlayerOrientationLockStateMixin<MobileClipCollectionPlayPage> {
  @override
  Widget build(BuildContext context) {
    return wrapWithPlayerImmersiveOverlay(
      ClipCollectionPlayContent(
        collectionId: widget.collectionId,
        startIndex: widget.startIndex,
        useTouchOptimizedControls: true,
        orientationLock: orientationLock,
      ),
    );
  }
}
