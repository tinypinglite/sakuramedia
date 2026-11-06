import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/cast/data/cast_director.dart';
import 'package:sakuramedia/features/cast/data/cast_session.dart';
import 'package:sakuramedia/features/cast/presentation/providers/cast_session_provider.dart';
import 'package:sakuramedia/features/cast/presentation/widgets/cast_device_picker.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/desktop_routes.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';

/// 打开投屏遥控页（会话已存在或刚投送成功后调用）。
void openCastRemotePage(BuildContext context) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      DesktopCastRemoteRouteData().push(context);
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      MobileCastRemoteRouteData().push(context);
  }
}

/// 影片投屏入口：选择设备投送播放地址，成功后进入遥控页。
Future<void> launchMovieCast(
  BuildContext context, {
  required MovieDetailDto movie,
  required MovieMediaItemDto? selectedMedia,
}) async {
  if (selectedMedia == null || !selectedMedia.hasPlayableUrl) {
    showToast(
      AppLocalizations.of(context).castNoPlayableMedia,
      tone: AppToastTone.error,
    );
    return;
  }
  final baseUrl = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(sessionStoreProvider).baseUrl;
  final resolvedUrl = resolveMediaUrl(
    rawUrl: selectedMedia.playUrl,
    baseUrl: baseUrl,
  );
  if (resolvedUrl == null || resolvedUrl.isEmpty) {
    showToast(
      AppLocalizations.of(context).castPlayUrlUnavailable,
      tone: AppToastTone.error,
    );
    return;
  }
  final title = movie.preferredTitle.isNotEmpty
      ? movie.preferredTitle
      : movie.movieNumber;
  final director = CastDirector(l10n: () => AppLocalizations.of(context));
  final casted = await showCastDevicePicker(
    context: context,
    onCast: (device) => director.cast(
      device: device,
      url: resolvedUrl,
      title: title,
      contentType: _videoContentTypeOf(selectedMedia.fileName),
    ),
  );
  if (casted == null || !context.mounted) {
    return;
  }
  ProviderScope.containerOf(context, listen: false)
      .read(castSessionControllerProvider.notifier)
      .start(
        CastSession(
          device: casted,
          mediaId: selectedMedia.mediaId,
          movieNumber: movie.movieNumber,
          durationSeconds: selectedMedia.durationSeconds,
        ),
      );
  openCastRemotePage(context);
}

String? _videoContentTypeOf(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == fileName.length - 1) {
    return null;
  }
  return switch (fileName.substring(dotIndex + 1).toLowerCase()) {
    'mp4' || 'm4v' => 'video/mp4',
    'mkv' => 'video/x-matroska',
    'ts' => 'video/mp2t',
    'avi' => 'video/x-msvideo',
    'mov' => 'video/quicktime',
    'wmv' => 'video/x-ms-wmv',
    'flv' => 'video/x-flv',
    'webm' => 'video/webm',
    _ => null,
  };
}
