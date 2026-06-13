import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/videos/data/video_item_detail_dto.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/add_to_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/video_detail_controller.dart';
import 'package:sakuramedia/features/videos/presentation/video_edit_dialog.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_media_item_list.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_media_point_gallery.dart';

class DesktopVideoDetailPage extends StatefulWidget {
  const DesktopVideoDetailPage({
    super.key,
    required this.videoId,
    this.fallbackPath,
  });

  final int videoId;
  final String? fallbackPath;

  @override
  State<DesktopVideoDetailPage> createState() => _DesktopVideoDetailPageState();
}

class _DesktopVideoDetailPageState extends State<DesktopVideoDetailPage> {
  late final VideoDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoDetailController(
      videoId: widget.videoId,
      videosApi: context.read<VideosApi>(),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openPlayer() {
    final media = _controller.selectedMedia;
    final query = media != null ? '?mediaId=${media.mediaId}' : '';
    context.go('$desktopVideosPath/${widget.videoId}/player$query');
  }

  Future<void> _openEdit() async {
    final detail = _controller.detail;
    if (detail == null) {
      return;
    }
    final updated = await showVideoEditDialog(context, existing: detail);
    if (updated != null) {
      await _controller.refresh();
    }
  }

  Future<void> _addToCollection() async {
    final added = await showAddToVideoCollectionDialog(
      context,
      videoItemId: widget.videoId,
    );
    if (added == true && mounted) {
      showToast('已加入合集');
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除视频'),
        content: const Text('将删除该视频条目及其媒体文件记录，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final ok = await _controller.deleteVideo();
    if (!mounted) {
      return;
    }
    if (ok) {
      showToast('已删除');
      context.go(widget.fallbackPath ?? desktopVideosPath);
    } else {
      showToast('删除失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = _controller.errorMessage;
          if (error != null) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppEmptyState(message: error),
                SizedBox(height: context.appSpacing.md),
                AppButton(
                  label: '重试',
                  variant: AppButtonVariant.secondary,
                  onPressed: _controller.load,
                ),
              ],
            );
          }
          final detail = _controller.detail;
          if (detail == null) {
            return const AppEmptyState(message: '未找到该视频');
          }
          return SingleChildScrollView(
            key: const Key('video-detail-page'),
            padding: EdgeInsets.all(context.appSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, detail),
                SizedBox(height: context.appSpacing.lg),
                _buildActions(context, detail),
                SizedBox(height: context.appSpacing.xl),
                _buildSectionTitle(context, '媒体源'),
                SizedBox(height: context.appSpacing.md),
                MovieMediaItemList(
                  mediaItems: detail.mediaItems,
                  selectedMediaId: _controller.selectedMediaId,
                  onSelect: (item) => _controller.selectMedia(item.mediaId),
                ),
                SizedBox(height: context.appSpacing.xl),
                _buildSectionTitle(context, '时刻'),
                SizedBox(height: context.appSpacing.md),
                MovieMediaPointGallery(
                  points: _controller.selectedMedia?.points ??
                      const [],
                  emptyMessage: '该媒体暂无标记点',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, VideoItemDetailDto detail) {
    final coverUrl = detail.coverImage?.bestAvailableUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: AspectRatio(
            aspectRatio: context.appComponentTokens.movieCardAspectRatio,
            child: ClipRRect(
              borderRadius: context.appRadius.lgBorder,
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? MaskedImage(url: coverUrl, fit: BoxFit.cover)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceMuted,
                      ),
                      child: Icon(
                        Icons.video_library_outlined,
                        color: context.appTextPalette.muted,
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.preferredTitle,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s20,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              if (detail.summary.trim().isNotEmpty) ...[
                SizedBox(height: context.appSpacing.sm),
                Text(
                  detail.summary,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
              if (detail.tags.isNotEmpty) ...[
                SizedBox(height: context.appSpacing.md),
                _buildChips(
                  context,
                  detail.tags.map((tag) => tag.name).toList(),
                  Icons.sell_outlined,
                ),
              ],
              if (detail.persons.isNotEmpty) ...[
                SizedBox(height: context.appSpacing.sm),
                _buildChips(
                  context,
                  detail.persons.map((person) => person.name).toList(),
                  Icons.person_outline,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChips(BuildContext context, List<String> labels, IconData icon) {
    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.sm,
      children: [
        for (final label in labels)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.appSpacing.sm,
              vertical: context.appSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: context.appColors.surfaceMuted,
              borderRadius: context.appRadius.pillBorder,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: context.appComponentTokens.iconSizeXs,
                  color: context.appTextPalette.secondary,
                ),
                SizedBox(width: context.appSpacing.xs),
                Text(
                  label,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, VideoItemDetailDto detail) {
    return Row(
      children: [
        AppButton(
          key: const Key('video-detail-play-button'),
          label: '播放',
          variant: AppButtonVariant.primary,
          onPressed: detail.canPlay ? _openPlayer : null,
        ),
        SizedBox(width: context.appSpacing.md),
        AppButton(
          label: '编辑',
          variant: AppButtonVariant.secondary,
          onPressed: _openEdit,
        ),
        SizedBox(width: context.appSpacing.md),
        AppButton(
          label: '加入合集',
          variant: AppButtonVariant.secondary,
          onPressed: _addToCollection,
        ),
        SizedBox(width: context.appSpacing.md),
        AppButton(
          label: '删除',
          variant: AppButtonVariant.secondary,
          onPressed: _confirmDelete,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s16,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
    );
  }
}
