import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

enum MovieDetailActionType {
  castToDevice,
  openExternalPlayer,
  mergePlayback,
  toggleSubscription,
  toggleFavorite,
  openMagnetSearch,
  toggleCollectionType,
  markWatched,
  markUnwatched,
  toggleBlacklist,
  refreshMetadata,
}

class MovieDetailActionDescriptor {
  const MovieDetailActionDescriptor({
    required this.type,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.tone = AppTextTone.primary,
  });

  final MovieDetailActionType type;
  final String label;
  final IconData icon;
  final bool enabled;
  final AppTextTone tone;
}

List<MovieDetailActionDescriptor> buildMovieDetailActionDescriptors({
  required AppLocalizations l10n,
  required bool isSubscribed,
  required bool isCollection,
  required bool isBlacklisted,
  bool isWatched = false,
  bool canCast = false,
  bool canUseExternalPlayer = false,
  bool canMergePlayback = false,
  String? castSessionLabel,
}) {
  return <MovieDetailActionDescriptor>[
    if (canCast || castSessionLabel != null)
      MovieDetailActionDescriptor(
        type: MovieDetailActionType.castToDevice,
        label: castSessionLabel ?? l10n.castPickerTitle,
        icon: Icons.cast_rounded,
      ),
    if (canUseExternalPlayer)
      MovieDetailActionDescriptor(
        type: MovieDetailActionType.openExternalPlayer,
        label: l10n.movieActionPlayExternal,
        icon: Icons.open_in_new_rounded,
      ),
    if (canMergePlayback)
      MovieDetailActionDescriptor(
        type: MovieDetailActionType.mergePlayback,
        label: l10n.moviePageMergedPlayback,
        icon: Icons.merge_rounded,
      ),
    if (!isBlacklisted)
      MovieDetailActionDescriptor(
        type: MovieDetailActionType.toggleSubscription,
        label: isSubscribed
            ? l10n.movieActionUnsubscribeMovie
            : l10n.movieActionSubscribeMovie,
        icon: isSubscribed
            ? Icons.favorite_border_rounded
            : Icons.favorite_rounded,
        tone: isSubscribed ? AppTextTone.error : AppTextTone.primary,
      ),
    MovieDetailActionDescriptor(
      type: MovieDetailActionType.openMagnetSearch,
      label: l10n.widgetMovieMagnetSearchResources,
      icon: Icons.search_rounded,
    ),
    MovieDetailActionDescriptor(
      type: MovieDetailActionType.toggleCollectionType,
      label: isCollection
          ? l10n.movieActionMarkAsSingle
          : l10n.movieActionMarkAsCollection,
      icon: isCollection
          ? Icons.video_library_outlined
          : Icons.collections_bookmark_outlined,
    ),
    MovieDetailActionDescriptor(
      type: isWatched
          ? MovieDetailActionType.markUnwatched
          : MovieDetailActionType.markWatched,
      label: isWatched
          ? l10n.movieActionMarkUnwatched
          : l10n.movieActionMarkWatched,
      icon: isWatched ? Icons.remove_done_rounded : Icons.done_all_rounded,
    ),
    if (isBlacklisted || !isSubscribed)
      MovieDetailActionDescriptor(
        type: MovieDetailActionType.toggleBlacklist,
        label: isBlacklisted
            ? l10n.moviePageUnblacklistAction
            : l10n.movieActionBlacklistMovie,
        icon: isBlacklisted ? Icons.undo_rounded : Icons.block_rounded,
        tone: isBlacklisted ? AppTextTone.primary : AppTextTone.error,
      ),
    MovieDetailActionDescriptor(
      type: MovieDetailActionType.refreshMetadata,
      label: l10n.movieActionRefreshMetadata,
      icon: Icons.sync_rounded,
    ),
  ];
}

List<AppMenuItem<MovieDetailActionType>> buildMovieDetailActionMenuItems(
  List<MovieDetailActionDescriptor> actions,
) {
  final maintenanceGroupStart =
      actions.any(
        (action) => action.type == MovieDetailActionType.toggleBlacklist,
      )
      ? MovieDetailActionType.toggleBlacklist
      : MovieDetailActionType.refreshMetadata;
  return <AppMenuItem<MovieDetailActionType>>[
    for (final action in actions)
      AppMenuItem(
        key: Key('movie-detail-hero-action-${action.type.name}'),
        value: action.type,
        label: action.label,
        icon: action.icon,
        tone: action.tone,
        enabled: action.enabled,
        showDividerBefore:
            action.type == MovieDetailActionType.toggleSubscription ||
            action.type == maintenanceGroupStart,
      ),
  ];
}

Future<MovieDetailActionType?> showMovieDetailDesktopActionMenu({
  required BuildContext context,
  required Offset globalPosition,
  required List<MovieDetailActionDescriptor> actions,
}) {
  return showAppActionMenu<MovieDetailActionType>(
    context: context,
    globalPosition: globalPosition,
    presentation: AppMenuPresentation.popup,
    items: buildMovieDetailActionMenuItems(actions),
  );
}

Future<MovieDetailActionType?> showMovieDetailMobileActionDrawer({
  required BuildContext context,
  required List<MovieDetailActionDescriptor> actions,
}) {
  return showAppActionMenu<MovieDetailActionType>(
    context: context,
    presentation: AppMenuPresentation.bottomDrawer,
    title: AppLocalizations.of(context).movieActionDetailMenuTitle,
    items: buildMovieDetailActionMenuItems(actions),
  );
}
