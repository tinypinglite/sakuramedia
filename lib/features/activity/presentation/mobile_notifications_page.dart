import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/activity/data/activity_notification_dto.dart';
import 'package:sakuramedia/features/activity/presentation/notification_card.dart';
import 'package:sakuramedia/features/activity/presentation/notification_center_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_badge.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';

/// 移动端「消息」中心页。消费全局 [NotificationCenterController]
/// (列表/分页来自 controller、已读为「无感」自动处理);移动端在桌面行为之上,
/// 按国内消息中心习惯增加「全部/未读」两段筛选与未读视觉(左侧红点 + 轻微高亮)。
///
/// 未读 / 高亮由 [_unreadSnapshotIds] 驱动(进入页面/下拉刷新/切到未读段/全部已读
/// 后重新拍快照),而非实时 `isRead`——否则卡片刚滚进视口被无感已读、红点 400ms 内
/// 就消失、「未读」列表也会在眼皮底下塌陷。快照让「本次有哪些是新的」在浏览期间稳定可见,
/// 无感已读继续在底层清掉服务端未读数与入口角标。
class MobileNotificationsPage extends StatefulWidget {
  const MobileNotificationsPage({super.key});

  @override
  State<MobileNotificationsPage> createState() =>
      _MobileNotificationsPageState();
}

enum _NotificationSegment { all, unread }

class _MobileNotificationsPageState extends State<MobileNotificationsPage>
    with SingleTickerProviderStateMixin {
  static const double _loadMoreTriggerOffset = 300;
  static const int _skeletonCount = 6;

  late final NotificationCenterController _controller;
  late final TabController _segmentController;
  final ScrollController _scrollController = ScrollController();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  _NotificationSegment _segment = _NotificationSegment.all;
  Set<int> _unreadSnapshotIds = <int>{};
  bool _snapshotDirty = true;

  @override
  void initState() {
    super.initState();
    _controller = context.read<NotificationCenterController>();
    _segmentController = TabController(length: 2, vsync: this);
    _controller.addListener(_handleControllerUpdate);
    _scrollController.addListener(_handleScroll);
    // 若全局 controller 尚未初始化(首个消费者),幂等触发一次。
    unawaited(_controller.initialize());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeAutoLoadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerUpdate);
    _segmentController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleControllerUpdate() {
    _maybeAutoLoadMore();
    if (mounted) {
      setState(() {});
    }
  }

  void _handleScroll() => _maybeAutoLoadMore();

  void _maybeAutoLoadMore() {
    // 「未读」段是基于冻结快照的本地过滤，再翻页也不会增加可见的未读项；若此时因
    // 空列表/短内容判到底而自动翻页，会把整条通知历史逐页抽干。故仅「全部」段自动翻页。
    if (_segment == _NotificationSegment.unread) {
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final reachedEnd =
        position.maxScrollExtent <= 0 ||
        position.pixels >= position.maxScrollExtent - _loadMoreTriggerOffset;
    if (!reachedEnd) {
      return;
    }
    if (_controller.hasMore &&
        !_controller.isLoadingMore &&
        _controller.loadMoreErrorMessage == null) {
      unawaited(_controller.loadMoreNotifications());
    }
  }

  /// 仅在快照「脏」且数据就绪时重拍未读快照;期间冻结,保证浏览稳定。
  void _ensureSnapshot() {
    if (!_snapshotDirty || _controller.isInitialLoading) {
      return;
    }
    _unreadSnapshotIds = _controller.notifications
        .where((item) => !item.isRead)
        .map((item) => item.id)
        .toSet();
    _snapshotDirty = false;
  }

  void _onSegmentTap(int index) {
    final next =
        index == 0 ? _NotificationSegment.all : _NotificationSegment.unread;
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
      await _controller.refreshNotifications();
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '刷新失败，请稍后重试'));
      }
    }
    if (mounted) {
      setState(() => _snapshotDirty = true);
    }
  }

  Future<void> _handleMarkAllRead() async {
    await _controller.markAllRead();
    if (mounted) {
      setState(() => _snapshotDirty = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureSnapshot();
    final spacing = context.appSpacing;

    return Column(
      key: const Key('mobile-notifications-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        SizedBox(height: spacing.sm),
        Expanded(
          child: AppAdaptiveRefreshScrollView(
            controller: _scrollController,
            onRefresh: _handleRefresh,
            // 收敛视口外预构建,避免「无感已读」把未展示的卡片提前标已读。
            cacheExtent: 0,
            slivers: _buildSlivers(context),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: AppTabBar(
            key: const Key('mobile-notifications-segments'),
            variant: AppTabBarVariant.compact,
            controller: _segmentController,
            onTap: _onSegmentTap,
            tabs: const <Widget>[Tab(text: '全部'), Tab(text: '未读')],
          ),
        ),
        SizedBox(width: context.appSpacing.md),
        AppButton(
          key: const Key('mobile-notifications-mark-all-read'),
          label: '全部已读',
          size: AppButtonSize.small,
          variant: AppButtonVariant.secondary,
          isLoading: _controller.isMarkingAllRead,
          onPressed:
              _controller.unreadCount > 0 && !_controller.isMarkingAllRead
                  ? _handleMarkAllRead
                  : null,
        ),
      ],
    );
  }

  List<Widget> _buildSlivers(BuildContext context) {
    if (_controller.isInitialLoading && _controller.notifications.isEmpty) {
      return <Widget>[_buildSkeletonSliver(context)];
    }
    if (_controller.initialErrorMessage != null &&
        _controller.notifications.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            key: const Key('mobile-notifications-error'),
            message: _controller.initialErrorMessage!,
            onRetry: () => _controller.reloadAll(),
          ),
        ),
      ];
    }

    final visible = _visibleNotifications();
    if (visible.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            key: const Key('mobile-notifications-empty'),
            message:
                _segment == _NotificationSegment.unread ? '没有未读消息' : '暂无消息',
          ),
        ),
      ];
    }

    return <Widget>[
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = visible[index];
          final isLast = index == visible.length - 1;
          // 卡片被构建(展示)即视为已读,帧后上报避免在 build 中改状态。
          if (!item.isRead) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _controller.onNotificationDisplayed(item.id);
            });
          }
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : context.appSpacing.sm),
            child: RepaintBoundary(
              child: MobileNotificationCard(
                notification: item,
                dateFormat: _dateFormat,
                isUnread: _unreadSnapshotIds.contains(item.id),
              ),
            ),
          );
        }, childCount: visible.length),
      ),
      SliverToBoxAdapter(
        child: Column(
          children: [
            SizedBox(height: context.appSpacing.md),
            AppPagedLoadMoreFooter(
              isLoading: _controller.isLoadingMore,
              errorMessage: _controller.loadMoreErrorMessage,
              onRetry: _controller.loadMoreNotifications,
            ),
            SizedBox(height: context.appSpacing.xl),
          ],
        ),
      ),
    ];
  }

  List<ActivityNotificationDto> _visibleNotifications() {
    final all = _controller.notifications;
    if (_segment == _NotificationSegment.all) {
      return all;
    }
    return all
        .where((item) => _unreadSnapshotIds.contains(item.id))
        .toList(growable: false);
  }

  Widget _buildSkeletonSliver(BuildContext context) {
    final spacing = context.appSpacing;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: EdgeInsets.only(
            bottom: index == _skeletonCount - 1 ? 0 : spacing.sm,
          ),
          child: const _MobileNotificationSkeleton(),
        ),
        childCount: _skeletonCount,
      ),
    );
  }
}

/// 移动端通知卡片(纯展示)。未读由 [isUnread] 显式驱动(= 在本次未读快照中),
/// 表现为左侧红点 + 轻微高亮底色,与桌面卡片的「不区分已读/未读」不同。
class MobileNotificationCard extends StatelessWidget {
  const MobileNotificationCard({
    super.key,
    required this.notification,
    required this.dateFormat,
    required this.isUnread,
  });

  final ActivityNotificationDto notification;
  final DateFormat dateFormat;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    return Container(
      key: Key('mobile-activity-notification-${notification.id}'),
      width: double.infinity,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: isUnread ? colors.selectionSurface : colors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
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
                      label: labelForNotificationCategory(notification.category),
                      tone: notificationCategoryTone(notification.category),
                      size: AppBadgeSize.compact,
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(notification.createdAt, dateFormat),
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
                    weight:
                        isUnread ? AppTextWeight.semibold : AppTextWeight.medium,
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

class _MobileNotificationSkeleton extends StatelessWidget {
  const _MobileNotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    Widget bar({required double width}) {
      return Container(
        height: spacing.md,
        width: width,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.smBorder,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(width: context.appLayoutTokens.filterFieldWidthMd),
          SizedBox(height: spacing.sm),
          bar(width: double.infinity),
          SizedBox(height: spacing.xs),
          bar(width: double.infinity),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? value, DateFormat formatter) {
  if (value == null) {
    return '时间未知';
  }
  return formatter.format(value.toLocal());
}
