import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class MovieDetailRemoteActionSpec {
  const MovieDetailRemoteActionSpec({
    required this.request,
    required this.successMessage,
    required this.failureMessage,
    this.resetPreview = false,
  });

  // 返回非 MovieDetailDto 表示排队型动作（202）：只提示已提交，不回填影片详情。
  final Future<Object?> Function(MoviesApi api) request;
  final String successMessage;
  final String failureMessage;
  final bool resetPreview;
}

class MovieDetailApplyResult {
  const MovieDetailApplyResult({
    required this.selectedMediaId,
    this.isSubscribedOverride,
    this.isCollectionOverride,
  });

  final int? selectedMediaId;
  final bool? isSubscribedOverride;
  final bool? isCollectionOverride;
}

/// 详情页取跨页订阅广播的入口——批 8 起 `movieSubscriptionEventsProvider` 是
/// keepAlive 常驻的 Riverpod class Notifier，直接由容器读出。
MovieSubscriptionEvents resolveMovieSubscriptionNotifier(BuildContext context) {
  return ProviderScope.containerOf(
    context,
    listen: false,
  ).read(movieSubscriptionEventsProvider.notifier);
}

MovieDetailRemoteActionSpec? movieDetailRemoteActionSpecFor({
  required MovieDetailActionType action,
  required String movieNumber,
  required AppLocalizations l10n,
}) {
  switch (action) {
    // 本地动作:只投屏,不发请求,由页面自行接管。
    case MovieDetailActionType.castToDevice:
      return null;
    case MovieDetailActionType.toggleSubscription:
    case MovieDetailActionType.toggleFavorite:
    case MovieDetailActionType.openMagnetSearch:
    case MovieDetailActionType.toggleCollectionType:
    case MovieDetailActionType.toggleBlacklist:
      return null;
    case MovieDetailActionType.refreshMetadata:
      return MovieDetailRemoteActionSpec(
        request: (api) => api.refreshMovieMetadata(movieNumber: movieNumber),
        successMessage: l10n.movieActionMovieMetadataRefreshed,
        failureMessage: l10n.movieActionRefreshMovieMetadataFailed,
        resetPreview: true,
      );
    case MovieDetailActionType.recomputeHeat:
      return MovieDetailRemoteActionSpec(
        request: (api) => api.recomputeMovieHeat(movieNumber: movieNumber),
        successMessage: l10n.movieActionHeatRecomputeSubmitted,
        failureMessage: l10n.movieActionRecomputeMovieHeatFailed,
      );
  }
}

/// 详情页远程动作的统一入口。批 8 前 `controller: MovieDetailController` 参数
/// 已改成 `ref + movieNumber`：内部经 `ref.read(movieDetailProvider(movieNumber))`
/// 拿当前 movie / `.notifier.applyMovie(...)` 回写。**测试必须包 ProviderScope**。
Future<bool> executeMovieDetailRemoteAction({
  required BuildContext context,
  required WidgetRef ref,
  required MovieDetailActionType action,
  required String movieNumber,
  required bool isLocked,
  required int? selectedMediaId,
  required void Function(MovieDetailActionType? action) onActiveActionChanged,
  required void Function(MovieDetailApplyResult result) onMovieApplied,
}) async {
  final l10n = AppLocalizations.of(context);
  final spec = movieDetailRemoteActionSpecFor(
    action: action,
    movieNumber: movieNumber,
    l10n: l10n,
  );
  if (spec == null || isLocked) {
    return false;
  }

  onActiveActionChanged(action);
  try {
    final response = await spec.request(ref.read(moviesApiProvider));
    if (!context.mounted) {
      return false;
    }
    if (response is MovieDetailDto) {
      final applyResult = applyReturnedMovieDetail(
        ref: ref,
        movieNumber: movieNumber,
        movie: response,
        selectedMediaId: selectedMediaId,
        resetPreview: spec.resetPreview,
      );
      onMovieApplied(applyResult);
    }
    showToast(spec.successMessage, tone: AppToastTone.success);
    return true;
  } catch (error) {
    if (context.mounted) {
      showToast(
        apiErrorMessage(error, fallback: spec.failureMessage, l10n: l10n),
        tone: AppToastTone.error,
      );
    }
    return false;
  } finally {
    onActiveActionChanged(null);
  }
}

MovieDetailApplyResult applyReturnedMovieDetail({
  required WidgetRef ref,
  required String movieNumber,
  required MovieDetailDto movie,
  required int? selectedMediaId,
  required bool resetPreview,
}) {
  final resolvedSelectedMediaId =
      selectedMediaId != null &&
          movie.mediaItems.any((item) => item.mediaId == selectedMediaId)
      ? selectedMediaId
      : (movie.mediaItems.isNotEmpty ? movie.mediaItems.first.mediaId : null);
  ref
      .read(movieDetailProvider(movieNumber).notifier)
      .applyMovie(movie, resetPreview: resetPreview);
  return MovieDetailApplyResult(
    selectedMediaId: resolvedSelectedMediaId,
    isSubscribedOverride: null,
    isCollectionOverride: null,
  );
}
