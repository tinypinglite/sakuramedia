import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/features/playlists/presentation/create_playlist_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_inline_action_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/app_shell/app_settings_group.dart';
import 'package:sakuramedia/widgets/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

class PlaylistsSection extends StatefulWidget {
  const PlaylistsSection({super.key, required this.active});

  final bool active;

  @override
  State<PlaylistsSection> createState() => _PlaylistsSectionState();
}

class _PlaylistsSectionState extends State<PlaylistsSection> {
  bool _initialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<PlaylistDto> _playlists = const <PlaylistDto>[];

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _loadPlaylists();
    }
  }

  @override
  void didUpdateWidget(covariant PlaylistsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_initialized && !_isLoading) {
      _loadPlaylists();
    }
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final playlists = await context.read<PlaylistsApi>().getPlaylists(
        includeSystem: false,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _playlists = playlists
            .where((playlist) => !playlist.isSystem)
            .toList(growable: false);
        _initialized = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '播放列表加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _createPlaylist() async {
    final created = await showCreatePlaylistDialog(context);
    if (!mounted || created == null) {
      return;
    }

    showToast('播放列表已创建');
    await _loadPlaylists();
  }

  Future<void> _editPlaylist(PlaylistDto playlist) async {
    if (!playlist.isMutable) {
      return;
    }

    final payload = await showDialog<UpdatePlaylistPayload>(
      context: context,
      builder:
          (dialogContext) =>
              PlaylistDialog(title: '编辑播放列表', initialPlaylist: playlist),
    );
    if (!mounted || payload == null) {
      return;
    }

    try {
      await context.read<PlaylistsApi>().updatePlaylist(
        playlistId: playlist.id,
        payload: payload,
      );
      showToast('播放列表已更新');
      await _loadPlaylists();
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '更新播放列表失败'));
    }
  }

  Future<void> _deletePlaylist(PlaylistDto playlist) async {
    if (!playlist.isDeletable) {
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除播放列表',
      message: '确认删除播放列表“${playlist.name}”？该操作不可恢复。',
      danger: true,
      confirmLabel: '删除',
    );
    if (!mounted || !confirmed) {
      return;
    }

    try {
      await context.read<PlaylistsApi>().deletePlaylist(playlist.id);
      showToast('播放列表已删除');
      await _loadPlaylists();
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '删除播放列表失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const AppSectionSkeleton(lineCount: 4);
    }

    if (_errorMessage != null) {
      return AppSectionError(
        title: '播放列表加载失败',
        message: _errorMessage!,
        onRetry: _loadPlaylists,
      );
    }

    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_playlists.isEmpty)
          const AppEmptyState(message: '还没有自定义播放列表')
        else
          AppSettingsGroup(
            dividerIndent: spacing.lg + spacing.xxl + spacing.md,
            children: [
              for (final playlist in _playlists)
                AppSettingCell(
                  key: Key('playlist-card-${playlist.id}'),
                  icon: Icons.playlist_play_outlined,
                  title: playlist.name,
                  subtitle: _playlistSubtitle(playlist),
                  trailing: _playlistTrailing(context, playlist),
                ),
            ],
          ),
        SizedBox(height: spacing.lg),
        AppSettingsGroup(
          children: [
            AppSettingCell(
              key: const Key('configuration-playlist-create-button'),
              icon: Icons.add_rounded,
              iconColor: Theme.of(context).colorScheme.primary,
              title: '新建播放列表',
              titleTone: AppTextTone.accent,
              titleWeight: AppTextWeight.medium,
              trailing: const AppSettingCellChevron(),
              onTap: _createPlaylist,
            ),
          ],
        ),
      ],
    );
  }

  String _playlistSubtitle(PlaylistDto playlist) {
    final description = playlist.description.trim();
    if (description.isNotEmpty) {
      return '$description · ${playlist.movieCount} 部';
    }
    return '${playlist.movieCount} 部影片';
  }

  Widget? _playlistTrailing(BuildContext context, PlaylistDto playlist) {
    if (!playlist.isMutable && !playlist.isDeletable) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (playlist.isMutable)
          AppInlineActionButton(
            key: Key('playlist-edit-${playlist.id}'),
            icon: Icons.edit_outlined,
            onTap: () => _editPlaylist(playlist),
          ),
        if (playlist.isMutable && playlist.isDeletable)
          SizedBox(width: context.appSpacing.xs),
        if (playlist.isDeletable)
          AppInlineActionButton(
            key: Key('playlist-delete-${playlist.id}'),
            icon: Icons.delete_outline,
            onTap: () => _deletePlaylist(playlist),
          ),
      ],
    );
  }
}

class PlaylistDialog extends StatefulWidget {
  const PlaylistDialog({super.key, required this.title, required this.initialPlaylist});

  final String title;
  final PlaylistDto initialPlaylist;

  @override
  State<PlaylistDialog> createState() => _PlaylistDialogState();
}

class _PlaylistDialogState extends State<PlaylistDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialPlaylist.name);
    _descriptionController = TextEditingController(
      text: widget.initialPlaylist.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      UpdatePlaylistPayload(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final fieldLabelStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.secondary,
    );

    return AppDesktopDialog(
      width: context.appComponentTokens.playlistDialogWidth,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s18,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: spacing.xl),
            Text('名称', style: fieldLabelStyle),
            SizedBox(height: spacing.sm),
            AppTextField(
              fieldKey: const Key('configuration-playlist-name-field'),
              controller: _nameController,
              hintText: '例如：稍后再看',
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? '请输入播放列表名称'
                          : null,
            ),
            SizedBox(height: spacing.lg),
            Text('描述', style: fieldLabelStyle),
            SizedBox(height: spacing.sm),
            AppTextField(
              fieldKey: const Key('configuration-playlist-description-field'),
              controller: _descriptionController,
              hintText: '描述可选',
            ),
            SizedBox(height: spacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: () => Navigator.of(context).pop(),
                    label: '取消',
                  ),
                ),
                SizedBox(width: context.appSpacing.md),
                Expanded(
                  child: AppButton(
                    onPressed: _submit,
                    label: '保存',
                    variant: AppButtonVariant.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
