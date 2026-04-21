import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/media_libraries_api.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/media_library_form.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

class MobileMediaLibrariesPage extends StatefulWidget {
  const MobileMediaLibrariesPage({super.key});

  @override
  State<MobileMediaLibrariesPage> createState() =>
      _MobileMediaLibrariesPageState();
}

class _MobileMediaLibrariesPageState extends State<MobileMediaLibrariesPage> {
  List<MediaLibraryDto> _libraries = const <MediaLibraryDto>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLibraries());
  }

  Future<void> _loadLibraries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final libraries = await context.read<MediaLibrariesApi>().getLibraries();
      if (!mounted) {
        return;
      }
      setState(() {
        _libraries = libraries;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '媒体库加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _refreshLibraries() async {
    try {
      final libraries = await context.read<MediaLibrariesApi>().getLibraries();
      if (!mounted) {
        return;
      }
      setState(() {
        _libraries = libraries;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '媒体库加载失败，请稍后重试。'));
    }
  }

  Future<void> _handleCreateLibrary() async {
    final createdLibrary = await showMobileMediaLibraryEditorDrawer(context);
    if (!mounted || createdLibrary == null) {
      return;
    }
    _upsertLibrary(createdLibrary);
    unawaited(_syncLibrariesInBackground());
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
    unawaited(_syncLibrariesInBackground());
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
      case MobileMediaLibraryAction.delete:
        await _handleDeleteLibrary(library);
    }
  }

  Future<void> _handleDeleteLibrary(MediaLibraryDto library) async {
    final deletedLibraryId = await showMobileDeleteMediaLibraryDrawer(
      context,
      library: library,
    );
    if (!mounted || deletedLibraryId == null) {
      return;
    }
    setState(() {
      _libraries = _libraries
          .where((item) => item.id != deletedLibraryId)
          .toList(growable: false);
      _errorMessage = null;
    });
    unawaited(_syncLibrariesInBackground());
  }

  Future<void> _syncLibrariesInBackground() async {
    try {
      final libraries = await context.read<MediaLibrariesApi>().getLibraries();
      if (!mounted) {
        return;
      }
      setState(() {
        _libraries = libraries;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '媒体库加载失败，请稍后重试。'));
    }
  }

  void _upsertLibrary(MediaLibraryDto library) {
    final nextLibraries = List<MediaLibraryDto>.of(_libraries);
    final index = nextLibraries.indexWhere((item) => item.id == library.id);
    if (index >= 0) {
      nextLibraries[index] = library;
    } else {
      nextLibraries.add(library);
    }
    setState(() {
      _libraries = nextLibraries;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return ColoredBox(
      key: const Key('mobile-settings-media-libraries'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppPullToRefresh(
              onRefresh: _refreshLibraries,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  spacing.md,
                  spacing.md,
                  spacing.md,
                  spacing.lg,
                ),
                children: [
                  const _MobileMediaLibrariesNoticeCard(),
                  SizedBox(height: spacing.md),
                  _buildContentSection(context),
                ],
              ),
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

  Widget _buildContentSection(BuildContext context) {
    if (_isLoading) {
      return const _MobileMediaLibraryLoadingSection();
    }
    if (_errorMessage != null) {
      return _MobileMediaLibraryErrorSection(
        message: _errorMessage!,
        onRetry: _loadLibraries,
      );
    }
    if (_libraries.isEmpty) {
      return const _MobileMediaLibraryEmptySection();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _libraries
          .expand(
            (library) => <Widget>[
              _MobileMediaLibraryCard(
                library: library,
                onTap: () => _handleEditLibrary(library),
                onMoreTap: () => _handleLibraryActions(library),
              ),
              if (library != _libraries.last)
                SizedBox(height: context.appSpacing.sm),
            ],
          )
          .toList(growable: false),
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
    maxHeightFactor: 0.34,
    builder:
        (drawerContext) => _MobileMediaLibraryActionsDrawer(library: library),
  );
}

Future<int?> showMobileDeleteMediaLibraryDrawer(
  BuildContext context, {
  required MediaLibraryDto library,
}) {
  return showAppBottomDrawer<int>(
    context: context,
    drawerKey: const Key('mobile-media-library-delete-drawer'),
    maxHeightFactor: 0.42,
    builder:
        (drawerContext) => _MobileDeleteMediaLibraryDrawer(library: library),
  );
}

enum MobileMediaLibraryAction { edit, delete }

class _MobileMediaLibrariesNoticeCard extends StatelessWidget {
  const _MobileMediaLibrariesNoticeCard();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      key: const Key('mobile-media-libraries-notice-card'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.noticeSurface,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: context.appComponentTokens.iconSizeMd,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '媒体库存储路径',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  '媒体库用于维护本地媒体存储根路径，下载器等模块会依赖这里的路径配置。',
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
    );
  }
}

class _MobileMediaLibraryCard extends StatelessWidget {
  const _MobileMediaLibraryCard({
    required this.library,
    required this.onTap,
    required this.onMoreTap,
  });

  final MediaLibraryDto library;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      key: Key('mobile-media-library-card-${library.id}'),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('mobile-media-library-card-body-${library.id}'),
                borderRadius: context.appRadius.lgBorder,
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width:
                            context.appComponentTokens.iconSizeXl + spacing.md,
                        height:
                            context.appComponentTokens.iconSizeXl + spacing.md,
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: context.appRadius.mdBorder,
                        ),
                        child: Icon(
                          Icons.folder_open_outlined,
                          size: context.appComponentTokens.iconSizeMd,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              library.name,
                              style: resolveAppTextStyle(
                                context,
                                size: AppTextSize.s14,
                                weight: AppTextWeight.semibold,
                                tone: AppTextTone.primary,
                              ),
                            ),
                            SizedBox(height: spacing.xs),
                            Text(
                              library.rootPath,
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
                              '更新时间: ${_formatUpdatedAt(library.updatedAt)}',
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
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: spacing.sm, right: spacing.sm),
            child: AppIconButton(
              key: Key('mobile-media-library-more-${library.id}'),
              tooltip: '更多操作',
              backgroundColor: colors.surfaceMuted,
              borderColor: colors.borderSubtle,
              onPressed: onMoreTap,
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

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
          _SkeletonBlock(
            width: context.appComponentTokens.iconSizeXl + spacing.md,
            height: context.appComponentTokens.iconSizeXl + spacing.md,
            radius: context.appRadius.md,
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBlock(width: 136, height: 16),
                SizedBox(height: spacing.xs),
                const _SkeletonBlock(width: double.infinity, height: 14),
                SizedBox(height: spacing.sm),
                const _SkeletonBlock(width: 72, height: 12),
                SizedBox(height: spacing.xs),
                const _SkeletonBlock(width: 148, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileMediaLibraryErrorSection extends StatelessWidget {
  const _MobileMediaLibraryErrorSection({
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
      key: const Key('mobile-media-libraries-error-state'),
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppEmptyState(message: '媒体库加载失败'),
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
              key: const Key('mobile-media-libraries-retry-button'),
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

class _MobileMediaLibraryEmptySection extends StatelessWidget {
  const _MobileMediaLibraryEmptySection();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mobile-media-libraries-empty-state'),
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: const AppEmptyState(message: '还没有媒体库'),
    );
  }
}

class _MobileMediaLibraryEditorDrawer extends StatefulWidget {
  const _MobileMediaLibraryEditorDrawer({this.initialLibrary});

  final MediaLibraryDto? initialLibrary;

  @override
  State<_MobileMediaLibraryEditorDrawer> createState() =>
      _MobileMediaLibraryEditorDrawerState();
}

class _MobileMediaLibraryEditorDrawerState
    extends State<_MobileMediaLibraryEditorDrawer> {
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
                _isEditing ? '编辑媒体库' : '新增媒体库',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s16,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                '维护可供下载器等模块使用的本地媒体根路径。',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: spacing.lg),
              MediaLibraryFormFields(
                nameController: _nameController,
                rootPathController: _rootPathController,
                nameFocusNode: _nameFocusNode,
                rootPathFocusNode: _rootPathFocusNode,
                enabled: !_isSubmitting,
                autovalidateMode: _autovalidateMode,
                onRootPathSubmitted: (_) => _submit(),
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
                      key: const Key('mobile-media-library-submit-button'),
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

    final value = MediaLibraryFormValue.fromControllers(
      nameController: _nameController,
      rootPathController: _rootPathController,
    );

    try {
      final api = context.read<MediaLibrariesApi>();
      final library =
          _isEditing
              ? await api.updateLibrary(
                libraryId: widget.initialLibrary!.id,
                payload: value.toUpdatePayload(),
              )
              : await api.createLibrary(value.toCreatePayload());
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
          library.rootPath,
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

class _MobileDeleteMediaLibraryDrawer extends StatefulWidget {
  const _MobileDeleteMediaLibraryDrawer({required this.library});

  final MediaLibraryDto library;

  @override
  State<_MobileDeleteMediaLibraryDrawer> createState() =>
      _MobileDeleteMediaLibraryDrawerState();
}

class _MobileDeleteMediaLibraryDrawerState
    extends State<_MobileDeleteMediaLibraryDrawer> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '删除媒体库',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          '确认删除媒体库“${widget.library.name}”？删除后下载器等依赖该路径的配置可能失效，该操作不可恢复。',
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
                key: const Key('mobile-media-library-delete-confirm-button'),
                label: '删除',
                variant: AppButtonVariant.danger,
                isLoading: _isSubmitting,
                onPressed: _deleteLibrary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _deleteLibrary() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<MediaLibrariesApi>().deleteLibrary(widget.library.id);
      if (!mounted) {
        return;
      }
      showToast('媒体库已删除');
      Navigator.of(context).pop(widget.library.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '删除媒体库失败'));
      setState(() {
        _isSubmitting = false;
      });
    }
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

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

String _formatUpdatedAt(DateTime? value) {
  if (value == null) {
    return '未知';
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
}
