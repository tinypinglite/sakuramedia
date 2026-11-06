import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/image_search/presentation/pages/shared/image_search_content.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_draft_store_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';

/// 移动画面搜索壳：结果动作全部落到移动路由（相似图搜经 draft store 中转、
/// 播放 / 详情 push 移动子页），预览用底部抽屉；共享实现在 [ImageSearchContent]。
class MobileImageSearchPage extends StatelessWidget {
  const MobileImageSearchPage({
    super.key,
    this.initialFileName,
    this.initialFileBytes,
    this.initialMimeType,
    this.currentMovieNumber,
    this.initialCurrentMovieScope = ImageSearchCurrentMovieScope.all,
    this.initialInputKind = ImageSearchInputKind.image,
  });

  final String? initialFileName;
  final Uint8List? initialFileBytes;
  final String? initialMimeType;
  final String? currentMovieNumber;
  final ImageSearchCurrentMovieScope initialCurrentMovieScope;
  final ImageSearchInputKind initialInputKind;

  Future<bool> _searchSimilar(
    BuildContext context,
    ImageSearchResultItemDto item,
  ) async {
    final imageUrl = item.image.origin;
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
      final nextDraftId = saveImageSearchDraft(
        context,
        fileName: fileName,
        bytes: imageBytes,
        mimeType: guessImageMimeType(fileName),
      );
      await MobileRoutes.imageSearch(
        draftId: nextDraftId,
        currentMovieNumber: item.movieNumber,
      ).push<bool>(context);
      return true;
    } catch (error) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.imageSearchReadResultImageFailed,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
      }
      return false;
    }
  }

  void _openPlayer(BuildContext context, ImageSearchResultItemDto item) {
    unawaited(
      launchMoviePlayback(
        context,
        movieNumber: item.movieNumber,
        mediaId: item.mediaId > 0 ? item.mediaId : null,
        positionSeconds: item.offsetSeconds,
      ),
    );
  }

  void _openMovieDetail(BuildContext context, ImageSearchResultItemDto item) {
    MobileRoutes.movieDetail(movieNumber: item.movieNumber).push(context);
  }

  @override
  Widget build(BuildContext context) {
    return ImageSearchContent(
      surfaceColor: context.appColors.surfaceCard,
      initialFileName: initialFileName,
      initialFileBytes: initialFileBytes,
      initialMimeType: initialMimeType,
      currentMovieNumber: currentMovieNumber,
      initialCurrentMovieScope: initialCurrentMovieScope,
      initialInputKind: initialInputKind,
      imagePicker: (l10n) => pickMobileImageSearchFile(l10n: l10n),
      onSearchSimilar: _searchSimilar,
      onOpenPlayer: _openPlayer,
      onOpenMovieDetail: _openMovieDetail,
      onOpenActorDetail: (context, actorId) =>
          MobileRoutes.actorDetail(actorId: actorId).push(context),
      resultPreviewPresentation:
          ImageSearchResultPreviewPresentation.bottomDrawer,
    );
  }
}
