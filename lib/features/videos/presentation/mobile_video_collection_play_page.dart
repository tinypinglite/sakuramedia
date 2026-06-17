import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/presentation/desktop_video_collection_play_page.dart';
import 'package:sakuramedia/widgets/movie_player/landscape_player_system_ui.dart';

/// 移动端视频合集连播页：在桌面连播页（左播放器 + 右队列）外薄包一层横屏沉浸式
/// `SystemChrome`，对齐 `MobileClipCollectionPlayPage` / `MobileMoviePlayerPage` 的包壳方式。
class MobileVideoCollectionPlayPage extends StatefulWidget {
  const MobileVideoCollectionPlayPage({
    super.key,
    required this.collectionId,
    this.startIndex = 0,
    this.sort,
  });

  final int collectionId;
  final int startIndex;

  /// 详情页透传的排序表达式（`field:direction`）；手动顺序为 `null`。
  final String? sort;

  @override
  State<MobileVideoCollectionPlayPage> createState() =>
      _MobileVideoCollectionPlayPageState();
}

class _MobileVideoCollectionPlayPageState
    extends State<MobileVideoCollectionPlayPage> {
  @override
  void initState() {
    super.initState();
    unawaited(enterLandscapePlayerSystemUi());
  }

  @override
  void dispose() {
    unawaited(restoreSystemUiAfterLandscapePlayer());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DesktopVideoCollectionPlayPage(
      collectionId: widget.collectionId,
      startIndex: widget.startIndex,
      sort: widget.sort,
      useTouchOptimizedControls: true,
    );
  }
}
