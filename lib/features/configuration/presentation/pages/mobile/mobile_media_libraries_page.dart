import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/media_library_form.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/cloud115_backend_picker.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/cloud115_library_login_flow.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_entity_list_card.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';

class MobileMediaLibrariesPage extends ConsumerStatefulWidget {
  const MobileMediaLibrariesPage({super.key});

  @override
  ConsumerState<MobileMediaLibrariesPage> createState() =>
      _MobileMediaLibrariesPageState();
}

class _MobileMediaLibrariesPageState
    extends ConsumerState<MobileMediaLibrariesPage> {
  Future<void> _refreshLibraries() async {
    final message = await ref.read(mediaLibrariesProvider.notifier).refresh();
    if (mounted && message != null) {
      showToast(message);
    }
  }

  Future<void> _handleCreateLibrary() async {
    final backend = await showMediaLibraryBackendPicker(context);
    if (!mounted || backend == null) {
      return;
    }
    final MediaLibraryDto? createdLibrary;
    if (backend == MediaLibraryBackend.cloud115) {
      createdLibrary = await showCloud115LibraryLoginFlow(context);
    } else {
      createdLibrary = await showMobileMediaLibraryEditorDrawer(context);
    }
    if (!mounted || createdLibrary == null) {
      return;
    }
    if (backend == MediaLibraryBackend.cloud115) {
      showToast('115 媒体库已创建');
    }
    _upsertLibrary(createdLibrary);
  }

  Future<void> _handleEditLibrary(MediaLibraryDto library) async {
    final updatedLibrary = await showMobileMediaLibraryEditorDrawer(
      context,
      initialLibrary: library,
    );
    if (!mounted || updatedLibrary == null) {
      return;
    }
    _upsertLibrary(updatedLibrary);
  }

  Future<void> _handleLibraryActions(MediaLibraryDto library) async {
    final action = await showMobileMediaLibraryActionsDrawer(
      context,
      library: library,
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case MobileMediaLibraryAction.edit:
        await _handleEditLibrary(library);
      case MobileMediaLibraryAction.reauth:
        await _handleReauthLibrary(library);
      case MobileMediaLibraryAction.delete:
        await _handleDeleteLibrary(library);
    }
  }

  Future<void> _handleReauthLibrary(MediaLibraryDto library) async {
    final updated = await showCloud115LibraryLoginFlow(
      context,
      reauthLibrary: library,
    );
    if (!mounted || updated == null) {
      return;
    }
    showToast('115 媒体库认证已更新');
    _upsertLibrary(updated);
  }

  Future<void> _handleDeleteLibrary(MediaLibraryDto library) async {
    final ok = await showAppConfigDeleteConfirm(
      context: context,
      title: '删除媒体库',
      message: '确认删除媒体库"${library.name}"？删除后下载器等依赖该路径的配置可能失效，该操作不可恢复。',
      dialogKey: const Key('mobile-media-library-delete-drawer'),
      confirmKey: const Key('mobile-media-library-delete-confirm-button'),
      onDelete:
          () => ref.read(mediaLibrariesProvider.notifier).delete(library.id),
      successToast: '媒体库已删除',
      failureFallback: '删除媒体库失败',
    );
    if (!ok || !mounted) {
      return;
    }
  }

  void _upsertLibrary(MediaLibraryDto library) {
    ref.read(mediaLibrariesProvider.notifier).upsert(library);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final async = ref.watch(mediaLibrariesProvider);

    return ColoredBox(
      key: const Key('mobile-settings-media-libraries'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: _refreshLibraries,
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
                        const AppNoticeCard(
                          key: Key('mobile-media-libraries-notice-card'),
                          leadingIcon: Icons.folder_open_outlined,
                          title: '媒体库存储',
                          description: '媒体库可使用本地目录或 115 网盘；下载器等本地模块仅使用本地媒体库。',
                        ),
                        SizedBox(height: spacing.md),
                        _buildContentSection(context, async),
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
                key: const Key('mobile-media-libraries-create-button'),
                label: '新增媒体库',
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed: _handleCreateLibrary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection(
    BuildContext context,
    AsyncValue<List<MediaLibraryDto>> async,
  ) {
    if (async.isLoading) {
      return const _MobileMediaLibraryLoadingSection();
    }
    if (async.hasError) {
      return AppMobileSectionError(
        key: const Key('mobile-media-libraries-error-state'),
        title: '媒体库加载失败',
        message: apiErrorMessage(async.error!, fallback: '媒体库加载失败，请稍后重试。'),
        onRetry: () => ref.read(mediaLibrariesProvider.notifier).reload(),
        retryButtonKey: const Key('mobile-media-libraries-retry-button'),
      );
    }
    final libraries = async.value ?? const <MediaLibraryDto>[];
    if (libraries.isEmpty) {
      return const MobileConfigEmptyCard(
        key: Key('mobile-media-libraries-empty-state'),
        message: '还没有媒体库',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: libraries
          .expand(
            (library) => <Widget>[
              _buildLibraryCard(context, library),
              if (library != libraries.last)
                SizedBox(height: context.appSpacing.sm),
            ],
          )
          .toList(growable: false),
    );
  }

  Widget _buildLibraryCard(BuildContext context, MediaLibraryDto library) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final avatarSide = componentTokens.iconSizeXl + spacing.md;

    return MobileEntityListCard(
      outerKey: Key('mobile-media-library-card-${library.id}'),
      bodyKey: Key('mobile-media-library-card-body-${library.id}'),
      leading: Container(
        width: avatarSide,
        height: avatarSide,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: Icon(
          library.isCloud115
              ? Icons.cloud_outlined
              : Icons.folder_open_outlined,
          size: componentTokens.iconSizeMd,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        library.name,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.semibold,
          tone: AppTextTone.primary,
        ),
      ),
      body: [
        SizedBox(height: spacing.xs),
        Text(
          library.isCloud115
              ? '115 网盘 · ${library.cloud115App.label}'
              : library.rootPath,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          'ID: ${library.id}',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          '更新时间: ${formatUpdatedAtLabel(library.updatedAt) ?? '未知'}',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
      ],
      onTap: () => _handleEditLibrary(library),
      trailingAction: AppIconButton(
        key: Key('mobile-media-library-more-${library.id}'),
        tooltip: '更多操作',
        backgroundColor: colors.surfaceMuted,
        borderColor: colors.borderSubtle,
        onPressed: () => _handleLibraryActions(library),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }
}

Future<MediaLibraryDto?> showMobileMediaLibraryEditorDrawer(
  BuildContext context, {
  MediaLibraryDto? initialLibrary,
}) {
  return showAppBottomDrawer<MediaLibraryDto>(
    context: context,
    drawerKey: const Key('mobile-media-library-editor-drawer'),
    heightFactor: 0.68,
    builder:
        (drawerContext) =>
            _MobileMediaLibraryEditorDrawer(initialLibrary: initialLibrary),
  );
}

Future<MobileMediaLibraryAction?> showMobileMediaLibraryActionsDrawer(
  BuildContext context, {
  required MediaLibraryDto library,
}) {
  return showAppBottomDrawer<MobileMediaLibraryAction>(
    context: context,
    drawerKey: const Key('mobile-media-library-actions-drawer'),
    maxHeightFactor: library.isCloud115 ? 0.48 : 0.34,
    builder:
        (drawerContext) => _MobileMediaLibraryActionsDrawer(library: library),
  );
}

enum MobileMediaLibraryAction { edit, reauth, delete }

class _MobileMediaLibraryLoadingSection extends StatelessWidget {
  const _MobileMediaLibraryLoadingSection();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      children: List<Widget>.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : spacing.sm),
          child: _MobileMediaLibrarySkeletonCard(
            key: Key('mobile-media-library-skeleton-$index'),
          ),
        ),
      ),
    );
  }
}

class _MobileMediaLibrarySkeletonCard extends StatelessWidget {
  const _MobileMediaLibrarySkeletonCard({super.key});

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
      padding: EdgeInsets.all(spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonBlock(
            width: context.appComponentTokens.iconSizeXl + spacing.md,
            height: context.appComponentTokens.iconSizeXl + spacing.md,
            radius: context.appRadius.mdBorder,
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeletonBlock(width: 136, height: 16),
                SizedBox(height: spacing.xs),
                const AppSkeletonBlock(width: double.infinity, height: 14),
                SizedBox(height: spacing.sm),
                const AppSkeletonBlock(width: 72, height: 12),
                SizedBox(height: spacing.xs),
                const AppSkeletonBlock(width: 148, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileMediaLibraryEditorDrawer extends ConsumerStatefulWidget {
  const _MobileMediaLibraryEditorDrawer({this.initialLibrary});

  final MediaLibraryDto? initialLibrary;

  @override
  ConsumerState<_MobileMediaLibraryEditorDrawer> createState() =>
      _MobileMediaLibraryEditorDrawerState();
}

class _MobileMediaLibraryEditorDrawerState
    extends ConsumerState<_MobileMediaLibraryEditorDrawer> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _rootPathController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _rootPathFocusNode;

  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialLibrary != null;

  AutovalidateMode get _autovalidateMode =>
      _hasAttemptedSubmit
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialLibrary?.name ?? '',
    );
    _rootPathController = TextEditingController(
      text: widget.initialLibrary?.rootPath ?? '',
    );
    _nameFocusNode = FocusNode();
    _rootPathFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rootPathController.dispose();
    _nameFocusNode.dispose();
    _rootPathFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomFormSheet(
      formKey: _formKey,
      title: _isEditing ? '编辑媒体库' : '新增媒体库',
      subtitle:
          widget.initialLibrary?.isCloud115 == true
              ? '媒体库名称可修改，115 登录平台请通过重新认证更新。'
              : '维护可供下载器等模块使用的本地媒体根路径。',
      submitKey: const Key('mobile-media-library-submit-button'),
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      body: MediaLibraryFormFields(
        nameController: _nameController,
        rootPathController: _rootPathController,
        nameFocusNode: _nameFocusNode,
        rootPathFocusNode: _rootPathFocusNode,
        enabled: !_isSubmitting,
        rootPathEnabled: !_isEditing,
        showRootPath: widget.initialLibrary?.isCloud115 != true,
        autovalidateMode: _autovalidateMode,
        onRootPathSubmitted: (_) => _submit(),
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

    final value = MediaLibraryFormValue.fromControllers(
      nameController: _nameController,
      rootPathController: _rootPathController,
    );

    try {
      final library =
          _isEditing
              ? await ref
                  .read(mediaLibrariesProvider.notifier)
                  .updateLibrary(
                    libraryId: widget.initialLibrary!.id,
                    payload: value.toUpdatePayload(),
                  )
              : await ref
                  .read(mediaLibrariesProvider.notifier)
                  .create(value.toCreatePayload());
      if (!mounted) {
        return;
      }
      showToast(_isEditing ? '媒体库已更新' : '媒体库已创建');
      Navigator.of(context).pop(library);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(error, fallback: _isEditing ? '更新媒体库失败' : '创建媒体库失败'),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

class _MobileMediaLibraryActionsDrawer extends StatelessWidget {
  const _MobileMediaLibraryActionsDrawer({required this.library});

  final MediaLibraryDto library;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          library.name,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          library.isCloud115
              ? '115 网盘 · ${library.cloud115App.label}'
              : library.rootPath,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        _MobileDrawerActionRow(
          key: const Key('mobile-media-library-action-edit'),
          icon: Icons.edit_outlined,
          label: '编辑媒体库',
          onTap: () => Navigator.of(context).pop(MobileMediaLibraryAction.edit),
        ),
        if (library.isCloud115) ...[
          SizedBox(height: spacing.sm),
          _MobileDrawerActionRow(
            key: const Key('mobile-media-library-action-reauth'),
            icon: Icons.refresh_rounded,
            label: '重新认证',
            onTap:
                () =>
                    Navigator.of(context).pop(MobileMediaLibraryAction.reauth),
          ),
        ],
        SizedBox(height: spacing.sm),
        _MobileDrawerActionRow(
          key: const Key('mobile-media-library-action-delete'),
          icon: Icons.delete_outline_rounded,
          label: '删除媒体库',
          tone: AppTextTone.error,
          onTap:
              () => Navigator.of(context).pop(MobileMediaLibraryAction.delete),
        ),
      ],
    );
  }
}

class _MobileDrawerActionRow extends StatelessWidget {
  const _MobileDrawerActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = AppTextTone.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppTextTone tone;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final textColor = resolveAppTextToneColor(context, tone);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.appRadius.lgBorder,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.md,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: context.appRadius.lgBorder,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: context.appComponentTokens.iconSizeMd,
                color: textColor,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.medium,
                    tone: tone,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: context.appComponentTokens.iconSizeLg,
                color: context.appTextPalette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
