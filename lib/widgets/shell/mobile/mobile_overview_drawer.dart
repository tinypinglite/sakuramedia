import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/activity/presentation/providers/notification_center_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/shell/app_version_info_card.dart';

/// 概览分支的侧滑抽屉：菜单分组 + 未读消息徽标 + 版本卡片。
///
/// 只负责展示与收起；点选后把菜单 key 交给 [onMenuSelected]（路由映射由
/// `lib/routes/mobile_routes.dart` 注入），避免壳层反向依赖具体路由。
class MobileOverviewDrawer extends ConsumerWidget {
  const MobileOverviewDrawer({
    super.key,
    required this.hostContext,
    required this.onMenuSelected,
  });

  /// 壳的宿主 context：抽屉关闭动画先于路由跳转，postFrame 里的跳转、
  /// 主题读取都以它为准。
  final BuildContext hostContext;
  final void Function(String key) onMenuSelected;

  static _MobileOverviewDrawerMenuItem _overviewItem(AppLocalizations l10n) =>
      _MobileOverviewDrawerMenuItem(
        key: 'overview',
        icon: Icons.space_dashboard_outlined,
        label: l10n.shellNavOverview,
      );

  static _MobileOverviewDrawerMenuItem _favoritesItem(AppLocalizations l10n) =>
      _MobileOverviewDrawerMenuItem(
        key: 'favorites',
        icon: Icons.favorite_border_rounded,
        label: l10n.shellNavFavorites,
      );

  static _MobileOverviewDrawerMenuItem _recentlyPlayedItem(
    AppLocalizations l10n,
  ) => _MobileOverviewDrawerMenuItem(
    key: 'recently-played',
    icon: Icons.play_circle_outline_rounded,
    label: l10n.shellNavRecentlyPlayed,
  );

  static _MobileOverviewDrawerMenuItem _recentViewsItem(
    AppLocalizations l10n,
  ) => _MobileOverviewDrawerMenuItem(
    key: 'recent-views',
    icon: Icons.visibility_outlined,
    label: l10n.shellNavRecentViews,
  );

  static _MobileOverviewDrawerMenuItem _ratingsItem(AppLocalizations l10n) =>
      _MobileOverviewDrawerMenuItem(
        key: 'ratings',
        icon: Icons.star_outline_rounded,
        label: l10n.shellNavMyRatings,
      );

  static _MobileOverviewDrawerMenuItem _tagsItem(AppLocalizations l10n) =>
      _MobileOverviewDrawerMenuItem(
        key: 'tags',
        icon: Icons.sell_outlined,
        label: l10n.shellNavTags,
      );

  static List<_MobileOverviewDrawerMenuItem> _contentItems(
    AppLocalizations l10n,
  ) => <_MobileOverviewDrawerMenuItem>[
    _favoritesItem(l10n),
    _recentlyPlayedItem(l10n),
    _recentViewsItem(l10n),
    _ratingsItem(l10n),
    _tagsItem(l10n),
  ];

  static List<_MobileOverviewDrawerMenuItem> _downloadTaskItems(
    AppLocalizations l10n,
  ) => <_MobileOverviewDrawerMenuItem>[
    _MobileOverviewDrawerMenuItem(
      key: 'download-tasks',
      icon: Icons.download_for_offline_outlined,
      label: l10n.shellNavDownloadTasks,
    ),
    _MobileOverviewDrawerMenuItem(
      key: 'activity',
      icon: Icons.bolt_outlined,
      label: l10n.shellNavTaskCenter,
    ),
    _MobileOverviewDrawerMenuItem(
      key: 'movie-subscriptions',
      icon: Icons.bookmark_added_outlined,
      label: l10n.shellNavSubscriptions,
    ),
  ];

  static List<_MobileOverviewDrawerMenuItem> _mediaConnectionItems(
    AppLocalizations l10n,
  ) => <_MobileOverviewDrawerMenuItem>[
    _MobileOverviewDrawerMenuItem(
      key: 'media-management',
      icon: Icons.video_settings_outlined,
      label: l10n.shellNavMediaManagement,
    ),
    _MobileOverviewDrawerMenuItem(
      key: 'media-import',
      icon: Icons.drive_folder_upload_outlined,
      label: l10n.shellNavMediaImport,
    ),
    _MobileOverviewDrawerMenuItem(
      key: 'media-libraries',
      icon: Icons.video_library_outlined,
      label: l10n.shellNavMediaLibraries,
    ),
    _MobileOverviewDrawerMenuItem(
      key: 'media-tags',
      icon: Icons.sell_outlined,
      label: l10n.shellNavMediaTags,
    ),
    _MobileOverviewDrawerMenuItem(
      key: 'downloaders',
      icon: Icons.download_outlined,
      label: l10n.shellNavDownloaders,
    ),
    _MobileOverviewDrawerMenuItem(
      key: 'indexers',
      icon: Icons.travel_explore_outlined,
      label: l10n.shellNavIndexers,
    ),
    _MobileOverviewDrawerMenuItem(
      key: 'download-selection',
      icon: Icons.filter_alt_outlined,
      label: l10n.configTabDownloadSelection,
    ),
  ];

  static List<_MobileOverviewDrawerMenuItem> _systemAccountItems(
    AppLocalizations l10n,
  ) => <_MobileOverviewDrawerMenuItem>[
    _MobileOverviewDrawerMenuItem(
      key: 'plugins',
      icon: Icons.extension_outlined,
      label: l10n.shellNavPlugins,
    ),
    _MobileOverviewDrawerMenuItem(
      key: 'system-maintenance',
      icon: Icons.build_outlined,
      label: l10n.shellNavSystemMaintenance,
    ),
    if (_supportsExternalPlayer)
      _MobileOverviewDrawerMenuItem(
        key: 'external-player',
        icon: Icons.open_in_new_rounded,
        label: l10n.shellNavExternalPlayer,
      ),
    _MobileOverviewDrawerMenuItem(
      key: 'appearance',
      icon: Icons.palette_outlined,
      label: l10n.shellNavAppearance,
    ),
    _MobileOverviewDrawerMenuItem(
      key: 'account-security',
      icon: Icons.security_rounded,
      label: l10n.shellNavAccountSecurity,
    ),
  ];

  static bool get _supportsExternalPlayer =>
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(
      notificationCenterProvider.select((value) => value.unreadCount),
    );
    return _buildDrawer(context, unreadCount: unreadCount);
  }

  Widget _buildDrawer(BuildContext context, {required int unreadCount}) {
    final l10n = appL10n(context);
    final spacing = hostContext.appSpacing;

    return Drawer(
      key: const Key('mobile-overview-drawer'),
      backgroundColor: hostContext.appColors.surfacePage,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.lg,
            spacing.lg,
            spacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MobileOverviewDrawerSection(
                        key: const Key('mobile-overview-drawer-home-section'),
                        header: l10n.shellDrawerGroupHome,
                        items: <Widget>[
                          _buildMenuEntry(
                            context: context,
                            item: _overviewItem(l10n),
                          ),
                          _MobileOverviewDrawerItem(
                            key: const Key(
                              'mobile-overview-drawer-notifications',
                            ),
                            icon: Icons.notifications_none_rounded,
                            label: l10n.shellNavNotifications,
                            trailing: unreadCount > 0
                                ? AppBadge(
                                    key: const Key(
                                      'mobile-overview-drawer-notifications-badge',
                                    ),
                                    label: unreadCount > 99
                                        ? '99+'
                                        : '$unreadCount',
                                    tone: AppBadgeTone.error,
                                    size: AppBadgeSize.compact,
                                  )
                                : null,
                            onTap: () => _selectMenu(context, 'notifications'),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing.md),
                      _MobileOverviewDrawerSection(
                        key: const Key(
                          'mobile-overview-drawer-content-section',
                        ),
                        header: l10n.shellDrawerGroupMyContent,
                        items: _buildMenuEntries(context, _contentItems(l10n)),
                      ),
                      SizedBox(height: spacing.md),
                      _MobileOverviewDrawerSection(
                        key: const Key(
                          'mobile-overview-drawer-downloads-tasks-section',
                        ),
                        header: l10n.shellDrawerGroupDownloadsTasks,
                        items: _buildMenuEntries(
                          context,
                          _downloadTaskItems(l10n),
                        ),
                      ),
                      SizedBox(height: spacing.md),
                      _MobileOverviewDrawerSection(
                        key: const Key(
                          'mobile-overview-drawer-media-connections-section',
                        ),
                        header: l10n.shellDrawerGroupMediaConnections,
                        items: _buildMenuEntries(
                          context,
                          _mediaConnectionItems(l10n),
                        ),
                      ),
                      SizedBox(height: spacing.md),
                      _MobileOverviewDrawerSection(
                        key: const Key(
                          'mobile-overview-drawer-system-account-section',
                        ),
                        header: l10n.shellDrawerGroupSystemAccount,
                        items: _buildMenuEntries(
                          context,
                          _systemAccountItems(l10n),
                        ),
                      ),
                      SizedBox(height: spacing.md),
                      const AppVersionInfoCard(
                        cardKey: Key('mobile-overview-drawer-version-card'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.md),
              _MobileOverviewDrawerSection(
                key: const Key('mobile-overview-drawer-bottom-actions'),
                items: <Widget>[
                  _MobileOverviewDrawerItem(
                    key: const Key('mobile-overview-drawer-logout'),
                    icon: Icons.logout_rounded,
                    label: l10n.shellLogout,
                    onTap: () => _selectMenu(context, 'logout'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuEntries(
    BuildContext context,
    List<_MobileOverviewDrawerMenuItem> items,
  ) {
    return items
        .map((item) => _buildMenuEntry(context: context, item: item))
        .toList(growable: false);
  }

  Widget _buildMenuEntry({
    required BuildContext context,
    required _MobileOverviewDrawerMenuItem item,
  }) {
    return _MobileOverviewDrawerItem(
      key: Key('mobile-overview-drawer-${item.key}'),
      icon: item.icon,
      label: item.label,
      onTap: () => _selectMenu(context, item.key),
    );
  }

  /// 先收起抽屉，下一帧再交给宿主跳转（宿主 context 仍在时）。
  void _selectMenu(BuildContext context, String key) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hostContext.mounted) {
        return;
      }
      onMenuSelected(key);
    });
  }
}

class _MobileOverviewDrawerSection extends StatelessWidget {
  const _MobileOverviewDrawerSection({
    super.key,
    required this.items,
    this.header,
  });

  final List<Widget> items;
  final String? header;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[
          Padding(
            padding: EdgeInsets.only(left: spacing.xs, bottom: spacing.sm),
            child: Text(
              header!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.muted,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: context.appRadius.lgBorder,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.xs),
            child: Column(
              children: items
                  .expand((item) {
                    final itemIndex = items.indexOf(item);
                    return <Widget>[
                      item,
                      if (itemIndex < items.length - 1)
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start:
                                spacing.md +
                                componentTokens.iconSizeXl +
                                spacing.sm +
                                spacing.md,
                            end: spacing.md,
                          ),
                          child: Divider(
                            height: spacing.xs,
                            thickness: 1,
                            color: colors.borderSubtle.fadedBy(0.56),
                          ),
                        ),
                    ];
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileOverviewDrawerMenuItem {
  const _MobileOverviewDrawerMenuItem({
    required this.key,
    required this.icon,
    required this.label,
  });

  final String key;
  final IconData icon;
  final String label;
}

class _MobileOverviewDrawerItem extends StatelessWidget {
  const _MobileOverviewDrawerItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        borderRadius: context.appRadius.lgBorder,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: componentTokens.iconSizeXl + spacing.sm,
                height: componentTokens.iconSizeXl + spacing.sm,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: context.appRadius.smBorder,
                ),
                child: Icon(
                  icon,
                  size: componentTokens.iconSizeMd,
                  color: context.appTextPalette.primary,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Text(
                  label,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              if (trailing != null) ...[SizedBox(width: spacing.sm), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
