import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_collection_play_content.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/widgets/domain/movies/player/landscape_player_system_ui.dart';

/// 移动端视频合集连播壳：横屏沉浸式 `SystemChrome` 是唯一有状态职责，
/// 播放器全部实现在共享的 [VideoCollectionPlayContent]（`useTouchOptimizedControls: true`）。
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
    return VideoCollectionPlayContent(
      collectionId: widget.collectionId,
      startIndex: widget.startIndex,
      sort: widget.sort,
      imageSearchRoutePath: mobileImageSearchPath,
      useTouchOptimizedControls: true,
    );
  }
}
