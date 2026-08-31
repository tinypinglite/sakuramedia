import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/pages/shared/image_search_content.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_draft_store_provider.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';

/// 移动以图搜图壳：结果动作全部落到移动路由（相似图搜经 draft store 中转、
/// 播放 / 详情 push 移动子页），预览用底部抽屉；共享实现在 [ImageSearchContent]。
class MobileImageSearchPage extends StatelessWidget {
  const MobileImageSearchPage({
    super.key,
    this.initialFileName,
    this.initialFileBytes,
    this.initialMimeType,
    this.currentMovieNumber,
    this.initialCurrentMovieScope = ImageSearchCurrentMovieScope.all,
  });

  final String? initialFileName;
  final Uint8List? initialFileBytes;
  final String? initialMimeType;
  final String? currentMovieNumber;
  final ImageSearchCurrentMovieScope initialCurrentMovieScope;

  Future<bool> _searchSimilar(
    BuildContext context,
    ImageSearchResultItemDto item,
  ) async {
    final imageUrl = item.image.resolvedUrl;
    final fileName =
        'image_search_${item.movieNumber}_${item.thumbnailId}.${guessImageFileExtension(imageUrl)}';
    try {
      final imageBytes = await ProviderScope.containerOf(
        context,
        listen: false,
      ).read(apiClientProvider).getBytes(imageUrl);
      if (!context.mounted) {
        return false;
      }
      final nextDraftId = ProviderScope.containerOf(context, listen: false)
          .read(imageSearchDraftStoreProvider)
          .save(
            fileName: fileName,
            bytes: imageBytes,
            mimeType: guessImageMimeType(fileName),
          );
      await MobileImageSearchRouteData(
        draftId: nextDraftId,
        currentMovieNumber: item.movieNumber,
      ).push<bool>(context);
      return true;
    } catch (error) {
      if (context.mounted) {
        showToast(apiErrorMessage(error, fallback: '读取结果图片失败，请稍后重试'));
      }
      return false;
    }
  }

  void _openPlayer(BuildContext context, ImageSearchResultItemDto item) {
    MobileMoviePlayerRouteData(
      movieNumber: item.movieNumber,
      mediaId: item.mediaId > 0 ? item.mediaId : null,
      positionSeconds: item.offsetSeconds,
    ).push(context);
  }

  void _openMovieDetail(BuildContext context, ImageSearchResultItemDto item) {
    MobileMovieDetailRouteData(movieNumber: item.movieNumber).push(context);
  }

  @override
  Widget build(BuildContext context) {
    return ImageSearchContent(
      initialFileName: initialFileName,
      initialFileBytes: initialFileBytes,
      initialMimeType: initialMimeType,
      currentMovieNumber: currentMovieNumber,
      initialCurrentMovieScope: initialCurrentMovieScope,
      imagePicker: pickMobileImageSearchFile,
      onSearchSimilar: _searchSimilar,
      onOpenPlayer: _openPlayer,
      onOpenMovieDetail: _openMovieDetail,
      resultPreviewPresentation: ImageSearchResultPreviewPresentation.bottomDrawer,
    );
  }
}
