import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_movie_actions_dialog.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/actions/video_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_actions_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_actions_sheet.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/add_to_video_collection_dialog.dart';
import 'package:sakuramedia/routes/app_routes.dart';

/// 「媒体管理」媒体列表行点击后的动作编排：JAV → 影片操作弹层（播放 / 影片详情），
/// PornBox → 复用视频操作弹窗 / 底部抽屉（播放 / 缩略图 / 加入合集）。
///
/// 弹层只回传用户选择，跳转与起播在这里完成：JAV 走 [launchMoviePlayback]
/// （外部播放器优先、回落应用内播放页）与注入的 [onOpenMovieDetail]；
/// PornBox 的播放 / 缩略图 / 合集跳转由本文件按 [mobile] 选择各自路由。
///
/// [previewWhenNoActions] 供失效媒体等场景使用：记录既没有可打开的影片详情，
/// 也没有 PornBox 视频动作时，仍回退到通用影片操作弹层查看封面和标题。
Future<void> openMediaRowActions(
  BuildContext context,
  WidgetRef ref,
  MediaListItemDto item, {
  required bool mobile,
  void Function(BuildContext context, String movieNumber)? onOpenMovieDetail,
  bool previewWhenNoActions = false,
}) async {
  final movieNumber = item.movieNumber?.trim();
  if (item.isJav && movieNumber != null && movieNumber.isNotEmpty) {
    final action = await showMediaMovieActionsOverlay(
      context: context,
      item: item,
      mobile: mobile,
      canOpenMovieDetail: onOpenMovieDetail != null,
    );
    if (!context.mounted) {
      return;
    }
    switch (action) {
      case MediaMovieAction.play:
        await launchMoviePlayback(
          context,
          movieNumber: movieNumber,
          mediaId: item.id,
        );
      case MediaMovieAction.openMovieDetail:
        onOpenMovieDetail!.call(context, movieNumber);
      case null:
        break;
    }
    return;
  }

  final videoItemId = item.videoItemId;
  if (item.isVideo && videoItemId != null && videoItemId > 0) {
    await _openPornboxActions(
      context,
      ref,
      item,
      videoItemId: videoItemId,
      mobile: mobile,
    );
    return;
  }

  if (previewWhenNoActions) {
    await showMediaMovieActionsOverlay(
      context: context,
      item: item,
      mobile: mobile,
    );
  }
}

/// 媒体行转视频操作弹层的展示数据：列表接口已带标题 / 封面 / 时长 / 合集，
/// 缺的只有视频域字段，按单条媒体可播语义补齐，不再发详情请求。
VideoItemListItemDto _toVideoListItem(MediaListItemDto item, int videoItemId) {
  return VideoItemListItemDto(
    id: videoItemId,
    title: item.title ?? '',
    coverImage: item.coverImage,
    durationSeconds: item.durationSeconds,
    fileSizeBytes: item.fileSizeBytes,
    mediaCount: 1,
    canPlay: item.valid,
    collections: item.collections,
  );
}

Future<void> _openPornboxActions(
  BuildContext context,
  WidgetRef ref,
  MediaListItemDto item, {
  required int videoItemId,
  required bool mobile,
}) {
  final video = _toVideoListItem(item, videoItemId);
  void onPlay() => unawaited(_playVideo(context, video, mobile: mobile));
  void onThumbnails() => _openThumbnails(context, videoItemId, mobile: mobile);
  void onAddToCollection() => unawaited(
    _addToCollection(
      context,
      ref,
      videoItemId: videoItemId,
      collections: item.collections,
      mobile: mobile,
    ),
  );
  void onCollectionTap(VideoCollectionRef collection) =>
      _openCollection(context, collection.id, mobile: mobile);

  if (mobile) {
    return showMobileVideoActionsSheet(
      context,
      video: video,
      onPlay: onPlay,
      onThumbnails: onThumbnails,
      onAddToCollection: onAddToCollection,
      collections: item.collections,
      onCollectionTap: onCollectionTap,
    );
  }
  return showDesktopVideoActionsDialog(
    context,
    video: video,
    onPlay: onPlay,
    onThumbnails: onThumbnails,
    onAddToCollection: onAddToCollection,
    collections: item.collections,
    onCollectionTap: onCollectionTap,
  );
}

/// 播放：外部播放器优先，不可用时进入应用内 PornBox 单视频播放页。
Future<void> _playVideo(
  BuildContext context,
  VideoItemListItemDto video, {
  required bool mobile,
}) async {
  if (await tryLaunchExternalVideoPlayback(
    context,
    videoId: video.id,
    title: video.preferredTitle,
  )) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  if (mobile) {
    await MobileRoutes.videoPlayer(videoId: video.id).push<void>(context);
    return;
  }
  DesktopRoutes.videoPlayer(videoId: video.id).push(context);
}

void _openThumbnails(
  BuildContext context,
  int videoId, {
  required bool mobile,
}) {
  if (mobile) {
    MobileRoutes.videoThumbnail(videoId: videoId).push<void>(context);
    return;
  }
  DesktopRoutes.videoThumbnail(videoId: videoId).push(context);
}

void _openCollection(
  BuildContext context,
  int collectionId, {
  required bool mobile,
}) {
  if (mobile) {
    MobileRoutes.videoCollectionDetail(
      collectionId: collectionId,
    ).push<void>(context);
    return;
  }
  DesktopRoutes.videoCollectionDetail(
    collectionId: collectionId,
  ).push(context);
}

Future<void> _addToCollection(
  BuildContext context,
  WidgetRef ref, {
  required int videoItemId,
  required List<VideoCollectionRef> collections,
  required bool mobile,
}) async {
  await showAddToVideoCollectionDialog(
    context,
    videoItemId: videoItemId,
    collectedRefs: collections,
    presentation: mobile
        ? AddToVideoCollectionPresentation.bottomDrawer
        : AddToVideoCollectionPresentation.dialog,
  );
  // 弹窗内可加入 / 移出（勾选切换）：关闭后统一广播，让 PornBox 列表 / 首页合集横滑区刷新。
  ref
      .read(videoMutationEventsProvider.notifier)
      .reportCollectionMembershipChanged(videoId: videoItemId);
}
