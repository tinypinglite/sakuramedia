import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/create_playlist_dialog.dart';
import 'package:sakuramedia/features/playlists/presentation/playlists_overview_controller.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/playlists/playlist_banner_card.dart';

class MobilePlaylistsPage extends StatefulWidget {
  const MobilePlaylistsPage({super.key});

  @override
  State<MobilePlaylistsPage> createState() => _MobilePlaylistsPageState();
}

class _MobilePlaylistsPageState extends State<MobilePlaylistsPage> {
  late final PlaylistsOverviewController _controller;

  @override
  void initState() {
    super.initState();
    final api = context.read<PlaylistsApi>();
    _controller = PlaylistsOverviewController(
      fetchPlaylists:
          ({bool includeSystem = true}) =>
              api.getPlaylists(includeSystem: false),
      fetchPlaylistCoverUrl: (playlistId) async {
        final page = await api.getPlaylistMovies(
          playlistId: playlistId,
          pageSize: 1,
        );
        return page.items.firstOrNull?.coverImage?.bestAvailableUrl;
      },
      createPlaylist: api.createPlaylist,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return ColoredBox(
      key: const Key('mobile-settings-playlists'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: _refreshPlaylists,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.md,
                    spacing.md,
                    spacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final customPlaylists = _controller.playlists
                                .where((item) => !item.isSystem)
                                .toList(growable: false);
                            return _MobilePlaylistsNoticeCard(
                              playlistCount: customPlaylists.length,
                              movieCount: customPlaylists.fold<int>(
                                0,
                                (total, item) => total + item.movieCount,
                              ),
                            );
                          },
                        ),
                        SizedBox(height: spacing.md),
                        _buildContentSection(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              spacing.md,
              spacing.md,
              spacing.md,
              spacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-playlists-create-button'),
                label: '新建播放列表',
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed: _handleCreatePlaylist,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const _MobilePlaylistsLoadingSection();
        }
        if (_controller.errorMessage != null) {
          return _MobilePlaylistsErrorSection(
            message: _controller.errorMessage!,
            onRetry: _controller.load,
          );
        }

        final playlists =
            _controller.playlists.where((item) => !item.isSystem).toList();
        if (playlists.isEmpty) {
          return const _MobilePlaylistsEmptySection();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: playlists
              .expand(
                (playlist) => <Widget>[
                  _MobilePlaylistManagementCard(
                    playlist: playlist,
                    coverImageUrl: _controller.coverUrlFor(playlist.id),
                    onViewTap: () {
                      MobilePlaylistDetailRouteData(
                        playlistId: playlist.id,
                      ).push(context);
                    },
                    onEditTap: () => _handleEditPlaylist(playlist),
                    onDeleteTap: () => _handleDeletePlaylist(playlist),
                  ),
                  if (playlist != playlists.last)
                    SizedBox(height: context.appSpacing.sm),
                ],
              )
              .toList(growable: false),
        );
      },
    );
  }

  Future<void> _refreshPlaylists() async {
    try {
      await _controller.refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '播放列表加载失败，请稍后重试。'));
    }
  }

  Future<void> _handleCreatePlaylist() async {
    final playlist = await showCreatePlaylistDialog(
      context,
      presentation: CreatePlaylistDialogPresentation.bottomDrawer,
    );
    if (!mounted || playlist == null) {
      return;
    }
    _controller.insertPlaylist(playlist);
    unawaited(_syncPlaylistsInBackground());
    showToast('播放列表已创建');
  }

  Future<void> _handleEditPlaylist(PlaylistDto playlist) async {
    final updated = await showMobileEditPlaylistDrawer(
      context,
      playlist: playlist,
    );
    if (!mounted || updated == null) {
      return;
    }
    _controller.replacePlaylist(updated);
    unawaited(_syncPlaylistsInBackground());
  }

  Future<void> _handleDeletePlaylist(PlaylistDto playlist) async {
    final deletedPlaylistId = await showMobileDeletePlaylistDrawer(
      context,
      playlist: playlist,
    );
    if (!mounted || deletedPlaylistId == null) {
      return;
    }
    _controller.removePlaylist(deletedPlaylistId);
    unawaited(_syncPlaylistsInBackground());
  }

  Future<void> _syncPlaylistsInBackground() async {
    try {
      await _controller.refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '播放列表加载失败，请稍后重试。'));
    }
  }
}

Future<PlaylistDto?> showMobileEditPlaylistDrawer(
  BuildContext context, {
  required PlaylistDto playlist,
}) {
  return showAppBottomDrawer<PlaylistDto>(
    context: context,
    drawerKey: const Key('mobile-playlist-edit-drawer'),
    heightFactor: 0.62,
    builder: (drawerContext) => _MobilePlaylistEditDrawer(playlist: playlist),
  );
}

Future<int?> showMobileDeletePlaylistDrawer(
  BuildContext context, {
  required PlaylistDto playlist,
}) {
  return showAppBottomDrawer<int>(
    context: context,
    drawerKey: const Key('mobile-playlist-delete-drawer'),
    maxHeightFactor: 0.42,
    builder: (drawerContext) => _MobileDeletePlaylistDrawer(playlist: playlist),
  );
}

class _MobilePlaylistsNoticeCard extends StatelessWidget {
  const _MobilePlaylistsNoticeCard({
    required this.playlistCount,
    required this.movieCount,
  });

  final int playlistCount;
  final int movieCount;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      key: const Key('mobile-playlists-notice-card'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.noticeSurface,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.playlist_play_rounded,
                size: context.appComponentTokens.iconSizeMd,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自定义播放列表管理',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      '这里集中维护可手动管理的播放列表，可继续进入详情查看片单内容。',
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
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: _PlaylistStatBlock(
                  label: '自定义播放列表数',
                  value: '$playlistCount',
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: _PlaylistStatBlock(
                  label: '收录影片总数',
                  value: '$movieCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaylistStatBlock extends StatelessWidget {
  const _PlaylistStatBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.appSpacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobilePlaylistManagementCard extends StatelessWidget {
  const _MobilePlaylistManagementCard({
    required this.playlist,
    required this.coverImageUrl,
    required this.onViewTap,
    required this.onEditTap,
    required this.onDeleteTap,
  });

  final PlaylistDto playlist;
  final String? coverImageUrl;
  final VoidCallback onViewTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final description =
        playlist.description.trim().isEmpty
            ? '未填写描述'
            : playlist.description.trim();
    final updatedAt = _formatUpdatedAt(playlist.updatedAt);

    return Container(
      key: Key('mobile-playlist-management-card-${playlist.id}'),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.md, spacing.md, spacing.md, 0),
            child: PlaylistBannerCard(
              key: Key('mobile-playlist-banner-${playlist.id}'),
              title: playlist.name,
              coverImageUrl: coverImageUrl,
              onTap: onViewTap,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  '${playlist.movieCount} 部影片',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  description,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
                if (updatedAt != null) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    '更新时间: $updatedAt',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
                SizedBox(height: spacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        key: Key('mobile-playlist-view-${playlist.id}'),
                        label: '查看详情',
                        size: AppButtonSize.xSmall,
                        onPressed: onViewTap,
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: AppButton(
                        key: Key('mobile-playlist-edit-${playlist.id}'),
                        label: '编辑',
                        size: AppButtonSize.xSmall,
                        onPressed: onEditTap,
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: AppButton(
                        key: Key('mobile-playlist-delete-${playlist.id}'),
                        label: '删除',
                        size: AppButtonSize.xSmall,
                        variant: AppButtonVariant.danger,
                        onPressed: onDeleteTap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobilePlaylistsLoadingSection extends StatelessWidget {
  const _MobilePlaylistsLoadingSection();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      children: List<Widget>.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : spacing.sm),
          child: _MobilePlaylistSkeletonCard(
            key: Key('mobile-playlist-skeleton-$index'),
          ),
        ),
      ),
    );
  }
}

class _MobilePlaylistSkeletonCard extends StatelessWidget {
  const _MobilePlaylistSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: context.appComponentTokens.playlistBannerHeight,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: context.appRadius.lgBorder,
              ),
            ),
            SizedBox(height: spacing.md),
            const _PlaylistSkeletonLine(width: 148, height: 16),
            SizedBox(height: spacing.xs),
            const _PlaylistSkeletonLine(width: 72, height: 12),
            SizedBox(height: spacing.xs),
            const _PlaylistSkeletonLine(width: double.infinity, height: 12),
            SizedBox(height: spacing.sm),
            Row(
              children: List<Widget>.generate(
                3,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == 2 ? 0 : spacing.sm,
                    ),
                    child: Container(
                      height: context.appComponentTokens.buttonHeightXs,
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: context.appRadius.smBorder,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistSkeletonLine extends StatelessWidget {
  const _PlaylistSkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
      ),
    );
  }
}

class _MobilePlaylistsErrorSection extends StatelessWidget {
  const _MobilePlaylistsErrorSection({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      key: const Key('mobile-playlists-error-state'),
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppEmptyState(message: '播放列表加载失败'),
          SizedBox(height: spacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              key: const Key('mobile-playlists-retry-button'),
              label: '重试',
              variant: AppButtonVariant.primary,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobilePlaylistsEmptySection extends StatelessWidget {
  const _MobilePlaylistsEmptySection();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mobile-playlists-empty-state'),
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: const AppEmptyState(message: '还没有自定义播放列表'),
    );
  }
}

class _MobilePlaylistEditDrawer extends StatefulWidget {
  const _MobilePlaylistEditDrawer({required this.playlist});

  final PlaylistDto playlist;

  @override
  State<_MobilePlaylistEditDrawer> createState() =>
      _MobilePlaylistEditDrawerState();
}

class _MobilePlaylistEditDrawerState extends State<_MobilePlaylistEditDrawer> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;

  AutovalidateMode get _autovalidateMode =>
      _hasAttemptedSubmit
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist.name);
    _descriptionController = TextEditingController(
      text: widget.playlist.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '编辑播放列表',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s16,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                '更新当前播放列表的名称和描述，保存后会立即生效。',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: spacing.lg),
              AppTextField(
                fieldKey: const Key('mobile-playlist-name-field'),
                controller: _nameController,
                hintText: '例如：稍后再看',
                enabled: !_isSubmitting,
                autovalidateMode: _autovalidateMode,
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? '请输入播放列表名称'
                            : null,
              ),
              SizedBox(height: spacing.sm),
              AppTextField(
                fieldKey: const Key('mobile-playlist-description-field'),
                controller: _descriptionController,
                hintText: '描述可选',
                enabled: !_isSubmitting,
                autovalidateMode: _autovalidateMode,
                maxLines: 3,
                minLines: 3,
              ),
              SizedBox(height: spacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: '取消',
                      onPressed:
                          _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: AppButton(
                      key: const Key('mobile-playlist-submit-button'),
                      label: '保存',
                      variant: AppButtonVariant.primary,
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_hasAttemptedSubmit) {
      setState(() {
        _hasAttemptedSubmit = true;
      });
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final playlist = await context.read<PlaylistsApi>().updatePlaylist(
        playlistId: widget.playlist.id,
        payload: UpdatePlaylistPayload(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      showToast('播放列表已更新');
      Navigator.of(context).pop(playlist);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '更新播放列表失败'));
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

class _MobileDeletePlaylistDrawer extends StatefulWidget {
  const _MobileDeletePlaylistDrawer({required this.playlist});

  final PlaylistDto playlist;

  @override
  State<_MobileDeletePlaylistDrawer> createState() =>
      _MobileDeletePlaylistDrawerState();
}

class _MobileDeletePlaylistDrawerState
    extends State<_MobileDeletePlaylistDrawer> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '删除播放列表',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          '确认删除播放列表“${widget.playlist.name}”？该操作不可恢复。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: '取消',
                onPressed:
                    _isSubmitting ? null : () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: AppButton(
                key: const Key('mobile-playlist-delete-confirm-button'),
                label: '删除',
                variant: AppButtonVariant.danger,
                isLoading: _isSubmitting,
                onPressed: _deletePlaylist,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _deletePlaylist() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<PlaylistsApi>().deletePlaylist(widget.playlist.id);
      if (!mounted) {
        return;
      }
      showToast('播放列表已删除');
      Navigator.of(context).pop(widget.playlist.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '删除播放列表失败'));
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

String? _formatUpdatedAt(DateTime? updatedAt) {
  if (updatedAt == null) {
    return null;
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(updatedAt.toLocal());
}
