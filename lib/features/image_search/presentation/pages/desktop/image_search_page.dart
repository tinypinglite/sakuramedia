import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/pages/shared/image_search_content.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';

/// 桌面画面搜索壳：结果动作走桌面默认（push 桌面路由、预览用对话框），
/// 全部实现在共享的 [ImageSearchContent]。
class DesktopImageSearchPage extends StatelessWidget {
  const DesktopImageSearchPage({
    super.key,
    this.fallbackPath,
    this.initialFileName,
    this.initialFileBytes,
    this.initialMimeType,
    this.currentMovieNumber,
    this.initialCurrentMovieScope = ImageSearchCurrentMovieScope.all,
    this.initialInputKind = ImageSearchInputKind.image,
  });

  final String? fallbackPath;
  final String? initialFileName;
  final Uint8List? initialFileBytes;
  final String? initialMimeType;
  final String? currentMovieNumber;
  final ImageSearchCurrentMovieScope initialCurrentMovieScope;
  final ImageSearchInputKind initialInputKind;

  @override
  Widget build(BuildContext context) {
    return ImageSearchContent(
      fallbackPath: fallbackPath,
      initialFileName: initialFileName,
      initialFileBytes: initialFileBytes,
      initialMimeType: initialMimeType,
      currentMovieNumber: currentMovieNumber,
      initialCurrentMovieScope: initialCurrentMovieScope,
      initialInputKind: initialInputKind,
    );
  }
}
