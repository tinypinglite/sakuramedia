import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/media_library_form.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/cloud115_backend_picker.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/cloud115_library_login_flow.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_inline_action_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';

class MediaLibrariesSection extends ConsumerStatefulWidget {
  const MediaLibrariesSection({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<MediaLibrariesSection> createState() =>
      _MediaLibrariesSectionState();
}

class _MediaLibrariesSectionState extends ConsumerState<MediaLibrariesSection> {
  Future<void> _createLibrary() async {
    final backend = await showMediaLibraryBackendPicker(context);
    if (!mounted || backend == null) {
      return;
    }
    if (backend == MediaLibraryBackend.cloud115) {
      final created = await showCloud115LibraryLoginFlow(context);
      if (!mounted || created == null) {
        return;
      }
      showToast('115 媒体库已创建');
      ref.read(mediaLibrariesProvider.notifier).upsert(created);
      return;
    }

    final payload = await showDialog<CreateMediaLibraryPayload>(
      context: context,
      builder: (dialogContext) => const MediaLibraryDialog(title: '新增媒体库'),
    );
    if (!mounted || payload == null) {
      return;
    }

    try {
      await ref.read(mediaLibrariesProvider.notifier).create(payload);
      showToast('媒体库已创建');
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '创建媒体库失败'));
    }
  }

  Future<void> _reauthLibrary(MediaLibraryDto library) async {
    final updated = await showCloud115LibraryLoginFlow(
      context,
      reauthLibrary: library,
    );
    if (!mounted || updated == null) {
      return;
    }
    showToast('115 媒体库认证已更新');
    ref.read(mediaLibrariesProvider.notifier).upsert(updated);
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
      await ref
          .read(mediaLibrariesProvider.notifier)
          .updateLibrary(libraryId: library.id, payload: payload);
      showToast('媒体库已更新');
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '更新媒体库失败'));
    }
  }

  Future<void> _deleteLibrary(MediaLibraryDto library) async {
    final ok = await showAppConfigDeleteConfirm(
      context: context,
      title: '删除媒体库',
      message: '确认删除媒体库“${library.name}”？该操作不可恢复。',
      onDelete:
          () => ref.read(mediaLibrariesProvider.notifier).delete(library.id),
      successToast: '媒体库已删除',
      failureFallback: '删除媒体库失败',
    );
    if (!ok || !mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final async = ref.watch(mediaLibrariesProvider);
    return async.when(
      loading: () => const AppSectionSkeleton(lineCount: 4),
      error:
          (error, _) => AppSectionError(
            title: '媒体库加载失败',
            message: apiErrorMessage(error, fallback: '媒体库加载失败，请稍后重试。'),
            onRetry: () => ref.read(mediaLibrariesProvider.notifier).reload(),
          ),
      data: (libraries) => _buildLoaded(context, libraries),
    );
  }

  Widget _buildLoaded(BuildContext context, List<MediaLibraryDto> libraries) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '媒体库用于管理本地目录或网盘存储；下载器等本地模块仅使用本地媒体库。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: spacing.lg),
        if (libraries.isEmpty)
          const AppEmptyState(message: '还没有媒体库')
        else
          AppSettingsGroup(
            // 分隔线缩到主标题起点（行左边距 + 图标盒 + 间隙）。
            dividerIndent: spacing.lg + spacing.xxl + spacing.md,
            children: [
              for (final library in libraries)
                AppSettingCell(
                  key: Key('media-library-card-${library.id}'),
                  icon:
                      library.isCloud115
                          ? Icons.cloud_outlined
                          : Icons.folder_open_outlined,
                  title: library.name,
                  subtitle:
                      library.isCloud115
                          ? '115 网盘 · ${library.cloud115App.label}'
                          : library.rootPath,
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
                      if (library.isCloud115) ...[
                        AppInlineActionButton(
                          key: Key('media-library-reauth-${library.id}'),
                          icon: Icons.refresh_rounded,
                          onTap: () => _reauthLibrary(library),
                        ),
                        SizedBox(width: spacing.xs),
                      ],
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

class MediaLibraryDialog extends ConsumerStatefulWidget {
  const MediaLibraryDialog({
    super.key,
    required this.title,
    this.initialLibrary,
  });

  final String title;
  final MediaLibraryDto? initialLibrary;

  @override
  ConsumerState<MediaLibraryDialog> createState() => _MediaLibraryDialogState();
}

class _MediaLibraryDialogState extends ConsumerState<MediaLibraryDialog> {
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
              rootPathEnabled: !_isEditing,
              showRootPath: widget.initialLibrary?.isCloud115 != true,
              labelBuilder:
                  (context, label) => Text(
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
