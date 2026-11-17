import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/image_search/data/image_search_target.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

enum ImageSearchActorFilterMode { none, includeSelected, excludeSelected }

enum ImageSearchCurrentMovieScope { all, onlyCurrent, excludeCurrent }

extension ImageSearchActorFilterModeLabel on ImageSearchActorFilterMode {
  String label(AppLocalizations l10n) {
    switch (this) {
      case ImageSearchActorFilterMode.none:
        return l10n.imageSearchActorFilterNone;
      case ImageSearchActorFilterMode.includeSelected:
        return l10n.imageSearchActorFilterInclude;
      case ImageSearchActorFilterMode.excludeSelected:
        return l10n.imageSearchActorFilterExclude;
    }
  }
}

extension ImageSearchCurrentMovieScopeLabel on ImageSearchCurrentMovieScope {
  String label(AppLocalizations l10n) {
    switch (this) {
      case ImageSearchCurrentMovieScope.all:
        return l10n.imageSearchMovieScopeAll;
      case ImageSearchCurrentMovieScope.onlyCurrent:
        return l10n.imageSearchMovieScopeOnlyCurrent;
      case ImageSearchCurrentMovieScope.excludeCurrent:
        return l10n.imageSearchMovieScopeExcludeCurrent;
    }
  }
}

extension ImageSearchTargetLabel on ImageSearchTarget {
  String label(AppLocalizations l10n) {
    switch (this) {
      case ImageSearchTarget.thumbnail:
        return l10n.imageSearchTargetThumbnail;
      case ImageSearchTarget.plot:
        return l10n.imageSearchTargetPlot;
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
      searchTarget == ImageSearchTarget.thumbnail &&
      currentMovieScope == ImageSearchCurrentMovieScope.all &&
      actorFilterMode == ImageSearchActorFilterMode.none &&
      scoreThreshold == null;

  int get selectedActorCount => selectedActors.length;

  bool get requiresActorSelection =>
      actorFilterMode != ImageSearchActorFilterMode.none;

  ImageSearchFilterState copyWith({
    ImageSearchTarget? searchTarget,
    ImageSearchCurrentMovieScope? currentMovieScope,
    ImageSearchActorFilterMode? actorFilterMode,
    List<ActorListItemDto>? selectedActors,
  }) {
    return ImageSearchFilterState(
      searchTarget: searchTarget ?? this.searchTarget,
      currentMovieScope: currentMovieScope ?? this.currentMovieScope,
      actorFilterMode: actorFilterMode ?? this.actorFilterMode,
      selectedActors: selectedActors ?? this.selectedActors,
    );
  }
}
