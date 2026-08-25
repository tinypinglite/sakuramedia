import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/media_library_form.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_entity_list_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';

class MobileMediaLibrariesPage extends ConsumerStatefulWidget {
  const MobileMediaLibrariesPage({super.key});

  @override
  ConsumerState<MobileMediaLibrariesPage> createState() =>
      _MobileMediaLibrariesPageState();
}

class _MobileMediaLibrariesPageState
    extends ConsumerState<MobileMediaLibrariesPage> {
  Future<List<MediaProviderDto>?> _loadCatalog() async {
    try {
      return await ref.read(mediaProviderCatalogProvider.future);
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: 'Provider 目录加载失败，请稍后重试。'));
      }
      return null;
    }
  }

  Future<void> _refreshLibraries() async {
    final message = await ref.read(mediaLibrariesProvider.notifier).refresh();
    if (mounted && message != null) showToast(message);
  }

  Future<void> _handleCreateLibrary() async {
    final providers = await _loadCatalog();
    if (!mounted || providers == null) return;
    if (providers.isEmpty) {
      showToast('暂无可用 Provider，请先在“插件”设置中安装并启用媒体 Provider。');
      return;
    }
    await showMobileMediaLibraryEditorDrawer(context, providers: providers);
  }

  Future<void> _handleEditLibrary(MediaLibraryDto library) async {
    final providers = await _loadCatalog() ?? const <MediaProviderDto>[];
    if (!mounted) return;
    await showMobileMediaLibraryEditorDrawer(
      context,
      providers: providers,
      initialLibrary: library,
    );
  }

  Future<void> _handleLibraryActions(MediaLibraryDto library) async {
    final action = await showMobileMediaLibraryActionsDrawer(
      context,
      library: library,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case MobileMediaLibraryAction.edit:
        await _handleEditLibrary(library);
      case MobileMediaLibraryAction.delete:
        await _handleDeleteLibrary(library);
    }
  }

  Future<void> _handleDeleteLibrary(MediaLibraryDto library) async {
    await showAppConfigDeleteConfirm(
      context: context,
      title: '删除媒体库',
      message: '确认删除媒体库“${library.name}”？该操作不可恢复。',
      dialogKey: const Key('mobile-media-library-delete-drawer'),
      confirmKey: const Key('mobile-media-library-delete-confirm-button'),
      onDelete: () =>
          ref.read(mediaLibrariesProvider.notifier).delete(library.id),
      successToast: '媒体库已删除',
      failureFallback: '删除媒体库失败',
    );
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
                          description: '媒体库通过已安装的 Provider 连接存储；配置字段由插件目录动态提供。',
                        ),
                        SizedBox(height: spacing.md),
                        _buildCatalogNotice(context),
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
            padding: EdgeInsets.all(spacing.md),
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

  Widget _buildCatalogNotice(BuildContext context) {
    final catalog = ref.watch(mediaProviderCatalogProvider);
    if (catalog.hasError) {
      return Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.md),
        child: const AppNoticeCard(
          leadingIcon: Icons.warning_amber_rounded,
          description: 'Provider 目录暂不可用，已存在的媒体库仍可管理；新增或编辑配置前请重试。',
        ),
      );
    }
    if (catalog.hasValue && catalog.value!.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.md),
        child: const AppNoticeCard(
          leadingIcon: Icons.extension_off_outlined,
          description: '暂无可用 Provider，请先在“插件”设置中安装并启用媒体 Provider。',
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildContentSection(
    BuildContext context,
    AsyncValue<List<MediaLibraryDto>> async,
  ) {
    if (async.isLoading) return const _MobileMediaLibraryLoadingSection();
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
    final catalog = ref.watch(mediaProviderCatalogProvider);
    final providers = catalog.value ?? const <MediaProviderDto>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: libraries
          .expand(
            (library) => <Widget>[
              _buildLibraryCard(
                context,
                library,
                providers,
                catalogReady: catalog.hasValue,
              ),
              if (library != libraries.last)
                SizedBox(height: context.appSpacing.sm),
            ],
          )
          .toList(growable: false),
    );
  }

  Widget _buildLibraryCard(
    BuildContext context,
    MediaLibraryDto library,
    List<MediaProviderDto> providers, {
    required bool catalogReady,
  }) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final provider = _findProvider(providers, library.providerKey);
    final unavailable = catalogReady && provider == null;
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
          Icons.folder_open_outlined,
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
          provider?.displayName ??
              (catalogReady
                  ? 'Provider 不可用 · ${library.providerKey}'
                  : library.providerKey),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: unavailable ? AppTextTone.error : AppTextTone.secondary,
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

MediaProviderDto? _findProvider(
  List<MediaProviderDto> providers,
  String providerKey,
) {
  for (final provider in providers) {
    if (provider.providerKey == providerKey) return provider;
  }
  return null;
}

Future<MediaLibraryDto?> showMobileMediaLibraryEditorDrawer(
  BuildContext context, {
  required List<MediaProviderDto> providers,
  MediaLibraryDto? initialLibrary,
}) {
  return showAppBottomDrawer<MediaLibraryDto>(
    context: context,
    drawerKey: const Key('mobile-media-library-editor-drawer'),
    heightFactor: 0.78,
    builder: (_) => _MobileMediaLibraryEditorDrawer(
      providers: providers,
      initialLibrary: initialLibrary,
    ),
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
    builder: (_) => _MobileMediaLibraryActionsDrawer(library: library),
  );
}

enum MobileMediaLibraryAction { edit, delete }

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
  const _MobileMediaLibraryEditorDrawer({
    required this.providers,
    this.initialLibrary,
  });

  final List<MediaProviderDto> providers;
  final MediaLibraryDto? initialLibrary;

  @override
  ConsumerState<_MobileMediaLibraryEditorDrawer> createState() =>
      _MobileMediaLibraryEditorDrawerState();
}

class _MobileMediaLibraryEditorDrawerState
    extends ConsumerState<_MobileMediaLibraryEditorDrawer> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  late String? _selectedProviderKey;
  late ProviderConfigFormController _providerConfigController;
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialLibrary != null;
  MediaProviderDto? get _selectedProvider =>
      _findProvider(widget.providers, _selectedProviderKey ?? '');
  AutovalidateMode get _autovalidateMode => _hasAttemptedSubmit
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialLibrary?.name ?? '',
    );
    _nameFocusNode = FocusNode();
    _selectedProviderKey =
        widget.initialLibrary?.providerKey ??
        (widget.providers.isEmpty ? null : widget.providers.first.providerKey);
    _providerConfigController = ProviderConfigFormController(
      fields:
          _selectedProvider?.libraryConfigFields ??
          const <ProviderConfigFieldDto>[],
      initialConfig:
          widget.initialLibrary?.providerConfig ?? const <String, dynamic>{},
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _providerConfigController.dispose();
    super.dispose();
  }

  void _selectProvider(String? providerKey) {
    if (providerKey == null ||
        providerKey == _selectedProviderKey ||
        _isEditing) {
      return;
    }
    _providerConfigController.dispose();
    final provider = _findProvider(widget.providers, providerKey);
    setState(() {
      _selectedProviderKey = providerKey;
      _providerConfigController = ProviderConfigFormController(
        fields:
            provider?.libraryConfigFields ?? const <ProviderConfigFieldDto>[],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = _selectedProvider;
    final unavailable = _isEditing && provider == null;
    return AppBottomFormSheet(
      formKey: _formKey,
      title: _isEditing ? '编辑媒体库' : '新增媒体库',
      subtitle: unavailable
          ? '当前 Provider 不可用，仅可修改媒体库名称。'
          : '选择 Provider 后填写其存储配置。',
      submitKey: const Key('mobile-media-library-submit-button'),
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MediaLibraryFormFields(
            nameController: _nameController,
            nameFocusNode: _nameFocusNode,
            enabled: !_isSubmitting,
            autovalidateMode: _autovalidateMode,
            onNameSubmitted: (_) => _submit(),
          ),
          SizedBox(height: context.appSpacing.lg),
          if (unavailable)
            MediaLibraryProviderUnavailableNotice(
              providerKey: widget.initialLibrary!.providerKey,
            )
          else
            MediaLibraryProviderSelectField(
              providers: widget.providers,
              value: _selectedProviderKey,
              enabled: !_isEditing && !_isSubmitting,
              onChanged: _selectProvider,
            ),
          if (provider != null && provider.libraryConfigFields.isNotEmpty) ...[
            SizedBox(height: context.appSpacing.lg),
            ProviderConfigFormFields(
              controller: _providerConfigController,
              enabled: !_isSubmitting,
              isEditing: _isEditing,
              autovalidateMode: _autovalidateMode,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!_hasAttemptedSubmit) {
      setState(() => _hasAttemptedSubmit = true);
    }
    if (!(_formKey.currentState?.validate() ?? false) ||
        _selectedProviderKey == null) {
      return;
    }
    setState(() => _isSubmitting = true);
    final value = MediaLibraryFormValue.fromControllers(
      nameController: _nameController,
      providerKey: _selectedProviderKey!,
      providerConfigController: _providerConfigController,
      isEditing: _isEditing,
    );
    try {
      final library = _isEditing
          ? await ref
                .read(mediaLibrariesProvider.notifier)
                .updateLibrary(
                  libraryId: widget.initialLibrary!.id,
                  payload: _selectedProvider == null
                      ? UpdateMediaLibraryPayload(name: value.name)
                      : value.toUpdatePayload(),
                )
          : await ref
                .read(mediaLibrariesProvider.notifier)
                .create(value.toCreatePayload());
      if (!mounted) return;
      showToast(_isEditing ? '媒体库已更新' : '媒体库已创建');
      Navigator.of(context).pop(library);
    } catch (error) {
      if (!mounted) return;
      showToast(
        apiErrorMessage(error, fallback: _isEditing ? '更新媒体库失败' : '创建媒体库失败'),
      );
      setState(() => _isSubmitting = false);
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
          library.providerKey,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
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
          onTap: () =>
              Navigator.of(context).pop(MobileMediaLibraryAction.delete),
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
