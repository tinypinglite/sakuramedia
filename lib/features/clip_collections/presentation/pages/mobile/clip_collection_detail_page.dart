import 'package:flutter/material.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/shared/clip_collection_detail_content.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/add_clips_to_collection_dialog.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/clip_actions_sheet.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/clip_confirm_drawer.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/clip_player_page.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';

export 'package:sakuramedia/features/clip_collections/presentation/pages/shared/clip_collection_detail_content.dart'
    show ClipCollectionDetailLayout;

/// 移动切片合集详情壳：移动语义（长按进多选 / 底部批量条 / 动作抽屉与确认抽屉 /
/// 标题报返回栏）收在壳里，实现在 [ClipCollectionDetailContent]。
class MobileClipCollectionDetailPage extends StatelessWidget {
  const MobileClipCollectionDetailPage({
    super.key,
    required this.collectionId,
  });

  final int collectionId;

  @override
  Widget build(BuildContext context) {
    return ClipCollectionDetailContent(
      collectionId: collectionId,
      surfaceColor: context.appColors.surfaceCard,
      keyPrefix: 'mobile-clip-collection',
      useMobileSelectionLayout: true,
      hoistTitleToSubpageShell: true,
      enableReorder: false,
      defaultLayout: ClipCollectionDetailLayout.grid,
      loadingBuilder: (_) => const AppMobileSkeletonList(
        key: Key('mobile-clip-collection-detail-loading'),
      ),
      playAllBuilder: (context, {required enabled, required onPlayFrom}) {
        return AppTextButton(
          key: const Key('mobile-clip-collection-play-all-button'),
          label: '播放',
          size: AppTextButtonSize.xSmall,
          onPressed: onPlayFrom,
        );
      },
      onMemberTap: (context, clip, actions) {
        showMobileClipActionsSheet(
          context,
          clip: clip,
          onPlay: () => actions.playSingle(context, clip),
          onOpenMovie: _openMovieCallback(context, clip),
          onRemoveFromCollection: () => actions.remove(clip),
          onDelete: () => actions.delete(clip),
        );
      },
      playSingle: (context, clip) async {
        // 用根 Navigator 推全屏页，覆盖底部导航；切片自带 streamUrl 直接传入。
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder:
                (_) => MobileClipPlayerPage(
                  streamUrl: clip.streamUrl,
                  title: clip.title,
                ),
          ),
        );
      },
      onOpenMovie: (context, clip) {
        final movieNumber = clip.movieNumber;
        if (movieNumber == null || movieNumber.isEmpty) {
          return;
        }
        MobileMovieDetailRouteData(movieNumber: movieNumber).push(context);
      },
      confirm: (
        context, {
        required title,
        required message,
        required confirmLabel,
        required confirmKey,
        drawerKey,
      }) async {
        final confirmed = await showMobileClipConfirmDrawer(
          context,
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          drawerKey: drawerKey,
          confirmButtonKey: confirmKey,
        );
        return confirmed == true;
      },
      onEditCollection: (context, collection) async {
        return showEditClipCollectionDialog(
          context,
          collection: collection,
          presentation: ClipCollectionEditPresentation.bottomDrawer,
        );
      },
      onAddClips: (context, memberClipIds) async {
        await showAddClipsToCollectionDialog(
          context,
          collectionId: collectionId,
          memberClipIds: memberClipIds,
          presentation: ClipCollectionEditPresentation.bottomDrawer,
        );
      },
    );
  }

  VoidCallback? _openMovieCallback(BuildContext context, MediaClipDto clip) {
    final movieNumber = clip.movieNumber;
    if (movieNumber == null || movieNumber.isEmpty) {
      return null;
    }
    return () => MobileMovieDetailRouteData(movieNumber: movieNumber).push(
      context,
    );
  }
}
