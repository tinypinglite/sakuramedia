import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/clip_collections/presentation/desktop_clip_collection_play_page.dart';
import 'package:sakuramedia/widgets/movie_player/landscape_player_system_ui.dart';

/// 移动端切片合集连播页：在桌面连播页（左播放器 + 右队列）外薄包一层横屏沉浸式
/// `SystemChrome`，对齐 `MobileMoviePlayerPage` 的包壳复用方式。
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
    extends State<MobileClipCollectionPlayPage> {
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
    return DesktopClipCollectionPlayPage(
      collectionId: widget.collectionId,
      startIndex: widget.startIndex,
      useTouchOptimizedControls: true,
    );
  }
}
