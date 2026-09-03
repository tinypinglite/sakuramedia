import 'dart:async';

import 'package:flutter/material.dart';
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
    this.indicatorDelay = const Duration(milliseconds: 150),
  });

  final bool isLoading;
  final bool hasPreviousItems;
  final Widget child;

  /// 实际请求很快完成时不显示进度标记，避免短暂闪烁。
  final Duration indicatorDelay;

  @override
  State<AppFilterResultLoadingOverlay> createState() =>
      _AppFilterResultLoadingOverlayState();
}

class _AppFilterResultLoadingOverlayState
    extends State<AppFilterResultLoadingOverlay> {
  Timer? _showTimer;
  bool _isIndicatorVisible = false;

  @override
  void initState() {
    super.initState();
    if (widget.isLoading && !widget.hasPreviousItems) {
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

    if (!widget.isLoading) {
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
      if (!mounted || !widget.isLoading) return;
      setState(() => _isIndicatorVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_isIndicatorVisible)
          Positioned.fill(
            child: IgnorePointer(
              child: Semantics(
                label: '筛选结果加载中',
                liveRegion: true,
                child: _FilterResultLoadingIndicator(
                  obscureContent: !widget.hasPreviousItems,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterResultLoadingIndicator extends StatelessWidget {
  const _FilterResultLoadingIndicator({required this.obscureContent});

  final bool obscureContent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;

    return ColoredBox(
      color: obscureContent
          ? colors.surfaceElevated.withValues(alpha: 0.96)
          : Colors.transparent,
      child: Center(
        child: DecoratedBox(
          key: const Key('app-filter-result-loading-overlay'),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: context.appRadius.mdBorder,
            boxShadow: context.appShadows.card,
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: SizedBox(
              width: componentTokens.iconSizeMd,
              height: componentTokens.iconSizeMd,
              child: CircularProgressIndicator(
                strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
