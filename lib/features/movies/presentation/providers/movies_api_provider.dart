import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';

part 'movies_api_provider.g.dart';

/// movies 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
MoviesApi moviesApi(Ref ref) {
  return MoviesApi(
    apiClient: ref.watch(apiClientProvider),
    l10n: () => ref.read(appLocalizationsProvider),
  );
}
