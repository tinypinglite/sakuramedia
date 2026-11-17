import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/activity/presentation/providers/notification_center_provider.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/presentation/activity_placeholders.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/activity/presentation/notification_card.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

/// 移动端「消息」中心页。列表、分页与无感已读来自全局通知 provider；移动端在桌面行为之上,
/// 按国内消息中心习惯增加「全部/未读」两段筛选与未读视觉(左侧红点 + 轻微高亮)。
///
/// 未读 / 高亮由 [_unreadSnapshotIds] 驱动(进入页面/下拉刷新/切到未读段/全部已读
/// 后重新拍快照),而非实时 `isRead`——否则卡片刚滚进视口被无感已读、红点 400ms 内
/// 就消失、「未读」列表也会在眼皮底下塌陷。快照让「本次有哪些是新的」在浏览期间稳定可见,
/// 无感已读继续在底层清掉服务端未读数与入口角标。
class MobileNotificationsPage extends ConsumerStatefulWidget {
  const MobileNotificationsPage({super.key});

  @override
  ConsumerState<MobileNotificationsPage> createState() =>
      _MobileNotificationsPageState();
}

enum _NotificationSegment { all, unread }

class _MobileNotificationsPageState
    extends ConsumerState<MobileNotificationsPage>
    with SingleTickerProviderStateMixin {
  static const int _skeletonCount = 6;

  late final TabController _segmentController;
  final ScrollController _scrollController = ScrollController();

  _NotificationSegment _segment = _NotificationSegment.all;
  Set<int> _unreadSnapshotIds = <int>{};
  bool _snapshotDirty = true;

  @override
  void initState() {
    super.initState();
    _segmentController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(notificationCenterProvider.notifier).initialize());
      }
    });
  }

  @override
  void dispose() {
    _segmentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 仅在快照「脏」且数据就绪时重拍未读快照;期间冻结,保证浏览稳定。
  /// 用 ref.read 取实时数据（不订阅），调用方在 setState 后或重建时触发。
  void _ensureSnapshot() {
    if (!_snapshotDirty) return;
    final state = ref.read(notificationCenterProvider);
    // 数据就绪前不拍快照：`initial` 的 isInitialLoading 为 false，只看它会把
    // 空列表固化成快照（深链/冷启动直达本页时未读段与红点会一直空着）。
    if (!state.initialized || state.isInitialLoading) {
      return;
    }
    _unreadSnapshotIds = state.notifications
        .where((item) => !item.isRead)
        .map((item) => item.id)
        .toSet();
    _snapshotDirty = false;
  }

  void _onSegmentTap(int index) {
    final next = index == 0
        ? _NotificationSegment.all
        : _NotificationSegment.unread;
    if (next == _segment) {
      return;
    }
    setState(() {
      _segment = next;
      // 每次进入「未读」段都以当下未读为准重拍快照。
      if (next == _NotificationSegment.unread) {
        _snapshotDirty = true;
      }
    });
  }

  Future<void> _handleRefresh() async {
    try {
      await ref
          .read(notificationCenterProvider.notifier)
          .refreshNotifications();
    } catch (_) {
      // 刷新失败由 Header 的 AppFilterUpdateBar 单通道呈现。
    }
    if (mounted) {
      setState(() => _snapshotDirty = true);
    }
  }

  Future<void> _handleMarkAllRead() async {
    await ref.read(notificationCenterProvider.notifier).markAllRead();
    if (mounted) {
      setState(() => _snapshotDirty = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 只订阅头部与快照所需的字段：轮询 tick 与已读回执只重建变化的行/页脚，
    // 不重建整页（见 _MobileNotificationsBodySliver / _MobileNotificationsFooterSliver）。
    final header = ref.watch(
      notificationCenterProvider.select((state) {
        return (
          unreadCount: state.unreadCount,
          isMarkingAllRead: state.isMarkingAllRead,
          filter: state.filter,
          filterUpdate: state.filterUpdate,
          hasNotifications: state.notifications.isNotEmpty,
          unreadIds: state.notifications
              .where((item) => !item.isRead)
              .map((item) => item.id)
              .join(','),
        );
      }),
    );
    _ensureSnapshot();
    final spacing = context.appSpacing;

    return Column(
      key: const Key('mobile-notifications-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          context,
          unreadCount: header.unreadCount,
          isMarkingAllRead: header.isMarkingAllRead,
          filter: header.filter,
          filterUpdate: header.filterUpdate,
          hasNotifications: header.hasNotifications,
        ),
        SizedBox(height: spacing.sm),
        Expanded(
          child: AppPagedLoadMoreScope(
            enabled: _segment == _NotificationSegment.all,
            canLoadMore: () {
              return ref.read(notificationCenterProvider).canAutoLoadMore;
            },
            onLoadMore: () => ref
                .read(notificationCenterProvider.notifier)
                .loadMoreNotifications(),
            child: AppAdaptiveRefreshScrollView(
              controller: _scrollController,
              onRefresh: _handleRefresh,
              // 收敛视口外预构建,避免「无感已读」把未展示的卡片提前标已读。
              cacheExtent: 0,
              slivers: <Widget>[
                _MobileNotificationsBodySliver(
                  segment: _segment,
                  unreadSnapshotIds: _unreadSnapshotIds,
                ),
                // 页脚常驻：loading / 失败时显示行，空闲只留上下间距（与原逻辑一致）。
                PagedLoadMoreFooterSliver(
                  topSpacing: PagedFooterSpacing.md,
                  bottomSpacing: PagedFooterSpacing.xl,
                  padWhenIdle: true,
                  watchFooter: (ref) => ref.watch(
                    notificationCenterProvider.select(
                      (state) => (
                        isLoading: state.isLoadingMore,
                        errorMessage: state.loadMoreErrorMessage,
                      ),
                    ),
                  ),
                  onLoadMore: (ref) => unawaited(
                    ref
                        .read(notificationCenterProvider.notifier)
                        .loadMoreNotifications(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required int unreadCount,
    required bool isMarkingAllRead,
    required ActivityNotificationFilterState filter,
    required FilterUpdateState filterUpdate,
    required bool hasNotifications,
  }) {
    final l10n = AppLocalizations.of(context);
    return NotificationFilterBar(
      filter: filter,
      onFilterChanged: ref
          .read(notificationCenterProvider.notifier)
          .applyNotificationFilter,
      filterUpdate: filterUpdate,
      hasPreviousItems: hasNotifications,
      onRetryFilter: ref
          .read(notificationCenterProvider.notifier)
          .refreshNotifications,
      unreadCount: unreadCount,
      isMarkingAllRead: isMarkingAllRead,
      onMarkAllRead: _handleMarkAllRead,
      showCategoryFilter: false,
      mobileLeading: AppTabBar(
        key: const Key('mobile-notifications-segments'),
        variant: AppTabBarVariant.compact,
        controller: _segmentController,
        onTap: _onSegmentTap,
        tabs: <Widget>[
          Tab(text: l10n.activityAll),
          Tab(text: l10n.activityUnread),
        ],
      ),
    );
  }
}

/// 按分段与快照过滤可见通知（列表本体订阅用）。
List<ActivityNotificationDto> _visibleNotifications(
  List<ActivityNotificationDto> notifications, {
  required _NotificationSegment segment,
  required Set<int> unreadSnapshotIds,
}) {
  if (segment == _NotificationSegment.unread) {
    return <ActivityNotificationDto>[
      for (final item in notifications)
        if (unreadSnapshotIds.contains(item.id)) item,
    ];
  }
  return notifications;
}

/// 移动端通知列表本体：只订阅可见条目 id 序列与四态。
///
/// 轮询 tick / 已读回执只改变行内数据（序列不变），不重建列表；
/// 各行通过 [_MobileNotificationRowItem] 独立订阅自己的通知对象。
class _MobileNotificationsBodySliver extends ConsumerWidget {
  const _MobileNotificationsBodySliver({
    required this.segment,
    required this.unreadSnapshotIds,
  });

  final _NotificationSegment segment;
  final Set<int> unreadSnapshotIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = ref.watch(
      notificationCenterProvider.select((state) {
        return (
          visibleIds: _visibleNotifications(
            state.notifications,
            segment: segment,
            unreadSnapshotIds: unreadSnapshotIds,
          ).map((item) => item.id).join(','),
          isInitialLoading: state.isInitialLoading,
          initialError: state.initialErrorMessage,
          hasNotifications: state.notifications.isNotEmpty,
        );
      }),
    );
    if (body.isInitialLoading && !body.hasNotifications) {
      return const _MobileNotificationsSkeletonSliver();
    }
    if (body.initialError != null && !body.hasNotifications) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppErrorState(
          key: const Key('mobile-notifications-error'),
          title: AppLocalizations.of(context).baseActionFailed,
          message: body.initialError!,
          onRetry: ref.read(notificationCenterProvider.notifier).reloadAll,
          retryKey: const Key('mobile-notifications-retry-button'),
        ),
      );
    }
    if (body.visibleIds.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          key: const Key('mobile-notifications-empty'),
          message: segment == _NotificationSegment.unread
              ? AppLocalizations.of(context).activityNoUnreadNotifications
              : AppLocalizations.of(context).activityNoNotifications,
        ),
      );
    }
    // 可见条目快照只读不订阅：序列变化时本体重建，快照即新；
    // 行内变化（已读翻转）由各行独立订阅。
    final notifications = ref.read(notificationCenterProvider).notifications;
    final visible = _visibleNotifications(
      notifications,
      segment: segment,
      unreadSnapshotIds: unreadSnapshotIds,
    );
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = visible[index];
        final isLast = index == visible.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : context.appSpacing.sm),
          child: RepaintBoundary(
            child: _MobileNotificationRowItem(
              itemId: item.id,
              snapshotUnread: unreadSnapshotIds.contains(item.id),
              fallback: item,
              isLast: isLast,
            ),
          ),
        );
      }, childCount: visible.length),
    );
  }
}

/// 移动端通知单行：独立订阅自己的通知对象（已读翻转只重建本行）。
///
/// 高亮红点走冻结快照（[snapshotUnread]），浏览期间稳定；
/// 已读上报沿用「构建即上报 + 帧后调用」语义。
class _MobileNotificationRowItem extends ConsumerWidget {
  const _MobileNotificationRowItem({
    required this.itemId,
    required this.snapshotUnread,
    required this.fallback,
    required this.isLast,
  });

  final int itemId;
  final bool snapshotUnread;
  final ActivityNotificationDto fallback;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item =
        ref.watch(
          notificationCenterProvider.select(
            (state) => _notificationById(state.notifications, itemId),
          ),
        ) ??
        fallback;
    if (!item.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(notificationCenterProvider.notifier)
            .onNotificationDisplayed(item.id);
      });
    }
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : context.appSpacing.sm),
      child: RepaintBoundary(
        child: MobileNotificationCard(
          notification: item,
          isUnread: snapshotUnread,
        ),
      ),
    );
  }
}

/// 移动端通知骨架：静态占位，无 provider 订阅。
class _MobileNotificationsSkeletonSliver extends StatelessWidget {
  const _MobileNotificationsSkeletonSliver();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final placeholders = activityNotificationPlaceholders(
      count: _MobileNotificationsPageState._skeletonCount,
    );
    // loading 用占位通知渲染真实卡片，由 [AppSkeletonizer] 灰化。
    return AppSkeletonizer.sliver(
      enabled: true,
      child: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: EdgeInsets.only(
              bottom: index == _MobileNotificationsPageState._skeletonCount - 1
                  ? 0
                  : spacing.sm,
            ),
            child: MobileNotificationCard(
              notification: placeholders[index],
              isUnread: false,
            ),
          ),
          childCount: _MobileNotificationsPageState._skeletonCount,
        ),
      ),
    );
  }
}

/// 按 id 取通知快照（行卡独立订阅用）；缺席返回 null，调用方回退占位。
ActivityNotificationDto? _notificationById(
  List<ActivityNotificationDto> notifications,
  int id,
) {
  for (final item in notifications) {
    if (item.id == id) return item;
  }
  return null;
}

/// 移动端通知卡片(纯展示)。未读由 [isUnread] 显式驱动(= 在本次未读快照中),
/// 表现为左侧红点 + 轻微高亮底色,与桌面卡片的「不区分已读/未读」不同。
class MobileNotificationCard extends StatelessWidget {
  const MobileNotificationCard({
    super.key,
    required this.notification,
    required this.isUnread,
  });

  final ActivityNotificationDto notification;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final spacing = context.appSpacing;

    return AppContentCard(
      key: Key('mobile-activity-notification-${notification.id}'),
      padding: EdgeInsets.all(spacing.md),
      backgroundColor: isUnread ? colors.selectionSurface : colors.surfaceCard,
      borderRadius: context.appRadius.mdBorder,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: spacing.sm,
            child: isUnread
                ? Padding(
                    padding: EdgeInsets.only(top: spacing.xs),
                    child: Container(
                      key: Key(
                        'mobile-activity-notification-${notification.id}-dot',
                      ),
                      width: spacing.sm,
                      height: spacing.sm,
                      decoration: BoxDecoration(
                        color: context.appTextPalette.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AppBadge(
                      label: labelForNotificationCategory(
                        notification.category,
                        l10n,
                      ),
                      tone: notificationCategoryTone(notification.category),
                      size: AppBadgeSize.compact,
                    ),
                    const Spacer(),
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
                SizedBox(height: spacing.sm),
                Text(
                  notification.title,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: isUnread
                        ? AppTextWeight.semibold
                        : AppTextWeight.medium,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: spacing.xs),
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
    );
  }
}
