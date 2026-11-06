import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';

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

/// 通知分类筛选条：纯状态输入与动作回调，不持有业务控制器。
class NotificationFilterBar extends StatelessWidget {
  const NotificationFilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
  });

  final ActivityNotificationFilterState filter;
  final ValueChanged<ActivityNotificationFilterState> onFilterChanged;

  static const List<String> _categories = <String>[
    'info',
    'warning',
    'error',
    'reminder',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            value: filter.category,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: <DropdownMenuItem<String?>>[
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.activityAll),
              ),
              ..._categories.map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Text(labelForNotificationCategory(value, l10n)),
                ),
              ),
            ],
            onChanged: (value) =>
                onFilterChanged(filter.copyWith(category: value)),
          ),
        ),
      ],
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

String labelForNotificationCategory(String value, AppLocalizations l10n) {
  return switch (value) {
    'info' => l10n.activityNotificationCategoryInfo,
    'warning' => l10n.activityNotificationCategoryWarning,
    'error' => l10n.activityNotificationCategoryError,
    'reminder' => l10n.activityNotificationCategoryReminder,
    _ => value,
  };
}
