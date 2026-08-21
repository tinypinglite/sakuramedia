import 'package:flutter/foundation.dart';

/// Desktop-only navigation metadata that must not be reflected in the URL.
///
/// The fallback is consumed by the desktop shell's top bar when there is no
/// in-app route stack left to pop.  Deep links and refreshes do not carry this
/// object, so they continue to use the canonical fallback for their path.
@immutable
class DesktopNavigationRouteState {
  const DesktopNavigationRouteState({required this.fallbackPath});

  final String? fallbackPath;
}

/// Reads desktop fallback metadata while keeping legacy route extras usable.
///
/// Route extras never become part of a URL, so only internal desktop paths are
/// accepted.  The shell applies any more specific legacy-string policy needed
/// for a given route; this helper is used by fullscreen routes that do not
/// render the shell themselves.
String? desktopNavigationFallbackPathFromExtra(Object? extra) {
  final fallbackPath = switch (extra) {
    DesktopNavigationRouteState(:final fallbackPath) => fallbackPath,
    String value => value,
    _ => null,
  };
  return fallbackPath != null && fallbackPath.startsWith('/desktop/')
      ? fallbackPath
      : null;
}
