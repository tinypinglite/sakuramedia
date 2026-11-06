import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/pages/desktop/image_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/pages/mobile/image_search_page.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_draft_store_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';
import 'package:material_ui/material_ui.dart';

class ImageSearchDraftPage extends ConsumerWidget {
  const ImageSearchDraftPage({
    super.key,
    required this.platform,
    this.draftId,
    this.fallbackPath,
    this.currentMovieNumber,
    this.initialCurrentMovieScope = ImageSearchCurrentMovieScope.all,
    this.initialInputKind = ImageSearchInputKind.image,
  });

  final AppPlatform platform;
  final String? draftId;
  final String? fallbackPath;
  final String? currentMovieNumber;
  final ImageSearchCurrentMovieScope initialCurrentMovieScope;
  final ImageSearchInputKind initialInputKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.read(imageSearchDraftStoreProvider).get(draftId);
    if (platform == AppPlatform.desktop) {
      return DesktopImageSearchPage(
        fallbackPath: fallbackPath,
        initialFileName: draft?.fileName,
        initialFileBytes: draft?.bytes,
        initialMimeType: draft?.mimeType,
        currentMovieNumber: currentMovieNumber,
        initialCurrentMovieScope: initialCurrentMovieScope,
        initialInputKind: initialInputKind,
      );
    }
    return MobileImageSearchPage(
      initialFileName: draft?.fileName,
      initialFileBytes: draft?.bytes,
      initialMimeType: draft?.mimeType,
      currentMovieNumber: currentMovieNumber,
      initialCurrentMovieScope: initialCurrentMovieScope,
      initialInputKind: initialInputKind,
    );
  }
}
