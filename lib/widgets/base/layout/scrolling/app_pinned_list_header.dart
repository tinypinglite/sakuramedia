import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';

/// 资料区后的列表控制栏。
class AppPinnedListHeader extends StatelessWidget {
  const AppPinnedListHeader({super.key, required this.child});

  final Widget child;

  /// 切筛选回到结果区开头；尚未滚过资料区时保留当前位置。
  static void scrollToStart(GlobalKey headerKey, ScrollController controller) {
    final renderObject = headerKey.currentContext?.findRenderObject();
    if (!controller.hasClients || renderObject == null) return;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return;
    final offset = viewport.getOffsetToReveal(renderObject, 0).offset;
    final position = controller.position;
    if (position.pixels > offset) {
      controller.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PinnedHeaderSliver(
    child: Listener(behavior: HitTestBehavior.opaque, child: child),
  );
}

/// 吸顶列表的标准三段式：前置内容 + 吸顶控制栏 + 后置结果。
///
/// 页面只负责传入三部分，前置/结果会被自动裁在控制栏边界之外，避免透明
/// 控制栏下方透出内容。
class AppPinnedSliverSection extends StatelessWidget {
  const AppPinnedSliverSection({
    super.key,
    required this.headerKey,
    required this.header,
    required this.after,
    this.before = const <Widget>[],
    this.headerBottomSpacing = 0,
  }) : assert(headerBottomSpacing >= 0);

  final GlobalKey headerKey;
  final List<Widget> before;
  final Widget header;

  /// 吸顶控制栏与滚动结果之间的持久留白。
  ///
  /// 必须放在吸顶头内部，才能让裁切边界和吸顶后的视觉间距保持一致；不要把
  /// 间距塞进 [after] 的首个 sliver。
  final double headerBottomSpacing;

  final List<Widget> after;

  @override
  Widget build(BuildContext context) {
    final pinnedHeader = headerBottomSpacing > 0
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header,
              SizedBox(height: headerBottomSpacing),
            ],
          )
        : header;
    return SliverMainAxisGroup(
      slivers: <Widget>[
        if (before.isNotEmpty)
          _AppPinnedHeaderClip(
            headerKey: headerKey,
            side: _AppPinnedHeaderClipSide.before,
            child: SliverMainAxisGroup(slivers: before),
          ),
        AppPinnedListHeader(key: headerKey, child: pinnedHeader),
        if (after.isNotEmpty)
          _AppPinnedHeaderClip(
            headerKey: headerKey,
            side: _AppPinnedHeaderClipSide.after,
            child: SliverMainAxisGroup(slivers: after),
          ),
      ],
    );
  }
}

enum _AppPinnedHeaderClipSide { before, after }

class _AppPinnedHeaderClip extends SingleChildRenderObjectWidget {
  const _AppPinnedHeaderClip({
    required this.headerKey,
    required this.side,
    required super.child,
  });

  final GlobalKey headerKey;
  final _AppPinnedHeaderClipSide side;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderAppPinnedHeaderClip(headerKey, side);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAppPinnedHeaderClip renderObject,
  ) {
    renderObject
      ..headerKey = headerKey
      ..side = side;
  }
}

class _RenderAppPinnedHeaderClip extends RenderProxySliver {
  _RenderAppPinnedHeaderClip(this._headerKey, this._side);

  GlobalKey get headerKey => _headerKey;
  GlobalKey _headerKey;
  set headerKey(GlobalKey value) {
    if (identical(_headerKey, value)) {
      return;
    }
    _headerKey = value;
    markNeedsPaint();
  }

  _AppPinnedHeaderClipSide get side => _side;
  _AppPinnedHeaderClipSide _side;
  set side(_AppPinnedHeaderClipSide value) {
    if (_side == value) {
      return;
    }
    _side = value;
    markNeedsPaint();
  }

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  Rect? _resolveClip() {
    if (constraints.axis != Axis.vertical) {
      return null;
    }
    final header = headerKey.currentContext?.findRenderObject();
    if (header is! RenderSliverSingleBoxAdapter) {
      return null;
    }
    final headerBox = header.child;
    if (headerBox == null || !headerBox.attached || !headerBox.hasSize) {
      return null;
    }
    final headerTop =
        MatrixUtils.transformPoint(
          headerBox.getTransformTo(null),
          Offset.zero,
        ).dy -
        MatrixUtils.transformPoint(getTransformTo(null), Offset.zero).dy;
    final viewportHeight = constraints.viewportMainAxisExtent;
    final headerBottom = headerTop + headerBox.size.height;
    final top = side == _AppPinnedHeaderClipSide.before
        ? 0.0
        : headerBottom.clamp(0.0, viewportHeight);
    final bottom = side == _AppPinnedHeaderClipSide.before
        ? headerTop.clamp(0.0, viewportHeight)
        : viewportHeight;
    if (bottom <= top) {
      return Rect.zero;
    }
    return Rect.fromLTRB(0, top, constraints.crossAxisExtent, bottom);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || !geometry!.visible) {
      return;
    }
    final clip = _resolveClip();
    if (clip == null) {
      super.paint(context, offset);
      return;
    }
    if (clip.isEmpty) {
      _clipLayer.layer = null;
      return;
    }
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      clip,
      (clipContext, clipOffset) => child.paint(clipContext, clipOffset),
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }
}
