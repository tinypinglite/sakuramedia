import 'package:flutter/foundation.dart';

@immutable
class DesktopSearchRouteState {
  const DesktopSearchRouteState({
    required this.fallbackPath,
    required this.useOnlineSearch,
  });

  final String? fallbackPath;
  final bool useOnlineSearch;

  static DesktopSearchRouteState maybeFromExtra(Object? extra) {
    if (extra is DesktopSearchRouteState) {
      return extra;
    }
    if (extra is String && extra.startsWith('/desktop/')) {
      return DesktopSearchRouteState(
        fallbackPath: extra,
        useOnlineSearch: false,
      );
    }
    return const DesktopSearchRouteState(
      fallbackPath: null,
      useOnlineSearch: false,
    );
  }
}
