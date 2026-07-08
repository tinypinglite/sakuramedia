import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

/// 在合集详情里弹出「添加切片」选择器：勾选我的切片即时加入 / 移出当前合集。
///
/// 关闭方式不固定（X / 点遮罩），不依赖返回值；调用方关闭后刷新合集详情即可。
/// 桌面端用居中弹窗，移动端用底部抽屉（复用 [ClipCollectionEditPresentation]）。
Future<void> showAddClipsToCollectionDialog(
  BuildContext context, {
  required int collectionId,
  required Set<int> memberClipIds,
  ClipCollectionEditPresentation presentation =
      ClipCollectionEditPresentation.dialog,
}) {
  switch (presentation) {
    case ClipCollectionEditPresentation.dialog:
      return showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AddClipsToCollectionDialog(
              collectionId: collectionId,
              memberClipIds: memberClipIds,
            ),
      );
    case ClipCollectionEditPresentation.bottomDrawer:
      return showAppBottomDrawer<void>(
        context: context,
        drawerKey: const Key('add-clips-to-collection-bottom-sheet'),
        heightFactor: 0.8,
        builder:
            (sheetContext) => AddClipsToCollectionDialog(
              collectionId: collectionId,
              memberClipIds: memberClipIds,
              presentation: ClipCollectionEditPresentation.bottomDrawer,
            ),
      );
  }
}

class AddClipsToCollectionDialog extends StatefulWidget {
  const AddClipsToCollectionDialog({
    super.key,
    required this.collectionId,
    required this.memberClipIds,
    this.presentation = ClipCollectionEditPresentation.dialog,
  });

  final int collectionId;
  final Set<int> memberClipIds;
  final ClipCollectionEditPresentation presentation;

  @override
  State<AddClipsToCollectionDialog> createState() =>
      _AddClipsToCollectionDialogState();
}

class _AddClipsToCollectionDialogState
    extends State<AddClipsToCollectionDialog> {
  static const double _checkboxScale = 0.85;
  static const int _pageSize = 24;

  final ScrollController _scrollController = ScrollController();
  final List<MediaClipDto> _clips = <MediaClipDto>[];
  late final Set<int> _memberIds;
  final Set<int> _updatingIds = <int>{};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  int _total = 0;
  String? _errorMessage;

  bool get _hasMore => _clips.length < _total;

  @override
  void initState() {
    super.initState();
    _memberIds = <int>{...widget.memberClipIds};
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 160) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    try {
      final result = await context.read<ClipsApi>().getMyClips(
        page: 1,
        pageSize: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _clips
          ..clear()
          ..addAll(result.items);
        _page = result.page;
        _total = result.total;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = apiErrorMessage(error, fallback: '切片加载失败');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final result = await context.read<ClipsApi>().getMyClips(
        page: _page + 1,
        pageSize: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _clips.addAll(result.items);
        _page = result.page;
        _total = result.total;
      });
    } catch (_) {
      // 加载更多失败保持已有列表，下次滚动可再次触发。
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  bool get _isDrawer =>
      widget.presentation == ClipCollectionEditPresentation.bottomDrawer;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final body = _buildBody(context);
    final content = Column(
      mainAxisSize: _isDrawer ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '添加切片',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.medium,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        // 抽屉高度固定，列表占满剩余空间；弹窗按内容收缩。
        _isDrawer ? Expanded(child: body) : body,
      ],
    );
    if (_isDrawer) {
      return content;
    }
    return AppDesktopDialog(
      dialogKey: const Key('add-clips-to-collection-dialog'),
      width: context.appComponentTokens.playlistDialogWidth,
      child: content,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return _bodyPlaceholder(
        const Center(child: CircularProgressIndicator()),
        key: const Key('add-clips-loading'),
      );
    }
    if (_errorMessage != null) {
      return _bodyPlaceholder(AppEmptyState(message: _errorMessage!));
    }
    if (_clips.isEmpty) {
      return _bodyPlaceholder(const Center(child: Text('还没有切片，去播放器圈选生成吧')));
    }

    final spacing = context.appSpacing;
    final list = ListView.separated(
      key: const Key('add-clips-list'),
      controller: _scrollController,
      // 抽屉里由外层 Expanded 限高，无需 shrinkWrap；弹窗里靠 shrinkWrap + 限高。
      shrinkWrap: !_isDrawer,
      itemCount: _clips.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        if (index >= _clips.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _buildClipOption(context, _clips[index]);
      },
    );
    if (_isDrawer) {
      return list;
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: list,
    );
  }

  /// 加载 / 空 / 错误态占位：抽屉里撑满剩余空间，弹窗里给固定高度。
  Widget _bodyPlaceholder(Widget child, {Key? key}) {
    if (_isDrawer) {
      return SizedBox.expand(key: key, child: child);
    }
    return SizedBox(key: key, height: 240, child: child);
  }

  Widget _buildClipOption(BuildContext context, MediaClipDto clip) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final selected = _memberIds.contains(clip.clipId);
    final isAnyUpdating = _updatingIds.isNotEmpty;
    final coverUrl = clip.coverImage?.bestAvailableUrl;
    final title = clip.title.trim();
    final metaParts = <String>[
      if (clip.movieNumber != null && clip.movieNumber!.isNotEmpty)
        clip.movieNumber!
      else
        '无番号',
      formatMediaTimecode(clip.durationSeconds),
    ];

    return InkWell(
      key: Key('add-clips-option-${clip.clipId}'),
      borderRadius: context.appRadius.xsBorder,
      onTap: isAnyUpdating ? null : () => _toggle(clip),
      child: Container(
        padding: EdgeInsets.all(spacing.xs),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.xsBorder,
          border: Border.all(
            color:
                selected
                    ? Theme.of(context).colorScheme.primary
                    : colors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Transform.scale(
              scale: _checkboxScale,
              child: Checkbox(
                key: Key('add-clips-checkbox-${clip.clipId}'),
                value: selected,
                onChanged: isAnyUpdating ? null : (_) => _toggle(clip),
              ),
            ),
            ClipRRect(
              borderRadius: context.appRadius.xsBorder,
              child: SizedBox(
                width: 72,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child:
                      coverUrl != null && coverUrl.isNotEmpty
                          ? MaskedImage(url: coverUrl, fit: BoxFit.cover)
                          : ColoredBox(color: colors.surfaceMuted),
                ),
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? '未命名切片' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      weight: AppTextWeight.medium,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    metaParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }

  Future<void> _toggle(MediaClipDto clip) async {
    final api = context.read<ClipCollectionsApi>();
    final isMember = _memberIds.contains(clip.clipId);
    setState(() {
      _updatingIds.add(clip.clipId);
      if (isMember) {
        _memberIds.remove(clip.clipId);
      } else {
        _memberIds.add(clip.clipId);
      }
    });
    try {
      if (isMember) {
        await api.removeClipFromCollection(
          collectionId: widget.collectionId,
          clipId: clip.clipId,
        );
      } else {
        await api.addClipToCollection(
          collectionId: widget.collectionId,
          clipId: clip.clipId,
        );
      }
    } catch (error) {
      setState(() {
        if (isMember) {
          _memberIds.add(clip.clipId);
        } else {
          _memberIds.remove(clip.clipId);
        }
      });
      showToast(apiErrorMessage(error, fallback: isMember ? '移出合集失败' : '加入合集失败'));
    } finally {
      if (mounted) {
        setState(() => _updatingIds.remove(clip.clipId));
      }
    }
  }
}
