import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/activity/presentation/notification_card.dart';
import 'package:sakuramedia/features/activity/presentation/notification_center_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

/// 独立的「通知」消息中心页。消费全局 [NotificationCenterController]：
/// 列表/分页/筛选来自 controller；已读为「无感」自动处理——卡片被渲染（展示）时
/// 即上报已读，未读角标在侧边栏菜单项上常驻显示。
class DesktopNotificationsPage extends StatefulWidget {
  const DesktopNotificationsPage({super.key});

  @override
  State<DesktopNotificationsPage> createState() =>
      _DesktopNotificationsPageState();
}

class _DesktopNotificationsPageState extends State<DesktopNotificationsPage> {
  static const double _loadMoreTriggerOffset = 300;

  late final NotificationCenterController _controller;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = context.read<NotificationCenterController>();
    _scrollController.addListener(_handleScroll);
    // 若全局 controller 尚未初始化（首个消费者），幂等触发一次。
    unawaited(_controller.initialize());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
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
    if (_controller.hasMore &&
        !_controller.isLoadingMore &&
        _controller.loadMoreErrorMessage == null) {
      unawaited(_controller.loadMoreNotifications());
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _maybeAutoLoadMore();
          }
        });

        if (_controller.isInitialLoading && _controller.notifications.isEmpty) {
          return const _NotificationsLoadingState();
        }
        if (_controller.initialErrorMessage != null &&
            _controller.notifications.isEmpty) {
          return _NotificationsErrorState(
            message: _controller.initialErrorMessage!,
            onRetry: _controller.reloadAll,
          );
        }

        return CustomScrollView(
          controller: _scrollController,
          // 收敛视口外预构建，避免卡片「提前已读」。
          cacheExtent: 0,
          slivers: _buildSlivers(context),
        );
      },
    );
  }

  List<Widget> _buildSlivers(BuildContext context) {
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
                    child: NotificationFilterBar(controller: _controller),
                  ),
                  SizedBox(width: context.appSpacing.md),
                  AppButton(
                    key: const Key('notifications-mark-all-read'),
                    label: '全部已读',
                    size: AppButtonSize.small,
                    variant: AppButtonVariant.secondary,
                    isLoading: _controller.isMarkingAllRead,
                    onPressed:
                        _controller.unreadCount > 0 &&
                                !_controller.isMarkingAllRead
                            ? () => _controller.markAllRead()
                            : null,
                  ),
                ],
              ),
              if (_controller.refreshErrorMessage != null) ...[
                SizedBox(height: context.appSpacing.md),
                AppPagedLoadMoreFooter(
                  isLoading: false,
                  errorMessage: _controller.refreshErrorMessage,
                  onRetry: _controller.refreshNotifications,
                ),
              ],
            ],
          ),
        ),
      ),
    ];

    if (_controller.notifications.isEmpty) {
      slivers.add(
        const SliverToBoxAdapter(child: AppEmptyState(message: '当前筛选下暂无通知')),
      );
      return slivers;
    }

    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = _controller.notifications[index];
          final isLast = index == _controller.notifications.length - 1;
          // 卡片被构建（展示）即视为已读，帧后上报避免在 build 中改状态。
          if (!item.isRead) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _controller.onNotificationDisplayed(item.id);
            });
          }
          return Padding(
            padding: EdgeInsets.only(
              bottom: isLast ? 0 : context.appSpacing.md,
            ),
            child: RepaintBoundary(
              child: NotificationCard(
                notification: item,
                dateFormat: _dateFormat,
              ),
            ),
          );
        }, childCount: _controller.notifications.length),
      ),
    );
    slivers.add(
      SliverToBoxAdapter(
        child: Column(
          children: [
            SizedBox(height: context.appSpacing.lg),
            AppPagedLoadMoreFooter(
              isLoading: _controller.isLoadingMore,
              errorMessage: _controller.loadMoreErrorMessage,
              onRetry: _controller.loadMoreNotifications,
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
    return Center(
      key: const Key('desktop-notifications-loading'),
      child: SizedBox(
        width: double.infinity,
        height: 220,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: context.appComponentTokens.movieCardLoaderStrokeWidth,
          ),
        ),
      ),
    );
  }
}

class _NotificationsErrorState extends StatelessWidget {
  const _NotificationsErrorState({required this.message, required this.onRetry});

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
