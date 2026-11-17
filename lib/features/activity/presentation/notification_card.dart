import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';

/// 通知列表卡片。已读为「无感」自动处理，卡片本身不区分已读/未读视觉，
/// 未读信号统一交给侧边栏角标。
class NotificationCard extends StatelessWidget {
  const NotificationCard({super.key, required this.notification});

  final ActivityNotificationDto notification;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppContentCard(
      key: Key('activity-notification-${notification.id}'),
      borderRadius: context.appRadius.mdBorder,
      borderColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                    SizedBox(height: context.appSpacing.xs),
                    Text(
                      notification.content,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.appSpacing.md),
          Wrap(
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppBadge(
                label: labelForNotificationCategory(
                  notification.category,
                  l10n,
                ),
                tone: notificationCategoryTone(notification.category),
              ),
              Text(
                formatUpdatedAtLabel(notification.createdAt) ??
                    l10n.activityTimeUnknown,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 通知分类筛选条：`AppGlassListHeader` / `AppMobileListHeader` 的薄适配器。
///
/// 分类筛选、全部已读与筛选更新反馈都留在 Header 内，页面不再外挂第二条
/// `AppFilterUpdateBar`。纯状态输入与动作回调，不持有业务控制器。
class NotificationFilterBar extends StatelessWidget {
  const NotificationFilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    this.filterUpdate = const FilterUpdateState.idle(),
    this.hasPreviousItems = true,
    this.onRetryFilter,
    this.unreadCount = 0,
    this.isMarkingAllRead = false,
    this.onMarkAllRead,
    this.mobileLeading,
    this.showCategoryFilter = true,
  });

  final ActivityNotificationFilterState filter;
  final ValueChanged<ActivityNotificationFilterState> onFilterChanged;
  final FilterUpdateState filterUpdate;
  final bool hasPreviousItems;
  final VoidCallback? onRetryFilter;
  final int unreadCount;
  final bool isMarkingAllRead;
  final VoidCallback? onMarkAllRead;

  /// 移动端 Header 左侧内容（通知页的「全部/未读」分段）。
  final Widget? mobileLeading;

  /// 移动端通知页当前只按已读状态分段，不必再放分类筛选入口。
  final bool showCategoryFilter;

  static const List<String> _categories = <String>[
    'info',
    'warning',
    'error',
    'reminder',
  ];

  @override
  Widget build(BuildContext context) {
    if (AppPlatformScope.maybeOf(context) == AppPlatform.mobile) {
      return _buildMobile(context);
    }
    return _buildDesktop(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canMarkAllRead = unreadCount > 0 && !isMarkingAllRead;
    return AppGlassListHeader(
      leading: showCategoryFilter
          ? AppGlassFilterPopover(
              panelKey: const Key('notification-category-filter-panel'),
              triggerKey: const Key('notification-category-filter'),
              label: notificationCategoryFilterSummary(filter, l10n),
              tooltip: l10n.baseFilterTooltip,
              isDefault: filter.category == null,
              resetKey: const Key('notification-category-filter-reset'),
              onReset: () => onFilterChanged(filter.copyWith(category: null)),
              panelBuilder: (context) => AppFilterChoiceSection<String?>(
                title: l10n.baseFilterTooltip,
                controlKey: const Key('notification-category-filter-options'),
                items: <AppSegmentedItem<String?>>[
                  AppSegmentedItem<String?>(
                    value: null,
                    label: l10n.activityAll,
                  ),
                  for (final value in _categories)
                    AppSegmentedItem<String?>(
                      value: value,
                      label: labelForNotificationCategory(value, l10n),
                    ),
                ],
                selected: filter.category,
                onChanged: (value) =>
                    onFilterChanged(filter.copyWith(category: value)),
              ),
            )
          : null,
      trailing: AppGlassHeaderGroup(
        children: <Widget>[
          AppGlassHeaderButton(
            key: const Key('notifications-mark-all-read'),
            icon: Icons.done_all_rounded,
            label: l10n.activityMarkAllRead,
            enabled: canMarkAllRead,
            isLoading: isMarkingAllRead,
            onTap: onMarkAllRead ?? () {},
          ),
        ],
      ),
      filterUpdate: filterUpdate,
      hasPreviousFilterItems: hasPreviousItems,
      onRetryFilter: onRetryFilter,
    );
  }

  Widget _buildMobile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = notificationCategoryFilterSummary(filter, l10n);
    return AppMobileListHeader(
      leading: mobileLeading ?? AppMobileHeaderText(countLabel: summary),
      actions: <Widget>[
        if (showCategoryFilter)
          AppGlassFilterIconButton(
            key: const Key('mobile-notification-category-filter'),
            summary: summary,
            isActive: filter.category != null,
            onPressed: () => unawaited(_showMobileCategoryDrawer(context)),
          ),
        AppGlassIconButton(
          key: const Key('mobile-notifications-mark-all-read'),
          tooltip: l10n.activityMarkAllRead,
          icon: Icons.done_all_rounded,
          onPressed: unreadCount > 0 && !isMarkingAllRead
              ? onMarkAllRead
              : null,
        ),
      ],
      filterUpdate: filterUpdate,
      hasPreviousFilterItems: hasPreviousItems,
      onRetryFilter: onRetryFilter,
    );
  }

  Future<void> _showMobileCategoryDrawer(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showAppBottomDrawer<void>(
      context: context,
      drawerKey: const Key('notification-category-filter-drawer'),
      maxHeightFactor: 0.42,
      builder: (drawerContext) => SingleChildScrollView(
        padding: EdgeInsets.all(context.appSpacing.lg),
        child: AppFilterChoiceSection<String?>(
          title: l10n.baseFilterTooltip,
          controlKey: const Key('mobile-notification-category-filter-options'),
          items: <AppSegmentedItem<String?>>[
            AppSegmentedItem<String?>(value: null, label: l10n.activityAll),
            for (final value in _categories)
              AppSegmentedItem<String?>(
                value: value,
                label: labelForNotificationCategory(value, l10n),
              ),
          ],
          selected: filter.category,
          onChanged: (value) {
            onFilterChanged(filter.copyWith(category: value));
            Navigator.of(drawerContext).pop();
          },
        ),
      ),
    );
  }
}

String notificationCategoryFilterSummary(
  ActivityNotificationFilterState filter,
  AppLocalizations l10n,
) {
  final category = filter.category;
  return category == null
      ? l10n.activityAll
      : labelForNotificationCategory(category, l10n);
}

AppBadgeTone notificationCategoryTone(String category) {
  return switch (category) {
    'error' => AppBadgeTone.error,
    'warning' => AppBadgeTone.warning,
    'info' => AppBadgeTone.primary,
    _ => AppBadgeTone.neutral,
  };
}

String labelForNotificationCategory(String value, AppLocalizations l10n) {
  return switch (value) {
    'info' => l10n.activityNotificationCategoryInfo,
    'warning' => l10n.activityNotificationCategoryWarning,
    'error' => l10n.activityNotificationCategoryError,
    'reminder' => l10n.activityNotificationCategoryReminder,
    _ => value,
  };
}
