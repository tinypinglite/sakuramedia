import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

enum AppImageActionType {
  searchSimilar,
  saveToLocal,
  toggleMark,
  play,
  movieDetail,
}

class AppImageActionDescriptor {
  const AppImageActionDescriptor({
    required this.type,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.destructive = false,
    this.visible = true,
  });

  final AppImageActionType type;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool destructive;
  final bool visible;
}

Future<AppImageActionType?> showAppImageActionMenu({
  required BuildContext context,
  required List<AppImageActionDescriptor> actions,
  required Offset? globalPosition,
}) {
  final componentTokens = Theme.of(context).appComponentTokens;
  final visibleActions =
      actions.where((action) => action.visible).toList()..sort(
        (left, right) =>
            _actionOrder(left.type).compareTo(_actionOrder(right.type)),
      );
  if (visibleActions.isEmpty || globalPosition == null) {
    return Future<AppImageActionType?>.value(null);
  }

  final navigator = Navigator.of(context);
  final overlay = navigator.overlay!.context.findRenderObject() as RenderBox;
  final localPosition = overlay.globalToLocal(globalPosition);
  final position = RelativeRect.fromRect(
    Rect.fromPoints(localPosition, localPosition),
    Offset.zero & overlay.size,
  );

  return showMenu<AppImageActionType>(
    context: context,
    position: position,
    useRootNavigator: false,
    items: visibleActions
        .map(
          (action) => PopupMenuItem<AppImageActionType>(
            value: action.type,
            enabled: action.enabled,
            child: Row(
              children: [
                Icon(
                  action.icon,
                  size: componentTokens.iconSizeSm,
                  color:
                      action.enabled
                          ? (action.destructive ? Colors.red.shade600 : null)
                          : Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Text(
                  action.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        action.enabled
                            ? (action.destructive ? Colors.red.shade600 : null)
                            : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(growable: false),
  );
}

int _actionOrder(AppImageActionType type) {
  switch (type) {
    case AppImageActionType.searchSimilar:
      return 0;
    case AppImageActionType.saveToLocal:
      return 1;
    case AppImageActionType.toggleMark:
      return 2;
    case AppImageActionType.play:
      return 3;
    case AppImageActionType.movieDetail:
      return 4;
  }
}
