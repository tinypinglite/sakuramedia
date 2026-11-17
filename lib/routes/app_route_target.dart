import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_registry.dart';

@immutable
class AppRouteTarget {
  const AppRouteTarget({
    required this.id,
    this.pathParameters = const <String, String>{},
    this.queryParameters = const <String, String?>{},
    this.fallbackPath,
  });

  final AppRouteId id;
  final Map<String, String> pathParameters;
  final Map<String, String?> queryParameters;
  final String? fallbackPath;

  AppRouteDefinition get definition => appRoutes.byId(id);

  String get location => appRoutes.locationOf(
    definition: definition,
    pathParameters: pathParameters,
    queryParameters: queryParameters,
  );

  String get path {
    final value = location;
    final queryIndex = value.indexOf('?');
    return queryIndex < 0 ? value : value.substring(0, queryIndex);
  }

  Object? get extra =>
      fallbackPath == null ? null : AppRouteExtra(fallbackPath: fallbackPath);

  void go(BuildContext context) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    context.go(location, extra: extra);
  }

  Future<T?> push<T>(BuildContext context) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    return context.push<T>(location, extra: extra);
  }

  void pushReplacement(BuildContext context) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    context.pushReplacement(location, extra: extra);
  }

  void replace(BuildContext context) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    context.replace(location, extra: extra);
  }
}
