import 'package:material_ui/material_ui.dart';

/// 侧边栏一级导航的滚动区。当内容溢出、底部仍可下滑时，在底部叠一层
/// 透明→底色的渐隐遮罩，提示「下面还有内容」；滚到底自动消失。
/// 遮罩为纯装饰（[IgnorePointer]），不拦截对底部菜单项的点击。
/// 桌面侧栏不需要滚动条：用 [ScrollConfiguration] 关掉全局
/// [MaterialScrollBehavior] 自动叠加的滚动条，保留滚轮/拖拽滚动。
class SidebarNavScrollArea extends StatefulWidget {
  const SidebarNavScrollArea({
    super.key,
    required this.horizontalPadding,
    required this.fadeColor,
    required this.isCompact,
    required this.children,
  });

  final double horizontalPadding;
  final Color fadeColor;
  final bool isCompact;
  final List<Widget> children;

  @override
  State<SidebarNavScrollArea> createState() => _SidebarNavScrollAreaState();
}

class _SidebarNavScrollAreaState extends State<SidebarNavScrollArea> {
  final ScrollController _controller = ScrollController();
  bool _canScrollDown = false;
  double? _offsetBeforeCompact;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_recompute);
    _scheduleRecompute();
  }

  @override
  void didUpdateWidget(covariant SidebarNavScrollArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompact != widget.isCompact) {
      if (widget.isCompact) {
        // 收起态不再构建账户卡，导航视口会临时变高；先记住位置，
        // 展开时再恢复，避免 ScrollPosition 在视口变高时把偏移量夹小。
        _offsetBeforeCompact = _controller.hasClients
            ? _controller.offset
            : null;
      } else {
        _restoreOffsetAfterCompact();
      }
    }
    // 折叠/展开或导航内容变化会改变溢出状态，下一帧重新评估。
    _scheduleRecompute();
  }

  @override
  void dispose() {
    _controller.removeListener(_recompute);
    _controller.dispose();
    super.dispose();
  }

  void _scheduleRecompute() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
  }

  void _restoreOffsetAfterCompact() {
    final offset = _offsetBeforeCompact;
    _offsetBeforeCompact = null;
    if (offset == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      final maxScrollExtent = _controller.position.maxScrollExtent;
      _controller.jumpTo(offset.clamp(0.0, maxScrollExtent));
    });
  }

  void _recompute() {
    if (!mounted || !_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final canScrollDown =
        position.maxScrollExtent > 0 &&
        position.pixels < position.maxScrollExtent - 1.0;
    if (canScrollDown != _canScrollDown) {
      setState(() => _canScrollDown = canScrollDown);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        // 视口或内容尺寸变化（如窗口 resize）时同步重算。
        _scheduleRecompute();
        return false;
      },
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              controller: _controller,
              padding: EdgeInsets.symmetric(
                horizontal: widget.horizontalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _canScrollDown ? 1 : 0,
                child: Container(
                  key: const Key('sidebar-nav-scroll-fade'),
                  height: _sidebarNavFadeHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.fadeColor.withValues(alpha: 0),
                        widget.fadeColor,
                      ],
                    ),
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

const double _sidebarNavFadeHeight = 32;
