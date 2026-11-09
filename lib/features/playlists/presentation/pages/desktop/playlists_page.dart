import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_scope.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_state.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/create_playlist_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_section_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/domain/playlists/playlist_banner_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

class DesktopPlaylistsPage extends ConsumerStatefulWidget {
  const DesktopPlaylistsPage({super.key});

  @override
  ConsumerState<DesktopPlaylistsPage> createState() =>
      _DesktopPlaylistsPageState();
}

class _DesktopPlaylistsPageState extends ConsumerState<DesktopPlaylistsPage> {
  int? _hoveredPlaylistId;
  late final PlaylistsOverviewScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = PlaylistsOverviewScope(
      orderScopeKey: ref.read(sessionStoreProvider).baseUrl,
      // 桌面 playlists 独立页展示全部（含系统列表）。
    );
  }

  void _setHoveredPlaylistId(int? playlistId) {
    if (_hoveredPlaylistId == playlistId) {
      return;
    }
    setState(() => _hoveredPlaylistId = playlistId);
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(
      playlistsOverviewProvider(_scope).select(selectPlaylistsOverview),
    );
    final notifier = ref.read(playlistsOverviewProvider(_scope).notifier);

    return AppPageRefreshScope(
      onRefresh: notifier.refresh,
      child: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          if (overview.isLoading) {
            return const _DesktopPlaylistsLoadingState();
          }
          if (overview.error case final error?) {
            return AppErrorState(
              title: l10n.playlistLoadFailed,
              message: apiErrorMessage(
                error,
                fallback: l10n.playlistLoadFailed,
                l10n: l10n,
              ),
              retryKey: const Key('playlists-error-retry'),
              onRetry: notifier.refresh,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppGlassListHeader(
                leading: AppGlassHeaderText(
                  label: l10n.playlistCountBadge(overview.playlists.length),
                ),
                trailing: AppGlassHeaderGroup(
                  children: [
                    AppGlassHeaderButton(
                      key: const Key('playlists-create-button'),
                      icon: Icons.add_rounded,
                      label: l10n.playlistCreateTooltip,
                      onTap: _openCreateDialog,
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.appSpacing.sm),
              Expanded(
                child: _buildPlaylistsList(
                  context,
                  overview.playlists,
                  notifier,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsList(
    BuildContext context,
    List<PlaylistDto> playlists,
    PlaylistsOverview notifier,
  ) {
    final l10n = AppLocalizations.of(context);
    if (playlists.isEmpty) {
      return AppEmptyState(message: l10n.playlistEmpty);
    }
    final systemPlaylists = playlists
        .where((playlist) => playlist.isSystem)
        .toList(growable: false);
    final customPlaylists = playlists
        .where((playlist) => !playlist.isSystem)
        .toList(growable: false);
    final spacing = context.appSpacing;

    return CustomScrollView(
      key: const Key('desktop-playlists-scroll'),
      slivers: [
        if (systemPlaylists.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: AppSectionHeader(
              title: l10n.playlistSectionSystem,
              trailingText: l10n.playlistCountBadge(systemPlaylists.length),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: spacing.sm)),
          SliverList.builder(
            itemCount: systemPlaylists.length,
            itemBuilder: (context, index) {
              final playlist = systemPlaylists[index];
              return Padding(
                key: ValueKey<int>(playlist.id),
                padding: EdgeInsets.only(bottom: spacing.sm),
                child: _buildBanner(context, playlist),
              );
            },
          ),
        ],
        if (systemPlaylists.isNotEmpty && customPlaylists.isNotEmpty)
          SliverToBoxAdapter(child: SizedBox(height: spacing.xl)),
        if (customPlaylists.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: AppSectionHeader(
              title: l10n.playlistSectionMine,
              trailingText: l10n.playlistCountBadge(customPlaylists.length),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: spacing.sm)),
          SliverReorderableList(
            key: const Key('desktop-playlists-reorderable-list'),
            itemCount: customPlaylists.length,
            onReorderItem: notifier.reorderCustomPlaylists,
            itemBuilder: (context, index) =>
                _buildCustomItem(context, customPlaylists, index),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: spacing.lg)),
      ],
    );
  }

  Widget _buildBanner(BuildContext context, PlaylistDto playlist) {
    return Consumer(
      builder: (context, ref, _) {
        final coverImageUrl = ref.watch(
          playlistsOverviewProvider(
            _scope,
          ).select((async) => async.value?.coverUrlFor(playlist.id)),
        );
        return PlaylistBannerCard(
          key: Key('playlist-banner-card-${playlist.id}'),
          title: playlist.name,
          coverImageUrl: coverImageUrl,
          onTap: () => DesktopRoutes.playlistDetail(
            playlistId: playlist.id,
            fallbackPath: desktopPlaylistsPath,
          ).push(context),
        );
      },
    );
  }

  Widget _buildCustomItem(
    BuildContext context,
    List<PlaylistDto> customPlaylists,
    int index,
  ) {
    final playlist = customPlaylists[index];
    final isHovered = _hoveredPlaylistId == playlist.id;
    return Padding(
      key: ValueKey<int>(playlist.id),
      padding: EdgeInsets.only(bottom: context.appSpacing.sm),
      child: MouseRegion(
        onEnter: (_) => _setHoveredPlaylistId(playlist.id),
        onExit: (_) {
          if (_hoveredPlaylistId == playlist.id) {
            _setHoveredPlaylistId(null);
          }
        },
        child: Stack(
          children: [
            _buildBanner(context, playlist),
            if (customPlaylists.length > 1)
              Positioned(
                right: context.appSpacing.sm,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IgnorePointer(
                    ignoring: !isHovered,
                    child: Visibility(
                      visible: isHovered,
                      child: ReorderableDragStartListener(
                        index: index,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: context.appColors.surfaceCard.withValues(
                                alpha: 0.92,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.appColors.borderSubtle,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(context.appSpacing.xs),
                              child: Icon(
                                Icons.unfold_more_rounded,
                                key: Key(
                                  'playlist-reorder-handle-${playlist.id}',
                                ),
                                size: context.appComponentTokens.iconSizeMd,
                                color: context.appTextPalette.primary,
                              ),
                            ),
                          ),
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

  Future<void> _openCreateDialog() async {
    final playlist = await showCreatePlaylistDialog(context);
    if (!mounted || playlist == null) {
      return;
    }
    ref
        .read(playlistsOverviewProvider(_scope).notifier)
        .insertPlaylist(playlist);
    if (!mounted) {
      return;
    }
    showToast(
      AppLocalizations.of(context).playlistCreatedToast,
      tone: AppToastTone.success,
    );
  }
}

class _DesktopPlaylistsLoadingState extends StatelessWidget {
  const _DesktopPlaylistsLoadingState();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    // loading 用占位播放列表渲染真实横幅，由 [AppSkeletonizer] 灰化。
    return AppSkeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: AppSkeletonBlock(
              width: appCompactIconButtonSize,
              height: appCompactIconButtonSize,
              radius: context.appRadius.smBorder,
            ),
          ),
          SizedBox(height: spacing.sm),
          Expanded(
            child: ListView.separated(
              key: const Key('playlists-page-loading'),
              itemCount: 6,
              separatorBuilder: (_, _) => SizedBox(height: spacing.sm),
              itemBuilder: (_, _) => PlaylistBannerCard(
                title: BoneMock.words(2),
                coverImageUrl: null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
