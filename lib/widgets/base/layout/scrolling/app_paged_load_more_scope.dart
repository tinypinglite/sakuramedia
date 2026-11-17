import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// 统一驱动分页滚动视图的下一页加载。
///
/// 同时监听滚动位置变化与滚动尺寸变化：
/// - 用户滚动接近底部时，按 [triggerOffset] 触发。
/// - 首次布局、窗口尺寸变化或内容追加后不足一屏时，立即触发。
///
/// Scope 不持有 [ScrollController]，只读取滚动通知；页面原有的控制器仍可
/// 用于筛选跳回、吸顶定位等操作。每个 Scope 只能包住一个滚动视图。
class AppPagedLoadMoreScope extends StatefulWidget {
  const AppPagedLoadMoreScope({
    super.key,
    required this.canLoadMore,
    required this.onLoadMore,
    required this.child,
    this.enabled = true,
    this.triggerOffset = 300,
  });

  /// 必须在触发时读取实时状态，不能使用已中立化 loadMore 状态的 build 快照。
  final bool Function() canLoadMore;

  /// 返回真实请求 Future；同一时间 Scope 只允许一个请求在途。
  final Future<void> Function() onLoadMore;

  final Widget child;

  /// 页面/Tab 是否处于可自动加载状态；隐藏分支还会受 [TickerMode] 约束。
  final bool enabled;

  /// 用户滚动到距底部多少逻辑像素时触发。
  final double triggerOffset;

  @override
  State<AppPagedLoadMoreScope> createState() => _AppPagedLoadMoreScopeState();
}

class _AppPagedLoadMoreScopeState extends State<AppPagedLoadMoreScope> {
  static const double _underfillTolerance = 0.5;

  /// 最近一次通知来自哪个纵向滚动视图。
  ///
  /// 只记录 context，不缓存 [ScrollMetrics]：`ScrollMetricsNotification` 在布局
  /// 结束后通过 microtask 派发，而 build 里排的 post-frame callback 会先执行，
  /// 缓存 metrics 会让 append / 隐藏 Tab 用上一帧的 extentAfter 继续补页。
  /// 真正需要判定时再回读这个滚动视图的实时 position。
  BuildContext? _metricsContext;
  bool _checkScheduled = false;
  bool _loadInFlight = false;
  bool _allowScrollThreshold = false;
  bool _effectiveEnabled = false;

  @override
  Widget build(BuildContext context) {
    _effectiveEnabled = widget.enabled && TickerMode.of(context);
    if (_effectiveEnabled) {
      _scheduleCheck();
    }

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth != 0 ||
            notification.metrics.axis != Axis.vertical) {
          return false;
        }
        _recordMetricsContext(notification.context);
        if (notification.metrics.extentAfter <= _underfillTolerance) {
          _scheduleCheck();
        }
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0 ||
              notification.metrics.axis != Axis.vertical) {
            return false;
          }
          _recordMetricsContext(notification.context);
          if ((notification is ScrollUpdateNotification ||
                  notification is ScrollEndNotification) &&
              notification.metrics.extentAfter <= widget.triggerOffset) {
            _scheduleCheck(allowScrollThreshold: true);
          }
          return false;
        },
        child: widget.child,
      ),
    );
  }

  void _recordMetricsContext(BuildContext? context) {
    if (context == null || !context.mounted) {
      return;
    }
    _metricsContext = context;
  }

  void _scheduleCheck({bool allowScrollThreshold = false}) {
    if (!mounted || !_effectiveEnabled || _loadInFlight) {
      return;
    }
    _allowScrollThreshold |= allowScrollThreshold;
    if (_checkScheduled) {
      return;
    }
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      final allowScrollThreshold = _allowScrollThreshold;
      _allowScrollThreshold = false;
      if (!mounted || !_effectiveEnabled || _loadInFlight) {
        return;
      }

      final metricsContext = _metricsContext;
      if (metricsContext == null || !metricsContext.mounted) {
        return;
      }

      // 回读实时 position，不能使用通知里的 metrics 快照：本回调可能在本次
      // layout 产生的 ScrollMetricsNotification 之前执行。
      final scrollable = metricsContext
          .findAncestorStateOfType<ScrollableState>();
      final position = scrollable?.position;
      if (position == null ||
          !position.hasContentDimensions ||
          position.axis != Axis.vertical) {
        return;
      }

      final threshold = allowScrollThreshold
          ? widget.triggerOffset
          : _underfillTolerance;
      if (position.extentAfter > threshold || !widget.canLoadMore()) {
        return;
      }

      _loadInFlight = true;
      unawaited(_runLoadMore());
    });
  }

  Future<void> _runLoadMore() async {
    try {
      await widget.onLoadMore();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'AppPagedLoadMoreScope',
          context: ErrorDescription('while loading the next page'),
        ),
      );
    } finally {
      _loadInFlight = false;
    }
  }
}
