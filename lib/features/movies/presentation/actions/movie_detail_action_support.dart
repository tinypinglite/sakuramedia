import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';

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
}) {
  switch (action) {
    // 本地动作:只开检查器,不发请求,由页面自行接管。
    case MovieDetailActionType.openInspector:
      return null;
    case MovieDetailActionType.toggleSubscription:
    case MovieDetailActionType.toggleBlacklist:
      return null;
    case MovieDetailActionType.refreshMetadata:
      return MovieDetailRemoteActionSpec(
        request: (api) => api.refreshMovieMetadata(movieNumber: movieNumber),
        successMessage: '影片元数据已刷新',
        failureMessage: '刷新影片元数据失败',
        resetPreview: true,
      );
    case MovieDetailActionType.recomputeHeat:
      return MovieDetailRemoteActionSpec(
        request: (api) => api.recomputeMovieHeat(movieNumber: movieNumber),
        successMessage: '影片热度重算任务已提交，请在活动中心查看进度',
        failureMessage: '计算影片热度失败',
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
  final spec = movieDetailRemoteActionSpecFor(
    action: action,
    movieNumber: movieNumber,
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
    showToast(spec.successMessage);
    return true;
  } catch (error) {
    if (context.mounted) {
      showToast(apiErrorMessage(error, fallback: spec.failureMessage));
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
