import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 卡片右键 / 长按上下文菜单的一项。
class AppCardContextMenuItem<T> {
  const AppCardContextMenuItem({
    required this.value,
    required this.label,
    this.tone,
  });

  final T value;
  final String label;
  final AppTextTone? tone;
}

/// 从卡片的 `onSecondaryTapDown` / `onLongPressStart` 全局坐标弹出上下文菜单。
///
/// 内部封装:
///   - 从 root overlay 反解 globalPosition → RelativeRect;
///   - `showMenu(useRootNavigator: false, items: PopupMenuItem(Text s14 [+ tone]))`。
///
/// 调用方保留自己的 action enum、items 组装(含"回调为 null 则不加此项")、
/// 派发 switch。手势外壳(onSecondaryTapDown / onLongPressStart)仍在调用方。
Future<T?> showAppCardContextMenu<T>(
  BuildContext context, {
  required Offset globalPosition,
  required List<AppCardContextMenuItem<T>> items,
}) async {
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay!.context.findRenderObject() as RenderBox;
  final localPosition = overlay.globalToLocal(globalPosition);
  final position = RelativeRect.fromRect(
    Rect.fromPoints(localPosition, localPosition),
    Offset.zero & overlay.size,
  );
  return showMenu<T>(
    context: context,
    position: position,
    useRootNavigator: false,
    items: [
      for (final item in items)
        PopupMenuItem<T>(
          value: item.value,
          child: Text(
            item.label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              tone: item.tone ?? AppTextTone.primary,
            ),
          ),
        ),
    ],
  );
}
