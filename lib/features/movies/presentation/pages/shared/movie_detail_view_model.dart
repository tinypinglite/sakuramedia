import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/clip_placeholders.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart';

typedef PickMovieActors =
    Future<List<ActorListItemDto>?> Function(
      BuildContext context,
      Set<int> existingActorIds,
    );
typedef AddMovieActor = Future<void> Function(int actorId);
typedef RemoveMovieActor = Future<void> Function(int actorId);
typedef RefreshMovieActors = Future<void> Function();

@immutable
class MovieDetailActorActions {
  const MovieDetailActorActions({
    this.pickActors,
    this.addActor,
    this.removeActor,
    this.refreshActors,
  });

  final PickMovieActors? pickActors;
  final AddMovieActor? addActor;
  final RemoveMovieActor? removeActor;
  final RefreshMovieActors? refreshActors;

  bool get canManage =>
      pickActors != null &&
      addActor != null &&
      removeActor != null &&
      refreshActors != null;
}

@immutable
class MovieDetailViewData {
  const MovieDetailViewData({
    required this.movie,
    required this.mediaItems,
    required this.selectedPreviewKey,
    required this.selectedPreviewUrl,
    required this.selectedMediaId,
    required this.similarMovies,
    required this.clips,
    required this.subtitleItems,
  });

  factory MovieDetailViewData.placeholder() {
    final movie = movieDetailPlaceholder();
    return MovieDetailViewData(
      movie: movie,
      mediaItems: movie.mediaItems,
      selectedPreviewKey: '',
      selectedPreviewUrl: null,
      selectedMediaId: null,
      similarMovies: movieListItemPlaceholders(count: 4),
      clips: clipPlaceholders(count: 4),
      subtitleItems: movieSubtitlePlaceholders(),
    );
  }

  final MovieDetailDto movie;
  final List<MovieMediaItemDto> mediaItems;
  final String selectedPreviewKey;
  final String? selectedPreviewUrl;
  final int? selectedMediaId;
  final List<MovieListItemDto> similarMovies;
  final List<MediaClipDto> clips;
  final List<MovieSubtitleItemDto> subtitleItems;
}

@immutable
class MovieDetailViewState {
  const MovieDetailViewState({
    this.isSubscribed = false,
    this.isSubscriptionUpdating = false,
    this.isFavoriteUpdating = false,
    this.isMoreActionsUpdating = false,
    this.isDeletingSelectedMedia = false,
    this.isPlayLoading = false,
    this.mergePlaybackLabel,
    this.isMergePlaybackLoading = false,
    this.isSimilarMoviesLoading = false,
    this.similarMoviesErrorMessage,
    this.isClipsLoading = false,
    this.clipsErrorMessage,
    this.isSubtitlesLoading = false,
    this.subtitleErrorMessage,
  });

  final bool isSubscribed;
  final bool isSubscriptionUpdating;
  final bool isFavoriteUpdating;
  final bool isMoreActionsUpdating;
  final bool isDeletingSelectedMedia;
  final bool isPlayLoading;
  final String? mergePlaybackLabel;
  final bool isMergePlaybackLoading;
  final bool isSimilarMoviesLoading;
  final String? similarMoviesErrorMessage;
  final bool isClipsLoading;
  final String? clipsErrorMessage;
  final bool isSubtitlesLoading;
  final String? subtitleErrorMessage;
}

@immutable
class MovieDetailViewConfig {
  const MovieDetailViewConfig({
    required this.surfaceColor,
    this.contentPadding = EdgeInsets.zero,
    this.showSimilarMovies = true,
    this.ratingPanel,
  });

  final Color surfaceColor;
  final EdgeInsetsGeometry contentPadding;
  final bool showSimilarMovies;
  final Widget? ratingPanel;
}

@immutable
class MovieDetailViewActions {
  const MovieDetailViewActions({
    required this.onInspectorPaneTap,
    required this.onPlaylistTap,
    required this.onMediaSelect,
    this.onFavoriteTap,
    this.onDeleteSelectedMedia,
    this.onEditMediaTags,
    this.onOpenMediaPointPreview,
    this.onRequestMediaPointMenu,
    this.onPlayTap,
    this.onMergePlaybackTap,
    this.onSubscriptionTap,
    this.onMoreActionsTap,
    this.onActorTap,
    this.actorActions = const MovieDetailActorActions(),
    this.onSeriesTap,
    this.onTagTap,
    this.onRequestPlotImageMenu,
    this.onOpenPlotPreview,
    this.onRetrySimilarMovies,
    this.onSimilarMovieTap,
    this.onRetryClips,
    this.onOpenClipActions,
    this.onPlayClip,
    this.onRenameClip,
    this.onDeleteClip,
    this.onAddClipToCollection,
    this.onRetrySubtitles,
    this.onOpenSubtitle,
  });

  factory MovieDetailViewActions.placeholder() {
    return MovieDetailViewActions(
      onInspectorPaneTap: (_) {},
      onPlaylistTap: () {},
      onMediaSelect: (_) {},
    );
  }

  final VoidCallback? onFavoriteTap;
  final ValueChanged<MovieDetailInspectorPane> onInspectorPaneTap;
  final VoidCallback onPlaylistTap;
  final ValueChanged<MovieMediaItemDto> onMediaSelect;
  final ValueChanged<MovieMediaItemDto>? onDeleteSelectedMedia;
  final ValueChanged<MovieMediaItemDto>? onEditMediaTags;
  final void Function(MovieMediaItemDto mediaItem, MovieMediaPointDto point)?
  onOpenMediaPointPreview;
  final Future<void> Function(
    BuildContext menuContext,
    MovieMediaItemDto mediaItem,
    MovieMediaPointDto point,
    Offset globalPosition,
  )?
  onRequestMediaPointMenu;
  final VoidCallback? onPlayTap;
  final VoidCallback? onMergePlaybackTap;
  final VoidCallback? onSubscriptionTap;
  final Future<void> Function(Offset globalPosition)? onMoreActionsTap;
  final ValueChanged<MovieActorDto>? onActorTap;
  final MovieDetailActorActions actorActions;
  final VoidCallback? onSeriesTap;
  final ValueChanged<MovieTagDto>? onTagTap;
  final Future<void> Function(
    BuildContext menuContext,
    int index,
    Offset globalPosition,
  )?
  onRequestPlotImageMenu;
  final ValueChanged<int>? onOpenPlotPreview;
  final VoidCallback? onRetrySimilarMovies;
  final ValueChanged<MovieListItemDto>? onSimilarMovieTap;
  final VoidCallback? onRetryClips;
  final ValueChanged<MediaClipDto>? onOpenClipActions;
  final ValueChanged<MediaClipDto>? onPlayClip;
  final ValueChanged<MediaClipDto>? onRenameClip;
  final ValueChanged<MediaClipDto>? onDeleteClip;
  final ValueChanged<MediaClipDto>? onAddClipToCollection;
  final Future<void> Function()? onRetrySubtitles;
  final Future<void> Function(MovieSubtitleItemDto item)? onOpenSubtitle;
}

@immutable
class MovieDetailDerived {
  const MovieDetailDerived({
    required this.mediaItems,
    required this.isSubscribed,
    required this.isBlacklisted,
    required this.isCollection,
    required this.isActionControlsLocked,
    required this.selectedMedia,
  });

  final List<MovieMediaItemDto> mediaItems;
  final bool isSubscribed;
  final bool isBlacklisted;
  final bool isCollection;
  final bool isActionControlsLocked;
  final MovieMediaItemDto? selectedMedia;
}
