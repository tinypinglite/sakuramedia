import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 合集连播页的「选集」浮层：从播放器右侧滑出一个剧集列表面板，盖在画面上，
/// 点击空白处或某一集后关闭。供切片合集 / 视频合集连播页复用（两端统一）。
///
/// 只负责浮层的显隐 / 滑入动画 / 遮罩 / 打开时滚动定位当前集；每一集长什么样
/// 由调用方通过 [itemBuilder] 决定（封面 + 名称 + 当前高亮 + 点击跳转）。
///
/// 注意：这与影片播放器右侧的「视频信息」抽屉是两回事，二者互不复用。
class EpisodeSelectorOverlay extends StatefulWidget {
  const EpisodeSelectorOverlay({
    super.key,
    required this.isOpen,
    required this.itemCount,
    required this.currentIndex,
    required this.itemBuilder,
    required this.onClose,
    required this.title,
    this.itemExtent = 72,
  });

  /// 是否展开。由父页面用 state 控制。
  final bool isOpen;
  final int itemCount;

  /// 当前正在播放的集索引；展开时列表自动滚动定位到它。
  final int currentIndex;

  /// 每一集的渲染（由调用方提供，含封面 / 名称 / 高亮 / 点击跳转）。
  final IndexedWidgetBuilder itemBuilder;

  /// 关闭浮层（点遮罩或选完一集时调用）。
  final VoidCallback onClose;

  /// 面板顶部标题，如「选集 · 12」。
  final String title;

  /// 固定行高，用于精确滚动定位当前集。
  final double itemExtent;

  @override
  State<EpisodeSelectorOverlay> createState() => _EpisodeSelectorOverlayState();
}

class _EpisodeSelectorOverlayState extends State<EpisodeSelectorOverlay> {
  static const Duration _animationDuration = Duration(milliseconds: 220);

  final ScrollController _scrollController = ScrollController();
  double _viewportHeight = 0;

  /// 实际行高：[EpisodeSelectorOverlay.itemExtent] 随系统字体缩放放大，
  /// 防止双行标题在放大字号下撑破固定行高（黄黑溢出条）。滚动定位用同一值。
  double _effectiveItemExtent = 0;

  @override
  void didUpdateWidget(covariant EpisodeSelectorOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOpen && widget.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 展开时把当前集滚动到可视区中部（不足一屏则贴顶 / 贴底，由 clamp 兜底）。
  void _scrollToCurrent() {
    if (!_scrollController.hasClients || widget.currentIndex < 0) {
      return;
    }
    final extent =
        _effectiveItemExtent > 0 ? _effectiveItemExtent : widget.itemExtent;
    final target =
        widget.currentIndex * extent - (_viewportHeight - extent) / 2;
    final maxOffset = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(target.clamp(0.0, maxOffset));
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !widget.isOpen,
        child: Stack(
          children: [
            // 半透明遮罩：点击关闭。
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
                child: AnimatedOpacity(
                  opacity: widget.isOpen ? 1 : 0,
                  duration: _animationDuration,
                  child: ColoredBox(color: context.appColors.mediaOverlayStrong),
                ),
              ),
            ),
            // 右侧滑出的剧集面板。
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedSlide(
                offset: widget.isOpen ? Offset.zero : const Offset(1, 0),
                duration: _animationDuration,
                curve: Curves.easeOutCubic,
                child: _buildPanel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final spacing = context.appSpacing;
    return GestureDetector(
      // 吞掉面板内的点击，避免冒泡到遮罩导致误关闭。
      onTap: () {},
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelWidth = math
              .min(360.0, constraints.maxWidth * 0.5)
              .clamp(280.0, 360.0)
              .toDouble();
          return SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: Material(
              color: context.appColors.surfaceElevated,
              child: SafeArea(
                left: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: Text(
                        widget.title,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, listConstraints) {
                          _viewportHeight = listConstraints.maxHeight;
                          // 行高随字体缩放放大：基准 itemExtent 是 textScale=1 下
                          // 的留白行高，放大时按比例抬高，保证双行标题不溢出。
                          final textScale = MediaQuery.textScalerOf(
                            context,
                          ).scale(1);
                          _effectiveItemExtent =
                              widget.itemExtent *
                              (textScale < 1 ? 1 : textScale);
                          return ListView.builder(
                            key: const Key('episode-selector-list'),
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing.sm,
                            ),
                            itemCount: widget.itemCount,
                            itemExtent: _effectiveItemExtent,
                            itemBuilder: widget.itemBuilder,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
