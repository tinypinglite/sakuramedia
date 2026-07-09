import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/section_loader_mixin.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/media_library_form.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_inline_action_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';

class MediaLibrariesSection extends StatefulWidget {
  const MediaLibrariesSection({
    super.key,
    required this.active,
    required this.onLibrariesChanged,
  });

  final bool active;
  final VoidCallback onLibrariesChanged;

  @override
  State<MediaLibrariesSection> createState() => _MediaLibrariesSectionState();
}

class _MediaLibrariesSectionState extends State<MediaLibrariesSection>
    with SectionLoaderMixin<List<MediaLibraryDto>, MediaLibrariesSection> {
  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];

  @override
  bool get isSectionActive => widget.active;

  @override
  Future<List<MediaLibraryDto>> fetchSectionData() =>
      context.read<MediaLibrariesApi>().getLibraries();

  @override
  void applySectionData(List<MediaLibraryDto> data) {
    _libraries = data;
  }

  @override
  String get sectionLoadErrorFallback => '媒体库加载失败，请稍后重试。';

  Future<void> _loadLibraries() => loadSectionData();

  @override
  void initState() {
    super.initState();
    tryLoadIfActive();
  }

  @override
  void didUpdateWidget(covariant MediaLibrariesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    tryLoadIfActive();
  }

  Future<void> _createLibrary() async {
    final payload = await showDialog<CreateMediaLibraryPayload>(
      context: context,
      builder: (dialogContext) => const MediaLibraryDialog(title: '新增媒体库'),
    );
    if (!mounted || payload == null) {
      return;
    }

    try {
      await context.read<MediaLibrariesApi>().createLibrary(payload);
      showToast('媒体库已创建');
      widget.onLibrariesChanged();
      await _loadLibraries();
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '创建媒体库失败'));
    }
  }

  Future<void> _editLibrary(MediaLibraryDto library) async {
    final payload = await showDialog<UpdateMediaLibraryPayload>(
      context: context,
      builder:
          (dialogContext) =>
              MediaLibraryDialog(title: '编辑媒体库', initialLibrary: library),
    );
    if (!mounted || payload == null) {
      return;
    }

    try {
      await context.read<MediaLibrariesApi>().updateLibrary(
        libraryId: library.id,
        payload: payload,
      );
      showToast('媒体库已更新');
      widget.onLibrariesChanged();
      await _loadLibraries();
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '更新媒体库失败'));
    }
  }

  Future<void> _deleteLibrary(MediaLibraryDto library) async {
    final api = context.read<MediaLibrariesApi>();
    final ok = await showAppConfigDeleteConfirm(
      context: context,
      title: '删除媒体库',
      message: '确认删除媒体库“${library.name}”？该操作不可恢复。',
      onDelete: () => api.deleteLibrary(library.id),
      successToast: '媒体库已删除',
      failureFallback: '删除媒体库失败',
    );
    if (ok && mounted) {
      widget.onLibrariesChanged();
      await _loadLibraries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildSectionStates(
      errorTitle: '媒体库加载失败',
      buildLoaded: _buildLoaded,
    );
  }

  Widget _buildLoaded(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '媒体库用于维护本地媒体存储根路径，下载器等模块会依赖这里的路径配置。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: spacing.lg),
        if (_libraries.isEmpty)
          const AppEmptyState(message: '还没有媒体库')
        else
          AppSettingsGroup(
            // 分隔线缩到主标题起点（行左边距 + 图标盒 + 间隙）。
            dividerIndent: spacing.lg + spacing.xxl + spacing.md,
            children: [
              for (final library in _libraries)
                AppSettingCell(
                  key: Key('media-library-card-${library.id}'),
                  icon: Icons.folder_open_outlined,
                  title: library.name,
                  subtitle: library.rootPath,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ID ${library.id}',
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.muted,
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      AppInlineActionButton(
                        key: Key('media-library-edit-${library.id}'),
                        icon: Icons.edit_outlined,
                        onTap: () => _editLibrary(library),
                      ),
                      SizedBox(width: spacing.xs),
                      AppInlineActionButton(
                        key: Key('media-library-delete-${library.id}'),
                        icon: Icons.delete_outline,
                        onTap: () => _deleteLibrary(library),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        SizedBox(height: spacing.lg),
        AppSettingsGroup(
          children: [
            AppSettingCell(
              key: const Key('configuration-media-library-create-button'),
              icon: Icons.add_rounded,
              iconColor: Theme.of(context).colorScheme.primary,
              title: '新增媒体库',
              titleTone: AppTextTone.accent,
              titleWeight: AppTextWeight.medium,
              trailing: const AppSettingCellChevron(),
              onTap: _createLibrary,
            ),
          ],
        ),
      ],
    );
  }
}

class MediaLibraryDialog extends StatefulWidget {
  const MediaLibraryDialog({super.key, required this.title, this.initialLibrary});

  final String title;
  final MediaLibraryDto? initialLibrary;

  @override
  State<MediaLibraryDialog> createState() => _MediaLibraryDialogState();
}

class _MediaLibraryDialogState extends State<MediaLibraryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _rootPathController;

  bool get _isEditing => widget.initialLibrary != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialLibrary?.name ?? '',
    );
    _rootPathController = TextEditingController(
      text: widget.initialLibrary?.rootPath ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rootPathController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final value = MediaLibraryFormValue.fromControllers(
      nameController: _nameController,
      rootPathController: _rootPathController,
    );
    if (_isEditing) {
      Navigator.of(context).pop(value.toUpdatePayload());
      return;
    }

    Navigator.of(context).pop(value.toCreatePayload());
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return AppDesktopDialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: context.appLayoutTokens.dialogInsetPadding,
        vertical: context.appLayoutTokens.dialogInsetPadding,
      ),
      width: context.appLayoutTokens.dialogWidthMd,
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
            MediaLibraryFormFields(
              nameController: _nameController,
              rootPathController: _rootPathController,
              labelBuilder: (context, label) => Text(
                label,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
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
