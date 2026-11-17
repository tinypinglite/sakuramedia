import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_pull_refresh_notification.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/theme.dart';

/// 服务端筛选请求中的结果区反馈。
///
/// 筛选控件会立即切换选中态；防抖窗口内不显示任何反馈。实际请求持续一小段时间
/// 后，在结果区中央显示非阻塞的进度标记，保留已有条目，避免顶栏和列表发生位移。
class AppFilterResultLoadingOverlay extends StatefulWidget {
  const AppFilterResultLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.hasPreviousItems,
    required this.child,
    this.protectedHeaderKey,
    this.scrollController,
    this.surfaceColor,
    this.indicatorDelay = const Duration(milliseconds: 150),
  });

  final bool isLoading;
  final bool hasPreviousItems;
  final Widget child;

  final Color? surfaceColor;

  /// 吸顶页的控制栏和主滚动控制器，用于把加载遮罩裁剪在控制栏下方。
  final GlobalKey? protectedHeaderKey;
  final ScrollController? scrollController;

  /// 实际请求很快完成时不显示进度标记，避免短暂闪烁。
  final Duration indicatorDelay;

  @override
  State<AppFilterResultLoadingOverlay> createState() =>
      _AppFilterResultLoadingOverlayState();
}

class _AppFilterResultLoadingOverlayState
    extends State<AppFilterResultLoadingOverlay> {
  final _stackKey = GlobalKey();
  Timer? _showTimer;
  bool _isIndicatorVisible = false;
  bool _isPullRefreshing = false;

  bool get _isLoading => widget.isLoading && !_isPullRefreshing;

  @override
  void initState() {
    super.initState();
    if (_isLoading && !widget.hasPreviousItems) {
      _isIndicatorVisible = true;
    } else {
      _syncVisibility();
    }
  }

  @override
  void didUpdateWidget(covariant AppFilterResultLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading ||
        oldWidget.hasPreviousItems != widget.hasPreviousItems ||
        oldWidget.indicatorDelay != widget.indicatorDelay) {
      _syncVisibility();
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  void _syncVisibility() {
    _showTimer?.cancel();
    _showTimer = null;

    if (!_isLoading) {
      if (_isIndicatorVisible && mounted) {
        setState(() => _isIndicatorVisible = false);
      }
      return;
    }

    // 没有旧条目时，先把旧空态遮住，再显示居中的请求中状态，避免「暂无数据」和
    // loading 同时出现。已有条目则给短暂缓冲，快速请求不打扰浏览节奏。
    if (!widget.hasPreviousItems) {
      if (!_isIndicatorVisible && mounted) {
        setState(() => _isIndicatorVisible = true);
      }
      return;
    }

    if (_isIndicatorVisible && mounted) {
      setState(() => _isIndicatorVisible = false);
    }

    _showTimer = Timer(widget.indicatorDelay, () {
      if (!mounted || !_isLoading) return;
      setState(() => _isIndicatorVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    return NotificationListener<AppPullRefreshNotification>(
      onNotification: (notification) {
        _isPullRefreshing = notification.isRefreshing;
        _syncVisibility();
        return true;
      },
      child: Stack(
        key: _stackKey,
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_isIndicatorVisible)
            Positioned.fill(
              child: ClipRect(
                clipper: widget.protectedHeaderKey == null
                    ? null
                    : _BelowHeaderClipper(
                        headerKey: widget.protectedHeaderKey!,
                        stackKey: _stackKey,
                        scrollController: widget.scrollController,
                      ),
                child: IgnorePointer(
                  child: Semantics(
                    label: l10n.baseFilterResultsLoading,
                    liveRegion: true,
                    child: _FilterResultLoadingIndicator(
                      obscureContent: !widget.hasPreviousItems,
                      surfaceColor: widget.surfaceColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterResultLoadingIndicator extends StatelessWidget {
  const _FilterResultLoadingIndicator({
    required this.obscureContent,
    this.surfaceColor,
  });

  final bool obscureContent;
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;

    return ColoredBox(
      color: obscureContent
          ? (surfaceColor ?? colors.surfaceElevated).withValues(alpha: 0.96)
          : Colors.transparent,
      child: Center(
        child: DecoratedBox(
          key: const Key('app-filter-result-loading-overlay'),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: context.appRadius.mdBorder,
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: SizedBox(
              width: componentTokens.iconSizeMd,
              height: componentTokens.iconSizeMd,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BelowHeaderClipper extends CustomClipper<Rect> {
  _BelowHeaderClipper({
    required this.headerKey,
    required this.stackKey,
    required ScrollController? scrollController,
  }) : super(reclip: scrollController);
  final GlobalKey headerKey;
  final GlobalKey stackKey;

  @override
  Rect getClip(Size size) {
    final header = headerKey.currentContext?.findRenderObject();
    final stack = stackKey.currentContext?.findRenderObject();
    if (header == null || stack == null || !header.attached) {
      return Offset.zero & size;
    }
    final bounds = MatrixUtils.transformRect(
      header.getTransformTo(stack),
      header.paintBounds,
    );
    final top = bounds.bottom.clamp(0.0, size.height);
    return Rect.fromLTRB(0, top, size.width, size.height);
  }

  @override
  bool shouldReclip(_BelowHeaderClipper oldClipper) => true;
}
