import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/configuration_placeholders.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_entity_list_card.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/media_library_editor.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

/// 媒体库设置页：桌面分类页与移动子页共用同一份数据、动作和编辑器。
class MediaLibrariesPage extends ConsumerStatefulWidget {
  const MediaLibrariesPage({
    super.key,
    required this.mobile,
    this.active = true,
  });

  final bool mobile;
  final bool active;

  @override
  ConsumerState<MediaLibrariesPage> createState() => _MediaLibrariesPageState();
}

class _MediaLibrariesPageState extends ConsumerState<MediaLibrariesPage> {
  @override
  void didUpdateWidget(covariant MediaLibrariesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) {
          unawaited(ref.read(mediaProviderCatalogProvider.notifier).reload());
        }
      });
    }
  }

  Future<List<MediaProviderDto>?> _loadCatalog({bool showError = true}) async {
    try {
      return await ref.read(mediaProviderCatalogProvider.future);
    } catch (error) {
      if (showError && mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.mediaLibraryProviderCatalogLoadFailed,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
      }
      return null;
    }
  }

  Future<void> _refreshDesktop() {
    return Future.wait<void>([
      ref.read(mediaLibrariesProvider.notifier).reload(),
      ref.read(mediaProviderCatalogProvider.notifier).reload(),
    ]);
  }

  Future<void> _refreshMobile() async {
    final message = await ref.read(mediaLibrariesProvider.notifier).refresh();
    if (mounted && message != null) showToast(message);
  }

  Future<void> _createLibrary() async {
    final providers = await _loadCatalog();
    if (!mounted || providers == null) return;
    if (providers.isEmpty) {
      showToast(
        AppLocalizations.of(context).mediaLibraryNoProviderInstalled,
        tone: AppToastTone.warning,
      );
      return;
    }
    await showMediaLibraryEditor(
      context,
      mobile: widget.mobile,
      providers: providers,
    );
  }

  Future<void> _editLibrary(MediaLibraryDto library) async {
    final providers =
        await _loadCatalog(showError: false) ?? const <MediaProviderDto>[];
    if (!mounted) return;
    await showMediaLibraryEditor(
      context,
      mobile: widget.mobile,
      providers: providers,
      initialLibrary: library,
    );
  }

  Future<void> _deleteLibrary(MediaLibraryDto library) async {
    final l10n = AppLocalizations.of(context);
    await showAppConfigDeleteConfirm(
      context: context,
      title: l10n.mediaLibraryDeleteTitle,
      message: l10n.mediaLibraryDeleteMessage(library.name),
      dialogKey: widget.mobile
          ? const Key('mobile-media-library-delete-drawer')
          : null,
      confirmKey: widget.mobile
          ? const Key('mobile-media-library-delete-confirm-button')
          : null,
      onDelete: () =>
          ref.read(mediaLibrariesProvider.notifier).delete(library.id),
      successToast: l10n.mediaLibraryDeleted,
      failureFallback: l10n.mediaLibraryDeleteFailed,
    );
  }

  Future<void> _handleMobileActions(MediaLibraryDto library) async {
    final l10n = AppLocalizations.of(context);
    final action = await showAppActionMenu<_MediaLibraryAction>(
      context: context,
      presentation: AppMenuPresentation.bottomDrawer,
      drawerKey: const Key('mobile-media-library-actions-drawer'),
      title: library.name,
      items: [
        AppMenuItem(
          key: const Key('mobile-media-library-action-edit'),
          value: _MediaLibraryAction.edit,
          label: l10n.mediaLibraryEditAction,
          icon: Icons.edit_outlined,
        ),
        AppMenuItem(
          key: const Key('mobile-media-library-action-delete'),
          value: _MediaLibraryAction.delete,
          label: l10n.mediaLibraryDeleteAction,
          icon: Icons.delete_outline_rounded,
          tone: AppTextTone.error,
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _MediaLibraryAction.edit:
        await _editLibrary(library);
      case _MediaLibraryAction.delete:
        await _deleteLibrary(library);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return widget.mobile ? _buildMobile(context) : _buildDesktop(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final libraries = ref.watch(mediaLibrariesProvider);
    final Widget content;
    if (libraries.hasError) {
      content = AppSectionError(
        key: const Key('media-libraries-error-state'),
        title: l10n.mediaLibraryLoadFailedTitle,
        message: apiErrorMessage(
          libraries.error!,
          fallback: l10n.mediaLibraryLoadFailedFallback,
          l10n: l10n,
        ),
        onRetry: () => ref.read(mediaLibrariesProvider.notifier).reload(),
      );
    } else {
      final catalog = ref.watch(mediaProviderCatalogProvider);
      final isLoading = libraries.value == null;
      final display = libraries.value ?? mediaLibraryPlaceholders();
      content = AppSkeletonizer(
        enabled: isLoading,
        child: _buildDesktopLoaded(context, display, catalog),
      );
    }
    return AppPageRefreshScope(onRefresh: _refreshDesktop, child: content);
  }

  Widget _buildDesktopLoaded(
    BuildContext context,
    List<MediaLibraryDto> libraries,
    AsyncValue<List<MediaProviderDto>> catalog,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final providers = catalog.value ?? const <MediaProviderDto>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppNoticeCard(
          leadingIcon: Icons.folder_open_outlined,
          title: l10n.mediaLibraryStorageTitle,
          description: l10n.mediaLibraryStorageDescriptionDesktop,
        ),
        SizedBox(height: spacing.lg),
        if (catalog.hasError)
          AppNoticeCard(
            leadingIcon: Icons.warning_amber_rounded,
            description: l10n.mediaLibraryProviderCatalogUnavailable,
          ),
        if (catalog.hasError) SizedBox(height: spacing.lg),
        if (catalog.hasValue && providers.isEmpty)
          AppNoticeCard(
            leadingIcon: Icons.extension_off_outlined,
            description: l10n.mediaLibraryNoProviderInstalled,
          ),
        if (catalog.hasValue && providers.isEmpty) SizedBox(height: spacing.lg),
        if (libraries.isEmpty)
          AppEmptyState(
            key: const Key('media-libraries-empty-state'),
            message: l10n.mediaLibraryEmpty,
          )
        else
          AppSettingsGroup(
            dividerIndent: spacing.lg + spacing.xxl + spacing.md,
            children: [
              for (final library in libraries)
                _buildDesktopLibraryCell(
                  context,
                  library,
                  providers,
                  catalogReady: catalog.hasValue,
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
              title: l10n.mediaLibraryAdd,
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

  Widget _buildDesktopLibraryCell(
    BuildContext context,
    MediaLibraryDto library,
    List<MediaProviderDto> providers, {
    required bool catalogReady,
  }) {
    final l10n = AppLocalizations.of(context);
    final provider = _findProvider(providers, library.providerKey);
    final unavailable = catalogReady && provider == null;
    return AppSettingCell(
      key: Key('media-library-card-${library.id}'),
      icon: Icons.folder_open_outlined,
      title: library.name,
      subtitle:
          provider?.displayName ??
          (catalogReady
              ? l10n.mediaLibraryProviderUnavailable(library.providerKey)
              : library.providerKey),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unavailable)
            Text(
              l10n.mediaLibraryUnavailable,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.error,
              ),
            ),
          if (unavailable) SizedBox(width: context.appSpacing.sm),
          Text(
            'ID ${library.id}',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(width: context.appSpacing.sm),
          AppIconButton(
            key: Key('media-library-edit-${library.id}'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.commonEdit,
            size: AppIconButtonSize.inline,
            iconColor: context.appTextPalette.secondary,
            onPressed: () => _editLibrary(library),
          ),
          SizedBox(width: context.appSpacing.xs),
          AppIconButton(
            key: Key('media-library-delete-${library.id}'),
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.commonDelete,
            size: AppIconButtonSize.inline,
            iconColor: context.appTextPalette.secondary,
            onPressed: () => _deleteLibrary(library),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final libraries = ref.watch(mediaLibrariesProvider);
    final catalog = ref.watch(mediaProviderCatalogProvider);
    return ColoredBox(
      key: const Key('mobile-settings-media-libraries'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: _refreshMobile,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.only(top: spacing.md, bottom: spacing.lg),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppNoticeCard(
                          key: const Key('mobile-media-libraries-notice-card'),
                          leadingIcon: Icons.folder_open_outlined,
                          title: l10n.mediaLibraryStorageTitle,
                          description:
                              l10n.mediaLibraryStorageDescriptionMobile,
                        ),
                        SizedBox(height: spacing.md),
                        _buildMobileCatalogNotice(context, catalog),
                        _buildMobileContent(context, libraries, catalog),
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
                label: l10n.mediaLibraryAdd,
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.add_rounded),
                onPressed: _createLibrary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCatalogNotice(
    BuildContext context,
    AsyncValue<List<MediaProviderDto>> catalog,
  ) {
    final l10n = AppLocalizations.of(context);
    if (catalog.hasError) {
      return Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.md),
        child: AppNoticeCard(
          leadingIcon: Icons.warning_amber_rounded,
          description: l10n.mediaLibraryProviderCatalogUnavailable,
        ),
      );
    }
    if (catalog.hasValue && catalog.value!.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.md),
        child: AppNoticeCard(
          leadingIcon: Icons.extension_off_outlined,
          description: l10n.mediaLibraryNoProviderInstalled,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMobileContent(
    BuildContext context,
    AsyncValue<List<MediaLibraryDto>> async,
    AsyncValue<List<MediaProviderDto>> catalog,
  ) {
    final l10n = AppLocalizations.of(context);
    if (async.isLoading && async.value == null) {
      return _buildMobileLoading(context);
    }
    if (async.hasError) {
      return AppMobileSectionError(
        key: const Key('mobile-media-libraries-error-state'),
        title: l10n.mediaLibraryLoadFailedTitle,
        message: apiErrorMessage(
          async.error!,
          fallback: l10n.mediaLibraryLoadFailedFallback,
          l10n: l10n,
        ),
        onRetry: () => ref.read(mediaLibrariesProvider.notifier).reload(),
        retryButtonKey: const Key('mobile-media-libraries-retry-button'),
      );
    }
    final libraries = async.value ?? const <MediaLibraryDto>[];
    if (libraries.isEmpty) {
      return MobileConfigEmptyCard(
        key: const Key('mobile-media-libraries-empty-state'),
        message: l10n.mediaLibraryEmpty,
      );
    }
    final providers = catalog.value ?? const <MediaProviderDto>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: libraries
          .expand(
            (library) => <Widget>[
              _buildMobileLibraryCard(
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

  Widget _buildMobileLoading(BuildContext context) {
    final libraries = mediaLibraryPlaceholders(count: 3);
    return AppSkeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: libraries
            .expand(
              (library) => <Widget>[
                _buildMobileLibraryCard(
                  context,
                  library,
                  const <MediaProviderDto>[],
                  catalogReady: false,
                ),
                if (library != libraries.last)
                  SizedBox(height: context.appSpacing.sm),
              ],
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildMobileLibraryCard(
    BuildContext context,
    MediaLibraryDto library,
    List<MediaProviderDto> providers, {
    required bool catalogReady,
  }) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final l10n = AppLocalizations.of(context);
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
                  ? l10n.mediaLibraryProviderUnavailable(library.providerKey)
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
          l10n.mediaLibraryUpdatedAt(
            formatUpdatedAtLabel(library.updatedAt) ?? l10n.commonUnknown,
          ),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
      ],
      onTap: () => _editLibrary(library),
      trailingAction: AppIconButton(
        key: Key('mobile-media-library-more-${library.id}'),
        tooltip: l10n.mediaLibraryMoreActions,
        backgroundColor: colors.surfaceMuted,
        borderColor: colors.borderSubtle,
        onPressed: () => _handleMobileActions(library),
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

enum _MediaLibraryAction { edit, delete }
