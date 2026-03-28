import 'package:sakuramedia/routes/app_route_paths.dart';

class AppBackDestination {
  const AppBackDestination._();

  static String defaultLocationForPath(String path) {
    if (path.startsWith('/desktop/library/movies/') && path.endsWith('/player')) {
      final movieNumber = path
          .substring('/desktop/library/movies/'.length)
          .split('/player')
          .first;
      return '$desktopMoviesPath/$movieNumber';
    }
    if (path.startsWith('/mobile/library/movies/') && path.endsWith('/player')) {
      final movieNumber = path
          .substring('/mobile/library/movies/'.length)
          .split('/player')
          .first;
      return '$mobileMoviesPath/$movieNumber';
    }
    if (path.startsWith('/desktop/library/movies/')) {
      return desktopMoviesPath;
    }
    if (path.startsWith('/desktop/library/actors/')) {
      return desktopActorsPath;
    }
    if (path.startsWith('/desktop/library/playlists/')) {
      return desktopPlaylistsPath;
    }
    if (path.startsWith('/desktop/search')) {
      return desktopOverviewPath;
    }
    if (path.startsWith('/mobile/library/movies/')) {
      return mobileMoviesPath;
    }
    if (path.startsWith('/mobile/library/actors/')) {
      return mobileActorsPath;
    }
    if (path.startsWith('$mobileOverviewPath/playlists/')) {
      return mobileOverviewPath;
    }
    if (path.startsWith('/mobile/search')) {
      return mobileOverviewPath;
    }
    return path.startsWith('/mobile/') ? mobileOverviewPath : desktopOverviewPath;
  }
}
