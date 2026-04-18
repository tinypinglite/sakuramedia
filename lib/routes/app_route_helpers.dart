import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';

String buildRouteLocation({
  required String path,
  required Map<String, String?> queryParameters,
}) {
  final effectiveQueryParameters = <String, String>{};
  for (final entry in queryParameters.entries) {
    final value = entry.value;
    if (value == null || value.isEmpty) {
      continue;
    }
    effectiveQueryParameters[entry.key] = value;
  }
  return Uri(
    path: path,
    queryParameters:
        effectiveQueryParameters.isEmpty ? null : effectiveQueryParameters,
  ).toString();
}

String? resolveStringQueryParameter(
  GoRouterState state, {
  required List<String> names,
  String? fallback,
}) {
  for (final name in names) {
    final value = state.uri.queryParameters[name];
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return fallback;
}

int? resolveIntQueryParameter(
  GoRouterState state, {
  required List<String> names,
  int? fallback,
}) {
  final value = resolveStringQueryParameter(state, names: names);
  return value == null ? fallback : int.tryParse(value) ?? fallback;
}

bool resolveBoolQueryParameter(
  GoRouterState state, {
  required List<String> names,
  required bool fallback,
}) {
  final value = resolveStringQueryParameter(state, names: names);
  switch (value) {
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      return fallback;
  }
}

ImageSearchCurrentMovieScope parseImageSearchCurrentMovieScope(String value) {
  return ImageSearchCurrentMovieScope.values.firstWhere(
    (scope) => scope.name == value,
    orElse: () => ImageSearchCurrentMovieScope.all,
  );
}

AppRouteSpec routeSpecForPath(List<AppRouteSpec> routeSpecs, String path) {
  return routeSpecs.firstWhere((spec) => spec.path == path);
}

String routeSpecNameForPath(List<AppRouteSpec> routeSpecs, String path) {
  return routeSpecForPath(routeSpecs, path).name;
}

Widget buildRouteSpecContent(
  List<AppRouteSpec> routeSpecs,
  String path,
  BuildContext context,
) {
  return routeSpecForPath(routeSpecs, path).builder(context);
}
