import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';

@immutable
class DesktopImageSearchRouteState {
  const DesktopImageSearchRouteState({
    required this.fallbackPath,
    this.initialFileName,
    this.initialFileBytes,
    this.initialMimeType,
    this.currentMovieNumber,
    this.initialCurrentMovieScope = ImageSearchCurrentMovieScope.all,
  });

  final String? fallbackPath;
  final String? initialFileName;
  final Uint8List? initialFileBytes;
  final String? initialMimeType;
  final String? currentMovieNumber;
  final ImageSearchCurrentMovieScope initialCurrentMovieScope;

  static DesktopImageSearchRouteState maybeFromExtra(Object? extra) {
    if (extra is DesktopImageSearchRouteState) {
      return extra;
    }
    if (extra is String && extra.startsWith('/desktop/')) {
      return DesktopImageSearchRouteState(fallbackPath: extra);
    }
    return const DesktopImageSearchRouteState(fallbackPath: null);
  }
}
