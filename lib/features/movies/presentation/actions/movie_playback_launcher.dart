import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/media/playback_resume_policy.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/external_player/data/external_playback_mode.dart';
import 'package:sakuramedia/features/external_player/data/external_player_app.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/data/external_player_selection.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_merge_playback_models.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';

enum MoviePlaybackTarget { auto, inApp, external }

/// 当前配置是否可选择外部播放器。
bool isExternalPlayerAvailable(ExternalPlayerSelection selection) {
  return selection.hasExternalPlayer &&
      const ExternalPlayerChannel().isSupported;
}

/// 统一的影片播放入口：根据用户是否设置了默认外部播放器，决定跳应用内播放页
/// 还是直接拉起外部播放器；[externalPlayer] 可让详情页一次性指定其他播放器。
///
/// 详情接口返回的 [MovieMediaItemDto.playUrl] 已经是后端签名播放地址。前端只
/// 负责补全 URL，外部播放器通道按用户偏好选择传输方式。
Future<void> launchMoviePlayback(
  BuildContext context, {
  required String movieNumber,
  int? mediaId,
  int? positionSeconds,
  MovieDetailDto? movie,
  String? inAppFallbackPath,
  MoviePlaybackTarget target = MoviePlaybackTarget.auto,
  ExternalPlayerApp? externalPlayer,
}) async {
  final selection =
      target != MoviePlaybackTarget.inApp && externalPlayer == null
      ? await readExternalPlayerSelection(context)
      : null;
  if (!context.mounted) {
    return;
  }
  const channel = ExternalPlayerChannel();
  final externalAvailable =
      channel.isSupported &&
      (externalPlayer != null ||
          (selection != null && selection.hasExternalPlayer));
  final canUseExternal =
      target != MoviePlaybackTarget.inApp && externalAvailable;

  if (target == MoviePlaybackTarget.external && !externalAvailable) {
    showToast(
      AppLocalizations.of(context).movieActionExternalPlayerUnavailableInApp,
      tone: AppToastTone.error,
    );
  }

  if (!canUseExternal) {
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
      fallbackPath: inAppFallbackPath,
    );
    return;
  }

  // 外部播放器需要完整直链与标题，按需补齐影片详情。
  var detail = movie;
  if (detail == null) {
    try {
      detail = await ProviderScope.containerOf(
        context,
        listen: false,
      ).read(moviesApiProvider).getMovieDetail(movieNumber: movieNumber);
    } catch (_) {
      detail = null;
    }
    if (!context.mounted) {
      return;
    }
  }

  final media = _resolvePlayableMedia(detail, mediaId);
  final baseUrl = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(sessionStoreProvider).baseUrl;
  final resolvedUrl = media == null
      ? null
      : resolveMediaUrl(rawUrl: media.playUrl, baseUrl: baseUrl);

  // 拿不到后端签名播放地址时回落到应用内播放页。
  if (detail == null ||
      media == null ||
      resolvedUrl == null ||
      resolvedUrl.isEmpty) {
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
      fallbackPath: inAppFallbackPath,
    );
    return;
  }

  final resumeSeconds =
      positionSeconds ??
      (media.progress == null
          ? null
          : resolvePlaybackResumePosition(
              storedPositionSeconds: media.progress!.lastPositionSeconds,
              durationSeconds: media.durationSeconds,
            )?.inSeconds);
  final title = detail.preferredTitle.isNotEmpty
      ? detail.preferredTitle
      : movieNumber;

  final launched = await channel.launch(
    playerId: externalPlayer?.id ?? selection!.playerId!,
    url: resolvedUrl,
    playbackMode: selection?.playbackMode ?? ExternalPlaybackMode.followBackend,
    title: title,
    positionMs: resumeSeconds != null && resumeSeconds > 0
        ? resumeSeconds * 1000
        : null,
  );
  if (!context.mounted) {
    return;
  }
  if (!launched) {
    // 外部播放器不可用（可能已卸载），提示并回落到应用内播放。
    showToast(
      AppLocalizations.of(context).movieActionExternalPlayerUnavailableInApp,
      tone: AppToastTone.error,
    );
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
      fallbackPath: inAppFallbackPath,
    );
  }
}

/// 外部播放器先向后端申请用户选定分段的虚拟 MP4；应用内则直接交接有序媒体。
Future<MovieMergePlaybackSubmission> prepareMovieMergedPlayback(
  BuildContext context, {
  required String movieNumber,
  required MovieDetailDto movie,
  required MovieMergePlaybackSelection selection,
  required ExternalPlayerSelection? externalSelection,
}) async {
  if (externalSelection == null ||
      !isExternalPlayerAvailable(externalSelection)) {
    return MovieMergePlaybackSubmission.inApp(selection: selection);
  }

  final container = ProviderScope.containerOf(context, listen: false);
  final l10n = AppLocalizations.of(context);
  final mergedPlayback = await container
      .read(moviesApiProvider)
      .getMergedPlayback(
        movieNumber: movieNumber,
        libraryId: selection.libraryId,
        mediaIds: selection.mediaIds,
      );
  final resolvedUrl = resolveMediaUrl(
    rawUrl: mergedPlayback.playUrl,
    baseUrl: container.read(sessionStoreProvider).baseUrl,
  );
  if (resolvedUrl == null || resolvedUrl.isEmpty) {
    throw MovieMergePlaybackSubmitException(
      l10n.movieActionMergedPlaybackUrlUnavailable,
    );
  }
  if (!listEquals(
    mergedPlaybackMediaIdsFromUrl(resolvedUrl),
    selection.mediaIds,
  )) {
    throw MovieMergePlaybackSubmitException(
      l10n.movieActionMergedPlaybackSelectionMismatch,
    );
  }
  final title = movie.preferredTitle.trim();
  return MovieMergePlaybackSubmission.external(
    selection: selection,
    externalUrl: resolvedUrl,
    playerId: externalSelection.playerId!,
    title: title.isEmpty ? movieNumber : title,
  );
}

Future<void> launchPreparedMovieMergedPlayback(
  BuildContext context,
  MovieMergePlaybackSubmission submission, {
  required String movieNumber,
}) async {
  if (!submission.usesExternalPlayer) {
    pushMovieMergedPlaybackInApp(
      context,
      movieNumber: movieNumber,
      selection: submission.selection,
    );
    return;
  }
  const channel = ExternalPlayerChannel();
  final launched = await channel.launch(
    playerId: submission.playerId!,
    url: submission.externalUrl!,
    title: submission.title,
  );
  if (context.mounted && !launched) {
    showToast(
      AppLocalizations.of(context).movieActionExternalPlayerUnavailable,
      tone: AppToastTone.error,
    );
  }
}

void pushMovieMergedPlaybackInApp(
  BuildContext context, {
  required String movieNumber,
  required MovieMergePlaybackSelection selection,
}) {
  _pushInAppPlayer(
    context,
    movieNumber: movieNumber,
    mergedLibraryId: selection.libraryId,
    mergedMediaIds: selection.mediaIds,
  );
}

/// 等待偏好加载完成；树上没有 [ProviderScope] 的局部上下文（部分 widget 测试）
/// 或读盘失败时返回 null（降级为应用内播放）。
Future<ExternalPlayerSelection?> readExternalPlayerSelection(
  BuildContext context,
) async {
  try {
    return await ProviderScope.containerOf(
      context,
      listen: false,
    ).read(externalPlayerPreferenceProvider.future);
  } on Object {
    return null;
  }
}

@visibleForTesting
List<int>? mergedPlaybackMediaIdsFromUrl(String url) {
  final values = Uri.tryParse(url)?.queryParametersAll['media_ids'];
  final raw = values == null || values.isEmpty ? null : values.first;
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  final ids = <int>[];
  for (final part in raw.split(',')) {
    final value = int.tryParse(part.trim());
    if (value == null || value <= 0) {
      return null;
    }
    ids.add(value);
  }
  return ids.length < 2 ? null : ids;
}

void _pushInAppPlayer(
  BuildContext context, {
  required String movieNumber,
  int? mediaId,
  int? mergedLibraryId,
  List<int>? mergedMediaIds,
  int? positionSeconds,
  String? fallbackPath,
}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      DesktopRoutes.moviePlayer(
        movieNumber: movieNumber,
        fallbackPath:
            fallbackPath ??
            DesktopRoutes.movieDetail(movieNumber: movieNumber).location,
        mediaId: mediaId,
        mergedLibraryId: mergedLibraryId,
        mergedMediaIds: mergedMediaIds,
        positionSeconds: positionSeconds,
      ).push(context);
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      MobileRoutes.moviePlayer(
        movieNumber: movieNumber,
        mediaId: mediaId,
        mergedLibraryId: mergedLibraryId,
        mergedMediaIds: mergedMediaIds,
        positionSeconds: positionSeconds,
      ).push(context);
  }
}

MovieMediaItemDto? _resolvePlayableMedia(MovieDetailDto? movie, int? mediaId) {
  if (movie == null) {
    return null;
  }
  if (mediaId != null) {
    for (final item in movie.mediaItems) {
      if (item.mediaId == mediaId && item.hasPlayableUrl) {
        return item;
      }
    }
  }
  for (final item in movie.mediaItems) {
    if (item.hasPlayableUrl) {
      return item;
    }
  }
  return null;
}
