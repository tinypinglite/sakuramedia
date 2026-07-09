import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/presentation/invalid_media_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_page_frame.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

class DesktopMediaMaintenancePage extends StatefulWidget {
  const DesktopMediaMaintenancePage({super.key, this.active = true});

  /// 作为系统设置页的 tab 嵌入时用于懒加载：仅在该 tab 激活后才拉取失效媒体。
  /// 作为独立页面使用时保持默认 `true`，进入即加载。
  final bool active;

  @override
  State<DesktopMediaMaintenancePage> createState() =>
      _DesktopMediaMaintenancePageState();
}

class _DesktopMediaMaintenancePageState
    extends State<DesktopMediaMaintenancePage> {
  late final InvalidMediaController _controller;

  @override
  void initState() {
    super.initState();
    _controller = InvalidMediaController(mediaApi: context.read<MediaApi>());
    _controller.attachScrollListener();
    if (widget.active) {
      unawaited(_controller.initialize());
    }
  }

  @override
  void didUpdateWidget(covariant DesktopMediaMaintenancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      unawaited(_controller.initialize());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return AppPageFrame(
          title: '',
          scrollController: _controller.scrollController,
          child: Column(
            key: const Key('desktop-media-maintenance-page'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MediaMaintenanceHeader(
                total: _controller.total,
                isRefreshing: _controller.isInitialLoading,
                onRefresh: () => unawaited(_controller.reload()),
              ),
              SizedBox(height: context.appSpacing.lg),
              _buildBody(context),
              if (_controller.items.isNotEmpty &&
                  (_controller.isLoadingMore ||
                      _controller.loadMoreErrorMessage != null)) ...[
                SizedBox(height: context.appSpacing.lg),
                AppPagedLoadMoreFooter(
                  isLoading: _controller.isLoadingMore,
                  errorMessage: _controller.loadMoreErrorMessage,
                  onRetry: _controller.loadMore,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isInitialLoading) {
      return const _MediaMaintenanceLoadingState();
    }

    if (_controller.initialErrorMessage != null) {
      return AppContentCard(
        title: '加载失败',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppEmptyState(message: _controller.initialErrorMessage!),
            SizedBox(height: context.appSpacing.lg),
            Align(
              alignment: Alignment.center,
              child: AppButton(
                key: const Key('invalid-media-initial-retry-button'),
                label: '重试',
                variant: AppButtonVariant.primary,
                onPressed: () => unawaited(_controller.reload()),
              ),
            ),
          ],
        ),
      );
    }

    if (_controller.items.isEmpty) {
      return const AppEmptyState(message: '当前没有失效媒体');
    }

    final isCheckingAnyMedia = _controller.checkingMediaId != null;
    final isDeletingAnyMedia = _controller.deletingMediaId != null;

    return Column(
      children: _controller.items
          .map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: context.appSpacing.md),
              child: _InvalidMediaCard(
                item: item,
                updatedAtText: formatUpdatedAtLabel(item.updatedAt) ?? '更新时间未知',
                isChecking: _controller.checkingMediaId == item.id,
                isDeleting: _controller.deletingMediaId == item.id,
                canCheck: !isCheckingAnyMedia && !isDeletingAnyMedia,
                canDelete:
                    _controller.canDeleteMedia(item.id) &&
                    !isCheckingAnyMedia &&
                    !isDeletingAnyMedia,
                onCheck: () => _checkMedia(item),
                onDelete: () => _deleteMedia(item),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _checkMedia(InvalidMediaDto item) async {
    try {
      final result = await _controller.checkValidity(mediaId: item.id);
      if (!mounted) {
        return;
      }
      showToast(result.validAfter ? '媒体已恢复' : '文件仍不可用，已开放删除');
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '媒体有效性复查失败'));
      }
    }
  }

  Future<void> _deleteMedia(InvalidMediaDto item) async {
    final confirmed = await _confirmDeleteMedia(item);
    if (!mounted || confirmed != true) {
      return;
    }

    try {
      await _controller.deleteInvalidMedia(mediaId: item.id);
      if (mounted) {
        showToast('失效媒体已删除');
      }
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '删除失效媒体失败'));
      }
    }
  }

  Future<bool?> _confirmDeleteMedia(InvalidMediaDto item) {
    return showAppConfirmDialog(
      context,
      title: '删除失效媒体',
      message:
          '确认删除“${item.movieNumber}”的这条失效媒体记录和本地媒体文件？该操作不可恢复。请确认刚才复查后文件仍不可用。',
      confirmLabel: '删除',
      danger: true,
      dialogKey: const Key('invalid-media-delete-confirm-dialog'),
      confirmKey: const Key('invalid-media-delete-confirm-button'),
      cancelKey: const Key('invalid-media-delete-cancel-button'),
    );
  }
}

class _MediaMaintenanceHeader extends StatelessWidget {
  const _MediaMaintenanceHeader({
    required this.total,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final int total;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      title: '失效媒体维护',
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '巡检标记为失效的本地媒体会出现在这里。你可以复查文件是否恢复，或清理已经确认不可用的记录。',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
                SizedBox(height: context.appSpacing.md),
                Text(
                  '共 $total 条失效媒体',
                  key: const Key('invalid-media-total-text'),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.appSpacing.lg),
          AppButton(
            key: const Key('invalid-media-refresh-button'),
            label: isRefreshing ? '刷新中' : '刷新',
            isLoading: isRefreshing,
            variant: AppButtonVariant.primary,
            onPressed: isRefreshing ? null : onRefresh,
          ),
        ],
      ),
    );
  }
}

class _MediaMaintenanceLoadingState extends StatelessWidget {
  const _MediaMaintenanceLoadingState();

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      title: '正在加载',
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: context.appLayoutTokens.emptySectionVerticalPadding,
        ),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: context.appComponentTokens.movieCardLoaderStrokeWidth,
          ),
        ),
      ),
    );
  }
}

class _InvalidMediaCard extends StatelessWidget {
  const _InvalidMediaCard({
    required this.item,
    required this.updatedAtText,
    required this.isChecking,
    required this.isDeleting,
    required this.canCheck,
    required this.canDelete,
    required this.onCheck,
    required this.onDelete,
  });

  final InvalidMediaDto item;
  final String updatedAtText;
  final bool isChecking;
  final bool isDeleting;
  final bool canCheck;
  final bool canDelete;
  final VoidCallback onCheck;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final coverWidth =
        context.appComponentTokens.mobileFollowMovieThinCoverWidth;
    final coverHeight = context.appComponentTokens.mobileFollowMovieCardHeight;

    return AppContentCard(
      title: item.movieNumber,
      headerBottomSpacing: context.appSpacing.md,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InvalidMediaCover(
            movieNumber: item.movieNumber,
            imageUrl: item.preferredCoverUrl,
            fit: item.usesThinCover ? BoxFit.cover : BoxFit.contain,
            width: coverWidth,
            height: coverHeight,
          ),
          SizedBox(width: context.appSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayTitle,
                  key: Key('invalid-media-title-${item.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: context.appSpacing.sm),
                _InvalidMediaMetaLine(label: '媒体库', value: _libraryText(item)),
                _InvalidMediaMetaLine(
                  label: '文件大小',
                  value: _fileSizeText(item),
                ),
                _InvalidMediaMetaLine(label: '更新时间', value: updatedAtText),
                SizedBox(height: context.appSpacing.sm),
                Text(
                  item.path,
                  key: Key('invalid-media-path-${item.id}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.appSpacing.lg),
          Wrap(
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.sm,
            children: [
              AppButton(
                key: Key('invalid-media-check-${item.id}'),
                label: isChecking ? '复查中' : '复查',
                size: AppButtonSize.small,
                isLoading: isChecking,
                onPressed: canCheck ? onCheck : null,
              ),
              AppButton(
                key: Key('invalid-media-delete-${item.id}'),
                label: isDeleting ? '删除中' : (canDelete ? '删除' : '先复查'),
                size: AppButtonSize.small,
                variant: AppButtonVariant.danger,
                isLoading: isDeleting,
                onPressed: canDelete ? onDelete : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _libraryText(InvalidMediaDto item) {
    final name = item.libraryName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return item.libraryId == null ? '媒体库已删除' : '媒体库 ${item.libraryId}';
  }

  String _fileSizeText(InvalidMediaDto item) {
    final bytes = item.fileSizeBytes;
    if (bytes <= 0) {
      return '未知';
    }
    final gib = bytes / (1024 * 1024 * 1024);
    if (gib >= 1) {
      return '${gib.toStringAsFixed(1)} GB';
    }
    final mib = bytes / (1024 * 1024);
    return '${mib.toStringAsFixed(1)} MB';
  }
}

class _InvalidMediaCover extends StatelessWidget {
  const _InvalidMediaCover({
    required this.movieNumber,
    required this.imageUrl,
    required this.fit,
    required this.width,
    required this.height,
  });

  final String movieNumber;
  final String? imageUrl;
  final BoxFit fit;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: context.appRadius.mdBorder,
      child: SizedBox(
        width: width,
        height: height,
        child:
            imageUrl == null || imageUrl!.isEmpty
                ? DecoratedBox(
                  key: Key('invalid-media-cover-placeholder-$movieNumber'),
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceMuted,
                  ),
                  child: Icon(
                    Icons.movie_creation_outlined,
                    size: context.appComponentTokens.iconSize2xl,
                    color: context.appTextPalette.muted,
                  ),
                )
                : MaskedImage(
                  key: Key('invalid-media-cover-$movieNumber'),
                  url: imageUrl!,
                  fit: fit,
                ),
      ),
    );
  }
}

class _InvalidMediaMetaLine extends StatelessWidget {
  const _InvalidMediaMetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.appSpacing.xs),
      child: Row(
        children: [
          Text(
            '$label：',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
