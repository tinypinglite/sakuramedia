import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 遥控页的细进度条：支持点击与拖动跳转。
///
/// 拖动中的目标位置通过 [onPreview] 实时上报（null 表示结束预览），
/// 供页面把时间文字替换为目标时间；松手或点击时通过 [onSeek] 提交最终目标。
class CastRemoteProgressBar extends StatefulWidget {
  const CastRemoteProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.enabled,
    required this.onSeek,
    this.onPreview,
  });

  final Duration position;
  final Duration duration;
  final bool enabled;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration?>? onPreview;

  @override
  State<CastRemoteProgressBar> createState() => _CastRemoteProgressBarState();
}

class _CastRemoteProgressBarState extends State<CastRemoteProgressBar> {
  static const double _trackHeight = 4;
  static const double _thumbSize = 12;
  static const double _touchHeight = 28;

  double? _dragFraction;
  bool _dragging = false;

  bool get _canInteract => widget.enabled && widget.duration > Duration.zero;

  double get _fraction {
    final drag = _dragFraction;
    if (drag != null) {
      return drag;
    }
    final total = widget.duration.inMilliseconds;
    if (total <= 0) {
      return 0;
    }
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration _fractionToTarget(double fraction) => Duration(
    milliseconds: (widget.duration.inMilliseconds * fraction).round(),
  );

  void _updateFraction(Offset localPosition, double width) {
    if (width <= 0) {
      return;
    }
    final fraction = (localPosition.dx / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = fraction);
    widget.onPreview?.call(_fractionToTarget(fraction));
  }

  void _commitDrag() {
    final fraction = _dragFraction;
    setState(() {
      _dragFraction = null;
      _dragging = false;
    });
    widget.onPreview?.call(null);
    if (fraction != null) {
      widget.onSeek(_fractionToTarget(fraction));
    }
  }

  void _cancelDrag() {
    setState(() {
      _dragFraction = null;
      _dragging = false;
    });
    widget.onPreview?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = _canInteract;
    final primary = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fraction = _fraction;
        final filledWidth = width * fraction;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: enabled
              ? (details) {
                  final tapFraction = (details.localPosition.dx / width)
                      .clamp(0.0, 1.0);
                  widget.onSeek(_fractionToTarget(tapFraction));
                }
              : null,
          onHorizontalDragStart: enabled
              ? (details) {
                  setState(() => _dragging = true);
                  _updateFraction(details.localPosition, width);
                }
              : null,
          onHorizontalDragUpdate: enabled
              ? (details) => _updateFraction(details.localPosition, width)
              : null,
          onHorizontalDragEnd: enabled ? (_) => _commitDrag() : null,
          onHorizontalDragCancel: enabled ? _cancelDrag : null,
          child: SizedBox(
            height: _touchHeight,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: _trackHeight,
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: context.appRadius.pillBorder,
                  ),
                ),
                Container(
                  width: filledWidth,
                  height: _trackHeight,
                  decoration: BoxDecoration(
                    color: enabled ? primary : primary.withValues(alpha: 0.4),
                    borderRadius: context.appRadius.pillBorder,
                  ),
                ),
                if (enabled)
                  Positioned(
                    left: (filledWidth - _thumbSize / 2).clamp(
                      0.0,
                      width - _thumbSize,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surfaceCard, width: 2),
                        boxShadow: _dragging ? context.appShadows.panel : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
