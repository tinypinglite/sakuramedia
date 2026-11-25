import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

typedef AppBottomDrawerScrollBuilder =
    Widget Function(BuildContext context, ScrollController controller);

/// 底部抽屉里的垂直滚动区，底部只在仍有内容时显示下滑提示。
///
/// 调用方必须把传入的 controller 交给滚动视图。提示跟随滚动视口，不占用
/// 抽屉固定底栏的位置，因此不会盖住确认、取消或重置按钮。
class AppBottomDrawerScrollRegion extends StatefulWidget {
  const AppBottomDrawerScrollRegion({
    super.key,
    required this.builder,
    this.controller,
    this.enabled = true,
  });

  static const Key cueKey = Key('app-bottom-drawer-scroll-cue');

  final AppBottomDrawerScrollBuilder builder;
  final ScrollController? controller;
  final bool enabled;

  @override
  State<AppBottomDrawerScrollRegion> createState() =>
      _AppBottomDrawerScrollRegionState();
}

class _AppBottomDrawerScrollRegionState
    extends State<AppBottomDrawerScrollRegion> {
  ScrollController? _ownedController;
  bool _showCue = false;
  bool _syncScheduled = false;

  ScrollController get _controller =>
      widget.controller ?? (_ownedController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scheduleSync);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant AppBottomDrawerScrollRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)?.removeListener(_scheduleSync);
      if (oldWidget.controller == null && widget.controller != null) {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _controller.addListener(_scheduleSync);
      _scheduleSync();
    } else if (oldWidget.enabled != widget.enabled) {
      _scheduleSync();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_scheduleSync);
    _ownedController?.dispose();
    super.dispose();
  }

  void _scheduleSync() {
    if (_syncScheduled) {
      return;
    }
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) {
        return;
      }
      final showCue =
          widget.enabled &&
          _controller.hasClients &&
          _controller.position.extentAfter > 1;
      if (showCue != _showCue) {
        setState(() => _showCue = showCue);
      }
    });
  }

  void _scrollDown() {
    if (!_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final target = math.min(
      position.maxScrollExtent,
      position.pixels + position.viewportDimension * 0.8,
    );
    if (target <= position.pixels) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(target);
      return;
    }
    position.animateTo(
      target,
      duration: context.appMotion.normal,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _scheduleSync();
        return false;
      },
      child: Stack(
        children: [
          widget.builder(context, _controller),
          if (_showCue)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height: spacing.xxl + spacing.xs,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          context.appColors.surfaceCard.withValues(alpha: 0),
                          context.appColors.surfaceCard.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_showCue)
            Positioned(
              left: 0,
              right: 0,
              bottom: spacing.xs,
              child: Center(
                child: Semantics(
                  button: true,
                  label: AppLocalizations.of(context).baseScrollDownForMore,
                  child: AppInteractiveSurface(
                    onTap: _scrollDown,
                    focusRingRadius: context.appRadius.pillBorder,
                    child: DecoratedBox(
                      key: AppBottomDrawerScrollRegion.cueKey,
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceMuted,
                        borderRadius: context.appRadius.pillBorder,
                        border: Border.all(
                          color: context.appColors.borderStrong,
                        ),
                        boxShadow: context.appShadows.panel,
                      ),
                      child: SizedBox(
                        width: tokens.iconSizeLg + spacing.md,
                        height: tokens.iconSizeLg + spacing.xs,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: tokens.iconSizeSm,
                          color: context.appTextPalette.secondary,
                        ),
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
