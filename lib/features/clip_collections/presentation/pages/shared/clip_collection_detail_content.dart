import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/clip_collection_placeholders.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collection_detail_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collection_detail_state.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/pick_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clip_mutation_events_provider.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/collection_playback_handoff_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_cover_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_member_views.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';
import 'package:skeletonizer/skeletonizer.dart';

typedef ClipPlaySingle =
    Future<void> Function(BuildContext context, MediaClipDto clip);

typedef ClipConfirm =
    Future<bool> Function(
      BuildContext context, {
      required String title,
      required String message,
      required String confirmLabel,
      required Key confirmKey,
      Key? drawerKey,
      Future<void> Function()? onConfirm,
    });

typedef ClipPlayAllBuilder =
    Widget Function(
      BuildContext context, {
      required bool enabled,
      required VoidCallback onPlayFrom,
    });

/// 单条切片动作的执行器（由共享 State 绑定后交给壳渲染动作抽屉 / 直接播放）。
class ClipCollectionMemberActions {
  const ClipCollectionMemberActions({
    required this.playSingle,
    required this.remove,
    required this.delete,
  });

  final ClipPlaySingle playSingle;
  final Future<void> Function(MediaClipDto clip) remove;
  final Future<void> Function(MediaClipDto clip) delete;
}

/// 切片合集详情共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 平台差异收在壳参数与钩子里：`keyPrefix` /
/// `useMobileSelectionLayout` / `hoistTitleToSubpageShell`,
///以及动作抽屉（`onMemberTap`）、单集播放（`playSingle`）、来源影片（`onOpenMovie`）、
/// 确认弹层（`confirm`）、播放全部（`playAllBuilder`）、改名 / 添加切片（`onEditCollection` /
/// `onAddClips`）。批量动作 / 删除 / 连播交接 / 列数推导等逐字重复块全部下沉本层。
/// **「加入其它合集」批量动作是移动独有**；桌面单卡悬停动作行同样提供「加入合集」
/// 单卡入口，本层按 `useMobileSelectionLayout` 门控悬停动作。
class ClipCollectionDetailContent extends ConsumerStatefulWidget {
  const ClipCollectionDetailContent({
    super.key,
    required this.collectionId,
    required this.keyPrefix,
    this.useMobileSelectionLayout = false,
    this.hoistTitleToSubpageShell = false,
    this.playAllBuilder,
    this.onMemberTap,
    this.playSingle,
    this.onOpenMovie,
    this.confirm,
    this.onEditCollection,
    this.onAddClips,
  });

  final int collectionId;
  final String keyPrefix;

  /// 移动端多选布局：多选态顶栏只留退出/计数/全选，批量动作走贴底
  /// `AppSelectionBottomBar`；桌面端批量动作内联在顶栏。
  final bool useMobileSelectionLayout;

  /// 把合集名报给外层移动子页壳的返回栏；桌面端 `false`——标题块留在页内。
  final bool hoistTitleToSubpageShell;

  final ClipPlayAllBuilder? playAllBuilder;

  /// 单条切片点击后的动作（桌面直接播放 / 移动动作抽屉），由壳实现。
  final void Function(
    BuildContext context,
    MediaClipDto clip,
    ClipCollectionMemberActions actions,
  )?
  onMemberTap;

  /// 单集播放（统一走 `launchClipPlayback`：桌面轻量弹窗 / 移动全屏页），由壳实现。
  final ClipPlaySingle? playSingle;

  /// 「来源影片」（桌面 push / 移动 push 路由），由壳实现。
  final void Function(BuildContext context, MediaClipDto clip)? onOpenMovie;

  /// 确认弹层（桌面 dialog / 移动 drawer），由壳实现；`drawerKey` 仅移动端使用。
  final ClipConfirm? confirm;

  /// 改名 / 编辑合集（桌面对话框 / 移动底部抽屉），由壳实现；返回更新后的合集。
  final Future<ClipCollectionDto?> Function(
    BuildContext context,
    ClipCollectionDto collection,
  )?
  onEditCollection;

  /// 添加切片（桌面对话框 / 移动底部抽屉），由壳实现；返回后 content 统一刷新广播。
  final Future<void> Function(BuildContext context, Set<int> memberClipIds)?
  onAddClips;

  @override
  ConsumerState<ClipCollectionDetailContent> createState() =>
      _ClipCollectionDetailContentState();
}

class _ClipCollectionDetailContentState
    extends ConsumerState<ClipCollectionDetailContent>
    with MultiSelectStateMixin<ClipCollectionDetailContent, int> {
  ClipCollectionDetailProvider get _providerRef =>
      clipCollectionDetailProvider(widget.collectionId);

  ClipMutationEvents get _mutationBroadcaster =>
      ref.read(clipMutationEventsProvider.notifier);

  bool get _isMobile => widget.useMobileSelectionLayout;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_providerRef);
    final state = async.value;
    if (widget.hoistTitleToSubpageShell) {
      _reportTitleToShell(state?.collection);
    }
    final isLoading = async.isLoading && state == null;

    final content = Builder(
      builder: (context) {
        if (!isLoading && async.hasError && state == null) {
          return AppEmptyState(
            message: apiErrorMessage(
              async.error!,
              fallback: AppLocalizations.of(
                context,
              ).clipCollectionDetailLoadFailed,
              l10n: AppLocalizations.of(context),
            ),
          );
        }
        if (!isLoading && state == null) {
          return const SizedBox.shrink();
        }
        // loading 用占位数据渲染同一份真实布局，由 [AppSkeletonizer] 灰化，
        // 骨架与数据到位后的首屏严格同形。
        final displayState = isLoading
            ? clipCollectionDetailPlaceholder()
            : state!;
        return AppSkeletonizer(
          enabled: isLoading,
          child: Column(
            key: Key('${widget.keyPrefix}-detail-page-body'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 移动端标题报到返回栏，页面内不再写第二遍大标题。
              if (!widget.hoistTitleToSubpageShell)
                _buildTitleBlock(context, displayState),
              if (!widget.hoistTitleToSubpageShell)
                SizedBox(height: context.appSpacing.md),
              if (selectionMode)
                _buildSelectionHeader(context, displayState)
              else
                _buildListHeader(context, displayState),
              SizedBox(height: context.appSpacing.md),
              Expanded(child: _buildClips(context, displayState)),
              if (_isMobile && selectionMode)
                _buildBatchBar(context, displayState),
            ],
          ),
        );
      },
    );

    if (_isMobile) {
      return content;
    }
    return AppPageRefreshScope(
      onRefresh: ref.read(_providerRef.notifier).refresh,
      child: content,
    );
  }

  // --------------------------------------------------------- 标题块

  /// 标题块（仅桌面）：合集名 + 「编辑合集」+ 「播放全部」主行动。
  Widget _buildTitleBlock(
    BuildContext context,
    ClipCollectionDetailState state,
  ) {
    final collection = state.collection;
    final playAllBuilder = widget.playAllBuilder;
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 标题区整体 Expanded 吃掉剩余空间，主行动才会真的贴右。
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  collection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s18,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              // 多选态隐藏「编辑合集」，避免和批量操作混在一起误触。
              if (!selectionMode) ...[
                SizedBox(width: context.appSpacing.xs),
                AppIconButton(
                  key: Key('${widget.keyPrefix}-rename-button'),
                  tooltip: l10n.clipCollectionEdit,
                  onPressed: () => _editCollection(context),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: context.appComponentTokens.iconSizeSm,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!selectionMode && playAllBuilder != null)
          // 主行动保留品牌底色会显得「加载中也可用」，用 shade 随骨架一起灰化。
          Skeleton.shade(
            child: playAllBuilder(
              context,
              enabled: state.clips.isNotEmpty,
              onPlayFrom: () => _playFrom(0),
            ),
          ),
      ],
    );
  }

  /// 把合集名报给外层返回栏。数据是异步来的，所以用 post-frame 回调写。
  void _reportTitleToShell(ClipCollectionDto? collection) {
    final name = collection?.name.trim() ?? '';
    if (name.isEmpty) {
      return;
    }
    final notifier = AppMobileSubpageTitle.read(context);
    if (notifier == null || notifier.value == name) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        notifier.value = name;
      }
    });
  }

  // --------------------------------------------------------- 顶栏

  /// 成员列表顶栏：桌面玻璃分组，移动端紧凑图标行。
  /// **本页没有筛选维度**——切片合集是手动顺序，不接筛选入口。
  Widget _buildListHeader(
    BuildContext context,
    ClipCollectionDetailState state,
  ) {
    final hasClips = state.clips.isNotEmpty;
    final l10n = AppLocalizations.of(context);
    if (!_isMobile) {
      return AppGlassListHeader(
        leading: Text(
          l10n.clipCollectionAllClipsTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        trailing: AppGlassHeaderGroup(
          children: <Widget>[
            AppGlassHeaderButton(
              key: Key('${widget.keyPrefix}-add-clips-button'),
              icon: Icons.playlist_add_rounded,
              label: l10n.clipCollectionAddClips,
              onTap: () => _addClips(context),
            ),
            if (hasClips)
              AppGlassHeaderButton(
                key: Key('${widget.keyPrefix}-enter-selection-button'),
                icon: Icons.check_circle_outline,
                label: l10n.baseSelect,
                onTap: enterSelection,
              ),
          ],
        ),
      );
    }
    return AppMobileListHeader(
      leading: AppMobileHeaderText(title: l10n.clipCollectionAllClipsTitle),
      actions: <Widget>[
        if (hasClips)
          AppGlassIconButton(
            key: Key('${widget.keyPrefix}-play-all-button'),
            tooltip: l10n.clipCollectionPlayAll,
            icon: Icons.play_arrow_rounded,
            onPressed: () => _playFrom(0),
          ),
        AppGlassIconButton(
          key: Key('${widget.keyPrefix}-add-clips-button'),
          tooltip: l10n.clipCollectionAdd,
          icon: Icons.playlist_add_rounded,
          onPressed: () => _addClips(context),
        ),
        AppGlassIconButton(
          key: Key('${widget.keyPrefix}-rename-button'),
          tooltip: l10n.clipCollectionEdit,
          onPressed: () => _editCollection(context),
          icon: Icons.edit_outlined,
        ),
      ],
    );
  }

  /// 多选态顶栏：桌面原地改写整条顶栏（批量动作内联），移动端只留退出/计数/全选、
  /// 批量动作走贴底 [_buildBatchBar]。
  Widget _buildSelectionHeader(
    BuildContext context,
    ClipCollectionDetailState state,
  ) {
    final clipIds = state.clips.map((clip) => clip.clipId);
    final allSelected = isAllSelected(clipIds);
    final hasSelection = selectedCount > 0;
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.clipCollectionAdd,
      BatchOperationType.clipCollectionRemove,
      BatchOperationType.clipDelete,
    ]);
    final l10n = AppLocalizations.of(context);
    if (_isMobile) {
      return AppMobileSelectionHeader(
        selectionLabel: l10n.clipCollectionSelectedCount(selectedCount),
        exitKey: Key('${widget.keyPrefix}-exit-selection-button'),
        onExitSelection: exitSelection,
        selectAllKey: Key('${widget.keyPrefix}-select-all-button'),
        selectAllTooltip: allSelected
            ? l10n.clipCollectionDeselectAll
            : l10n.clipCollectionSelectAll,
        onToggleAll: () => toggleSelectAll(clipIds),
      );
    }
    return AppGlassSelectionHeader(
      selectionLabel: l10n.clipCollectionSelectedCount(selectedCount),
      selectAllLabel: allSelected
          ? l10n.clipCollectionDeselectAll
          : l10n.clipCollectionSelectAll,
      selectAllKey: Key('${widget.keyPrefix}-select-all-button'),
      onToggleAll: () => toggleSelectAll(clipIds),
      actions: <AppGlassSelectionAction>[
        AppGlassSelectionAction(
          key: Key('${widget.keyPrefix}-batch-remove-button'),
          label: l10n.clipCollectionRemoveFromCollection,
          icon: Icons.playlist_remove_rounded,
          onTap: hasSelection && !submitting ? () => _batchRemove(state) : null,
        ),
        AppGlassSelectionAction(
          key: Key('${widget.keyPrefix}-batch-delete-button'),
          label: l10n.clipCollectionDeleteClips,
          icon: Icons.delete_outline_rounded,
          foregroundColor: context.appTextPalette.error,
          onTap: hasSelection && !submitting ? () => _batchDelete(state) : null,
        ),
      ],
      exitKey: Key('${widget.keyPrefix}-exit-selection-button'),
      onExitSelection: exitSelection,
    );
  }

  Widget _buildBatchBar(BuildContext context, ClipCollectionDetailState state) {
    final hasSelection = selectedCount > 0;
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.clipCollectionAdd,
      BatchOperationType.clipCollectionRemove,
      BatchOperationType.clipDelete,
    ]);
    final l10n = AppLocalizations.of(context);
    return AppSelectionBottomBar(
      key: Key('${widget.keyPrefix}-batch-bottom-bar'),
      actions: [
        AppButton(
          key: Key('${widget.keyPrefix}-batch-add-collection-button'),
          label: l10n.clipCollectionAddToCollection,
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection && !submitting
              ? () => _batchAddToOtherCollection(state)
              : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-remove-button'),
          label: l10n.clipCollectionRemove,
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection && !submitting
              ? () => _batchRemove(state)
              : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-delete-button'),
          label: l10n.commonDelete,
          variant: AppButtonVariant.danger,
          onPressed: hasSelection && !submitting
              ? () => _batchDelete(state)
              : null,
        ),
      ],
    );
  }

  // --------------------------------------------------------- body

  Widget _buildClips(BuildContext context, ClipCollectionDetailState state) {
    if (state.clips.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return AppEmptyState(
        message: _isMobile
            ? l10n.clipCollectionNoClipsMobile
            : l10n.clipCollectionNoClipsDesktop,
      );
    }
    return _buildGrid(context, state);
  }

  Widget _buildGrid(BuildContext context, ClipCollectionDetailState state) {
    final clips = state.clips;
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = resolveAppCardGridColumnCount(
          context,
          width: constraints.maxWidth,
          spacing: spacing.md,
          orientation: AppCardGridOrientation.landscape,
        );
        final grid = GridView.builder(
          key: Key('${widget.keyPrefix}-detail-grid'),
          // 底部 = 区块留白 + 底部安全区：外壳不吞安全区，多选态底部操作条之上
          // 也要留出 home indicator 的高度。
          padding: _isMobile
              ? EdgeInsets.only(
                  bottom: spacing.lg + MediaQuery.paddingOf(context).bottom,
                )
              : EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing.md,
            crossAxisSpacing: spacing.md,
            childAspectRatio: 16 / 9,
          ),
          itemCount: clips.length,
          itemBuilder: (context, index) {
            final clip = clips[index];
            if (_isMobile) {
              return ClipCoverCard(
                key: ValueKey<int>(clip.clipId),
                clip: clip,
                selectionMode: selectionMode,
                isSelected: isSelected(clip.clipId),
                onSelectedChanged: (_) => toggleSelect(clip.clipId),
                onTap: () => _openMemberActions(context, clip),
                onLongPress: selectionMode
                    ? null
                    : () {
                        enterSelection();
                        toggleSelect(clip.clipId);
                      },
              );
            }
            final number = clip.movieNumber?.isNotEmpty == true
                ? clip.movieNumber!
                : l10n.clipCollectionNoMovieNumber;
            final duration = formatMediaTimecode(clip.durationSeconds);
            final playSingle = widget.playSingle;
            final openMovie = _openMovieCallback(clip);
            return CollectionMemberCard(
              key: ValueKey<int>(clip.clipId),
              coverUrl: clip.coverImage?.origin,
              coverAspectRatio: 16 / 9,
              title: number,
              subtitle: duration,
              onPlay: playSingle == null
                  ? null
                  : () => playSingle(context, clip),
              playButtonKey: Key(
                '${widget.keyPrefix}-grid-play-${clip.clipId}',
              ),
              onTap: selectionMode
                  ? () => toggleSelect(clip.clipId)
                  : () => _openMemberActions(context, clip),
              menuKey: Key('${widget.keyPrefix}-grid-menu-${clip.clipId}'),
              onOpenSource: openMovie,
              openSourceLabel: l10n.clipCollectionMovieSource,
              openSourceButtonKey: Key(
                '${widget.keyPrefix}-grid-movie-${clip.clipId}',
              ),
              onAddToCollection: () => _addToOtherCollection(clip),
              addToCollectionButtonKey: Key(
                '${widget.keyPrefix}-grid-add-collection-${clip.clipId}',
              ),
              onRemove: () => _removeClip(clip),
              removeButtonKey: Key(
                '${widget.keyPrefix}-grid-remove-${clip.clipId}',
              ),
              onDelete: () => _deleteClip(clip),
              deleteButtonKey: Key(
                '${widget.keyPrefix}-grid-delete-${clip.clipId}',
              ),
              deleteLabel: l10n.clipCollectionDeleteClips,
              selectionMode: selectionMode,
              isSelected: isSelected(clip.clipId),
            );
          },
        );
        return grid;
      },
    );
  }

  // --------------------------------------------------------- 单条动作

  void _openMemberActions(BuildContext context, MediaClipDto clip) {
    final handler = widget.onMemberTap;
    if (handler == null) {
      return;
    }
    handler(
      context,
      clip,
      ClipCollectionMemberActions(
        playSingle: widget.playSingle ?? (_, __) async {},
        remove: _removeClip,
        delete: _deleteClip,
      ),
    );
  }

  VoidCallback? _openMovieCallback(MediaClipDto clip) {
    final movieNumber = clip.movieNumber;
    if (movieNumber == null || movieNumber.isEmpty) {
      return null;
    }
    final onOpenMovie = widget.onOpenMovie;
    if (onOpenMovie == null) {
      return null;
    }
    return () => onOpenMovie(context, clip);
  }

  Future<void> _playFrom(int index) async {
    final state = ref.read(_providerRef).value;
    if (state == null) {
      return;
    }
    final handoff = ref.read(collectionPlaybackHandoffProvider);
    // 切片自带 streamUrl，把当前列表交给连播页直接用，免其二次全量拉取。
    handoff.offerClips(collectionId: widget.collectionId, clips: state.clips);
    if (_isMobile) {
      MobileClipCollectionPlayRouteData(
        collectionId: widget.collectionId,
        startIndex: index,
      ).push(context);
      return;
    }
    context.pushDesktopClipCollectionPlay(
      collectionId: widget.collectionId,
      startIndex: index,
    );
  }

  Future<void> _removeClip(MediaClipDto clip) async {
    final l10n = AppLocalizations.of(context);
    final error = await ref.read(_providerRef.notifier).removeClip(clip.clipId);
    if (!mounted) {
      return;
    }
    if (error == null) {
      // 合集封面 / 计数可能变化，广播给上层合集列表（首页横滑区、全部合集页）。
      _mutationBroadcaster.reportCollectionMembershipChanged(
        clipId: clip.clipId,
        collectionId: widget.collectionId,
      );
    }
    showToast(
      error ?? l10n.clipCollectionRemovedToast,
      tone: error == null ? AppToastTone.success : AppToastTone.error,
    );
  }

  /// 彻底删除切片本体（含文件，不可恢复，后端从所有合集级联移除）：先确认，再走
  /// notifier 乐观删除并广播 [ClipMutationEvents.reportDeleted]。与「移出合集」不同。
  Future<void> _deleteClip(MediaClipDto clip) async {
    final l10n = AppLocalizations.of(context);
    final title = clip.displayTitle(l10n).trim();
    final label = title.isEmpty ? l10n.clipCollectionUnnamedClip : '“$title”';
    final notifier = ref.read(_providerRef.notifier);
    final confirmed = await _confirm(
      title: l10n.clipCollectionDeleteClips,
      message: l10n.clipCollectionDeleteClipMessage(label),
      confirmLabel: l10n.commonDelete,
      confirmKey: Key('${widget.keyPrefix}-delete-confirm-button'),
      drawerKey: _isMobile ? Key('${widget.keyPrefix}-delete-drawer') : null,
      onConfirm: () => notifier.deleteClip(clip.clipId),
    );
    if (!mounted || !confirmed) {
      return;
    }
    _mutationBroadcaster.reportDeleted(clip.clipId);
    showToast(l10n.clipCollectionClipDeletedToast, tone: AppToastTone.success);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Key confirmKey,
    Key? drawerKey,
    Future<void> Function()? onConfirm,
  }) async {
    final handler = widget.confirm;
    if (handler == null) {
      return false;
    }
    return handler(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      confirmKey: confirmKey,
      drawerKey: drawerKey,
      onConfirm: onConfirm,
    );
  }

  /// 单卡「加入合集」：把该切片加入其它合集（排除当前合集），成功后广播刷新
  /// 目标合集的封面 / 计数。
  Future<void> _addToOtherCollection(MediaClipDto clip) async {
    final l10n = AppLocalizations.of(context);
    final target = await showPickClipCollectionDialog(
      context,
      presentation: _isMobile
          ? PickClipCollectionPresentation.bottomDrawer
          : PickClipCollectionPresentation.dialog,
      excludedCollectionId: widget.collectionId,
    );
    if (!mounted || target == null) {
      return;
    }
    try {
      await ref
          .read(clipCollectionsApiProvider)
          .addClipToCollection(collectionId: target.id, clipId: clip.clipId);
      if (!mounted) {
        return;
      }
      _mutationBroadcaster.reportCollectionMembershipChanged(
        clipId: clip.clipId,
        collectionId: target.id,
      );
      showToast(
        l10n.clipCollectionAddedToToast(target.name),
        tone: AppToastTone.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.clipCollectionAddFailedRetry,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  Future<void> _editCollection(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final collection = ref.read(_providerRef).value?.collection;
    if (collection == null) {
      return;
    }
    final onEditCollection = widget.onEditCollection;
    if (onEditCollection == null) {
      return;
    }
    final updated = await onEditCollection(context, collection);
    if (!mounted || updated == null) {
      return;
    }
    ref.read(_providerRef.notifier).applyCollectionMeta(updated);
    // 合集名称变化，广播给上层合集列表刷新卡片标题。
    _mutationBroadcaster.reportCollectionMembershipChanged(
      collectionId: widget.collectionId,
    );
    showToast(l10n.commonSaved, tone: AppToastTone.success);
  }

  Future<void> _addClips(BuildContext context) async {
    final currentClips =
        ref.read(_providerRef).value?.clips ?? const <MediaClipDto>[];
    final onAddClips = widget.onAddClips;
    if (onAddClips == null) {
      return;
    }
    await onAddClips(context, currentClips.map((clip) => clip.clipId).toSet());
    if (!mounted) {
      return;
    }
    // 选择器内可能增删了成员，回来统一刷新切片列表与计数。
    await ref.read(_providerRef.notifier).refresh();
    if (!mounted) {
      return;
    }
    // 成员 / 封面 / 计数可能变化，广播给上层合集列表。
    _mutationBroadcaster.reportCollectionMembershipChanged(
      collectionId: widget.collectionId,
    );
  }

  // --------------------------------------------------------- 选择 / 批量

  List<MediaClipDto> _selectedClips(ClipCollectionDetailState state) =>
      state.clips.where((c) => isSelected(c.clipId)).toList(growable: false);

  /// 「加入其它合集」批量动作是**移动端独有**（桌面切片合集没有此入口），
  /// 按 `useMobileSelectionLayout` 门控展示；行为两端保持原样。
  Future<void> _batchAddToOtherCollection(
    ClipCollectionDetailState state,
  ) async {
    final selected = _selectedClips(state);
    if (selected.isEmpty) {
      return;
    }
    final ClipCollectionDto? target = await showPickClipCollectionDialog(
      context,
      presentation: PickClipCollectionPresentation.bottomDrawer,
      excludedCollectionId: widget.collectionId,
    );
    if (!mounted || target == null) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.clipCollectionAdd,
      targetCollectionId: target.id,
      ids: selected.map((clip) => clip.clipId).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> _batchRemove(ClipCollectionDetailState state) async {
    final selected = _selectedClips(state);
    if (selected.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.clipCollectionRemoveFromCollection,
      message: l10n.clipCollectionBatchRemoveMessage(selected.length),
      confirmLabel: _isMobile
          ? l10n.clipCollectionRemove
          : l10n.clipCollectionConfirm,
      confirmKey: _batchConfirmKey('remove'),
      drawerKey: _isMobile
          ? Key('${widget.keyPrefix}-batch-remove-drawer')
          : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.clipCollectionRemove,
      targetCollectionId: widget.collectionId,
      ids: selected.map((clip) => clip.clipId).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> _batchDelete(ClipCollectionDetailState state) async {
    final selected = _selectedClips(state);
    if (selected.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.clipCollectionDeleteClips,
      message: l10n.clipCollectionBatchDeleteMessage(selected.length),
      confirmLabel: _isMobile ? l10n.commonDelete : l10n.clipCollectionConfirm,
      confirmKey: _batchConfirmKey('delete'),
      drawerKey: _isMobile
          ? Key('${widget.keyPrefix}-batch-delete-drawer')
          : null,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.clipDelete,
      ids: selected.map((clip) => clip.clipId).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  /// 批量确认按钮 Key：桌面两端共用 `$keyPrefix-batch-confirm-button`，
  /// 移动端按操作区分（remove / delete）。
  Key _batchConfirmKey(String op) {
    if (_isMobile) {
      return Key('${widget.keyPrefix}-batch-$op-confirm-button');
    }
    return Key('${widget.keyPrefix}-batch-confirm-button');
  }
}
