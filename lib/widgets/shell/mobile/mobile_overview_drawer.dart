import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/activity/presentation/providers/notification_center_provider.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/shell/app_sidebar_account_card.dart';

/// 概览分支的侧滑抽屉：菜单分组 + 未读消息徽标 + 桌面同款账户卡。
///
/// 只负责展示与收起；菜单数据由路由层注入，点选后把条目交给 [onSelected]，
/// 避免壳层反向依赖具体路由。
class MobileOverviewDrawer extends ConsumerWidget {
  const MobileOverviewDrawer({
    super.key,
    required this.hostContext,
    required this.sections,
    required this.onSelected,
    required this.onLogout,
    required this.onOpenPluginUpdates,
  });

  /// 壳的宿主 context：抽屉关闭动画先于路由跳转，postFrame 里的跳转、
  /// 主题读取都以它为准。
  final BuildContext hostContext;
  final List<AppDrawerSection> sections;
  final void Function(AppDrawerEntry entry) onSelected;
  final VoidCallback onLogout;
  final VoidCallback onOpenPluginUpdates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(
      notificationCenterProvider.select((value) => value.unreadCount),
    );
    return _buildDrawer(context, unreadCount: unreadCount);
  }

  Widget _buildDrawer(BuildContext context, {required int unreadCount}) {
    final spacing = hostContext.appSpacing;
    final sectionWidgets = <Widget>[];
    for (var index = 0; index < sections.length; index += 1) {
      final section = sections[index];
      final entries = section.entries
          .where((entry) => entry.visible?.call() ?? true)
          .toList(growable: false);
      if (entries.isEmpty) {
        continue;
      }
      if (sectionWidgets.isNotEmpty) {
        sectionWidgets.add(SizedBox(height: spacing.md));
      }
      sectionWidgets.add(
        _MobileOverviewDrawerSection(
          key: Key('mobile-overview-drawer-${section.id}-section'),
          header: section.header,
          items: entries
              .map(
                (entry) => _buildMenuEntry(
                  context: context,
                  entry: entry,
                  unreadCount: unreadCount,
                ),
              )
              .toList(growable: false),
        ),
      );
    }

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
                    children: sectionWidgets,
                  ),
                ),
              ),
              SizedBox(height: spacing.md),
              AppSidebarAccountCard(
                key: const Key('mobile-overview-drawer-account-card'),
                logoutKey: const Key('mobile-overview-drawer-logout'),
                onLogout: () => _selectAction(context, onLogout),
                onOpenPluginUpdates: () =>
                    _selectAction(context, onOpenPluginUpdates),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuEntry({
    required BuildContext context,
    required AppDrawerEntry entry,
    required int unreadCount,
  }) {
    final showBadge =
        entry.badge == AppDrawerBadge.notifications && unreadCount > 0;
    return _MobileOverviewDrawerItem(
      key: Key('mobile-overview-drawer-${entry.key}'),
      icon: entry.icon,
      label: entry.label,
      trailing: showBadge
          ? AppBadge(
              key: const Key('mobile-overview-drawer-notifications-badge'),
              label: unreadCount > 99 ? '99+' : '$unreadCount',
              tone: AppBadgeTone.error,
              size: AppBadgeSize.compact,
            )
          : null,
      onTap: () => _selectEntry(context, entry),
    );
  }

  /// 先收起抽屉，下一帧再交给宿主跳转（宿主 context 仍在时）。
  void _selectEntry(BuildContext context, AppDrawerEntry entry) {
    _closeThen(context, () => onSelected(entry));
  }

  void _selectAction(BuildContext context, VoidCallback action) {
    _closeThen(context, action);
  }

  void _closeThen(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hostContext.mounted) {
        return;
      }
      action();
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
