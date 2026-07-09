import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/presentation/notification_center_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';

/// 通知列表卡片。已读为「无感」自动处理，卡片本身不区分已读/未读视觉，
/// 未读信号统一交给侧边栏角标。
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
  });

  final ActivityNotificationDto notification;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      width: double.infinity,
      child: Container(
        key: Key('activity-notification-${notification.id}'),
        width: double.infinity,
        padding: EdgeInsets.all(context.appSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: context.appRadius.mdBorder,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.28),
          ),
        ),
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
                  label: labelForNotificationCategory(notification.category),
                  tone: notificationCategoryTone(notification.category),
                ),
                Text(
                  formatUpdatedAtLabel(notification.createdAt) ?? '时间未知',
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
      ),
    );
  }
}

/// 通知分类筛选条（接 [NotificationCenterController]）。
class NotificationFilterBar extends StatelessWidget {
  const NotificationFilterBar({super.key, required this.controller});

  final NotificationCenterController controller;

  static const List<String> _categories = <String>[
    'info',
    'warning',
    'error',
    'reminder',
  ];

  @override
  Widget build(BuildContext context) {
    final layoutTokens = context.appLayoutTokens;
    final filterTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.tertiary,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.md,
      children: [
        SizedBox(
          width: layoutTokens.filterFieldWidthMd,
          child: AppSelectField<String?>(
            key: const Key('notification-category-filter'),
            value: controller.filter.category,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(value: null, child: Text('全部')),
              ..._categories.map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Text(labelForNotificationCategory(value)),
                ),
              ),
            ],
            onChanged:
                controller.isRefreshing
                    ? null
                    : (value) => controller.applyNotificationFilter(
                      controller.filter.copyWith(category: value),
                    ),
          ),
        ),
        _FilterRefreshIndicator(
          indicatorKey: const Key('notification-filter-loading'),
          isVisible: controller.isRefreshing,
        ),
      ],
    );
  }
}

class _FilterRefreshIndicator extends StatelessWidget {
  const _FilterRefreshIndicator({
    required this.indicatorKey,
    required this.isVisible,
  });

  final Key indicatorKey;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child:
            isVisible
                ? SizedBox(
                  key: indicatorKey,
                  width: 18,
                  height: 18,
                  child: const CircularProgressIndicator.adaptive(
                    strokeWidth: 2.2,
                  ),
                )
                : null,
      ),
    );
  }
}


AppBadgeTone notificationCategoryTone(String category) {
  return switch (category) {
    'error' => AppBadgeTone.error,
    'warning' => AppBadgeTone.warning,
    'info' => AppBadgeTone.primary,
    _ => AppBadgeTone.neutral,
  };
}

String labelForNotificationCategory(String value) {
  return switch (value) {
    'info' => '信息',
    'warning' => '警告',
    'error' => '错误',
    'reminder' => '提醒',
    _ => value,
  };
}
