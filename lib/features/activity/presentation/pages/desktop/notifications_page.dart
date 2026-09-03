import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/activity/presentation/providers/notification_center_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/notification_center_state.dart';
import 'package:sakuramedia/features/activity/presentation/notification_card.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';

/// 独立的「通知」消息中心页。列表、分页、筛选和无感已读由全局通知 provider
/// 驱动，卡片被渲染时即上报已读。
class DesktopNotificationsPage extends ConsumerStatefulWidget {
  const DesktopNotificationsPage({super.key});

  @override
  ConsumerState<DesktopNotificationsPage> createState() =>
      _DesktopNotificationsPageState();
}

class _DesktopNotificationsPageState
    extends ConsumerState<DesktopNotificationsPage> {
  static const double _loadMoreTriggerOffset = 300;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(notificationCenterProvider.notifier).initialize());
        _maybeAutoLoadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    _maybeAutoLoadMore();
  }

  void _maybeAutoLoadMore() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (!_shouldAutoLoadMoreForViewport()) {
      return;
    }
    final state = ref.read(notificationCenterProvider);
    if (state.hasMore &&
        !state.isLoadingMore &&
        state.loadMoreErrorMessage == null) {
      unawaited(
        ref.read(notificationCenterProvider.notifier).loadMoreNotifications(),
      );
    }
  }

  bool _shouldAutoLoadMoreForViewport() {
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) {
      return true;
    }
    return position.pixels >= position.maxScrollExtent - _loadMoreTriggerOffset;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationCenterProvider);
    ref.listen(notificationCenterProvider.select((value) => value.filter), (
      previous,
      next,
    ) {
      if (previous != next && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeAutoLoadMore();
      }
    });
    return AppPageRefreshScope(
      onRefresh: ref
          .read(notificationCenterProvider.notifier)
          .refreshNotifications,
      child: state.isInitialLoading && state.notifications.isEmpty
          ? const _NotificationsLoadingState()
          : state.initialErrorMessage != null && state.notifications.isEmpty
          ? _NotificationsErrorState(
              message: state.initialErrorMessage!,
              onRetry: ref.read(notificationCenterProvider.notifier).reloadAll,
            )
          : AppFilterResultLoadingOverlay(
              isLoading: state.filterUpdate.isLoading,
              hasPreviousItems: state.notifications.isNotEmpty,
              child: CustomScrollView(
                controller: _scrollController,
                // 收敛视口外预构建，避免卡片「提前已读」。
                cacheExtent: 0,
                slivers: _buildSlivers(context, state),
              ),
            ),
    );
  }

  List<Widget> _buildSlivers(
    BuildContext context,
    NotificationCenterState state,
  ) {
    final notifier = ref.read(notificationCenterProvider.notifier);
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          key: const Key('desktop-notifications-page'),
          padding: EdgeInsets.only(bottom: context.appSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: NotificationFilterBar(
                      state: state,
                      onFilterChanged: notifier.applyNotificationFilter,
                    ),
                  ),
                  SizedBox(width: context.appSpacing.md),
                  AppButton(
                    key: const Key('notifications-mark-all-read'),
                    label: '全部已读',
                    size: AppButtonSize.small,
                    variant: AppButtonVariant.secondary,
                    isLoading: state.isMarkingAllRead,
                    onPressed: state.unreadCount > 0 && !state.isMarkingAllRead
                        ? notifier.markAllRead
                        : null,
                  ),
                ],
              ),
              AppFilterUpdateBar(
                state: state.filterUpdate,
                hasPreviousItems: state.notifications.isNotEmpty,
                onRetry: notifier.refreshNotifications,
              ),
            ],
          ),
        ),
      ),
    ];

    if (state.notifications.isEmpty && state.filterUpdate.hasFailed) {
      return slivers;
    }
    if (state.notifications.isEmpty) {
      slivers.add(
        const SliverToBoxAdapter(child: AppEmptyState(message: '当前筛选下暂无通知')),
      );
      return slivers;
    }

    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = state.notifications[index];
          final isLast = index == state.notifications.length - 1;
          // 卡片被构建（展示）即视为已读，帧后上报避免在 build 中改状态。
          if (!item.isRead) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              notifier.onNotificationDisplayed(item.id);
            });
          }
          return Padding(
            padding: EdgeInsets.only(
              bottom: isLast ? 0 : context.appSpacing.md,
            ),
            child: RepaintBoundary(child: NotificationCard(notification: item)),
          );
        }, childCount: state.notifications.length),
      ),
    );
    slivers.add(
      SliverToBoxAdapter(
        child: Column(
          children: [
            SizedBox(height: context.appSpacing.lg),
            AppPagedLoadMoreFooter(
              isLoading: state.isLoadingMore,
              errorMessage: state.loadMoreErrorMessage,
              onRetry: notifier.loadMoreNotifications,
            ),
            SizedBox(height: context.appSpacing.xl),
          ],
        ),
      ),
    );
    return slivers;
  }
}

class _NotificationsLoadingState extends StatelessWidget {
  const _NotificationsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const AppMobileSkeletonList(
      key: Key('desktop-notifications-loading'),
      itemCount: 5,
      padding: EdgeInsets.zero,
    );
  }
}

class _NotificationsErrorState extends StatelessWidget {
  const _NotificationsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('desktop-notifications-error'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.lg),
        AppButton(label: '重试', onPressed: () => onRetry()),
      ],
    );
  }
}
