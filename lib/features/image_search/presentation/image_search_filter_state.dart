import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/image_search/data/image_search_target.dart';

enum ImageSearchActorFilterMode { none, includeSelected, excludeSelected }

enum ImageSearchCurrentMovieScope { all, onlyCurrent, excludeCurrent }

extension ImageSearchActorFilterModeLabel on ImageSearchActorFilterMode {
  String get label {
    switch (this) {
      case ImageSearchActorFilterMode.none:
        return '不过滤';
      case ImageSearchActorFilterMode.includeSelected:
        return '仅包含所选';
      case ImageSearchActorFilterMode.excludeSelected:
        return '排除所选';
    }
  }
}

extension ImageSearchCurrentMovieScopeLabel on ImageSearchCurrentMovieScope {
  String get label {
    switch (this) {
      case ImageSearchCurrentMovieScope.all:
        return '全部';
      case ImageSearchCurrentMovieScope.onlyCurrent:
        return '仅当前影片';
      case ImageSearchCurrentMovieScope.excludeCurrent:
        return '排除当前影片';
    }
  }
}

extension ImageSearchTargetLabel on ImageSearchTarget {
  String get label {
    switch (this) {
      case ImageSearchTarget.thumbnail:
        return '缩略图';
      case ImageSearchTarget.plot:
        return '剧情图';
    }
  }
}

class ImageSearchFilterState {
  const ImageSearchFilterState({
    this.searchTarget = ImageSearchTarget.thumbnail,
    this.currentMovieScope = ImageSearchCurrentMovieScope.all,
    this.actorFilterMode = ImageSearchActorFilterMode.none,
    this.selectedActors = const <ActorListItemDto>[],
    this.scoreThreshold,
  });

  final ImageSearchTarget searchTarget;
  final ImageSearchCurrentMovieScope currentMovieScope;
  final ImageSearchActorFilterMode actorFilterMode;
  final List<ActorListItemDto> selectedActors;
  final double? scoreThreshold;

  bool get isDefault =>
      currentMovieScope == ImageSearchCurrentMovieScope.all &&
      actorFilterMode == ImageSearchActorFilterMode.none &&
      selectedActors.isEmpty &&
      scoreThreshold == null;

  int get selectedActorCount => selectedActors.length;

  bool get requiresActorSelection =>
      actorFilterMode != ImageSearchActorFilterMode.none;

  ImageSearchFilterState copyWith({
    ImageSearchTarget? searchTarget,
    ImageSearchCurrentMovieScope? currentMovieScope,
    ImageSearchActorFilterMode? actorFilterMode,
    List<ActorListItemDto>? selectedActors,
    double? scoreThreshold,
    bool clearScoreThreshold = false,
  }) {
    return ImageSearchFilterState(
      searchTarget: searchTarget ?? this.searchTarget,
      currentMovieScope: currentMovieScope ?? this.currentMovieScope,
      actorFilterMode: actorFilterMode ?? this.actorFilterMode,
      selectedActors: selectedActors ?? this.selectedActors,
      scoreThreshold:
          clearScoreThreshold ? null : scoreThreshold ?? this.scoreThreshold,
    );
  }
}
