import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/media/app_image_fullscreen.dart';

enum AppImageActionType {
  searchSimilar,
  saveToLocal,
  toggleMark,
  play,
  movieDetail,
}

enum AppImageActionMenuPresentation { popup, bottomDrawer }

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
  AppImageActionMenuPresentation presentation =
      AppImageActionMenuPresentation.popup,
}) {
  final visibleActions =
      actions.where((action) => action.visible).toList()..sort(
        (left, right) =>
            _actionOrder(left.type).compareTo(_actionOrder(right.type)),
      );
  if (visibleActions.isEmpty) {
    return Future<AppImageActionType?>.value(null);
  }

  return switch (presentation) {
    AppImageActionMenuPresentation.popup => _showPopupImageActionMenu(
      context: context,
      actions: visibleActions,
      globalPosition: globalPosition,
    ),
    AppImageActionMenuPresentation.bottomDrawer => _showBottomImageActionMenu(
      context: context,
      actions: visibleActions,
    ),
  };
}

Future<AppImageActionType?> _showPopupImageActionMenu({
  required BuildContext context,
  required List<AppImageActionDescriptor> actions,
  required Offset? globalPosition,
}) {
  if (globalPosition == null) {
    return Future<AppImageActionType?>.value(null);
  }

  final componentTokens = Theme.of(context).appComponentTokens;

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
    items: actions
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
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ).copyWith(
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

Future<AppImageActionType?> _showBottomImageActionMenu({
  required BuildContext context,
  required List<AppImageActionDescriptor> actions,
}) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  final estimatedHeight = 72 + actions.length * 52;
  final heightFactor = (estimatedHeight / screenHeight).clamp(0.24, 0.72);
  final inlineFullscreenDrawer =
      AppImageFullscreenHost.showBottomDrawer<AppImageActionType>(
        context: context,
        drawerKey: const Key('app-image-action-bottom-drawer'),
        heightFactor: heightFactor,
        ignoreTopSafeArea: true,
        builder:
            (drawerContext, close) => _AppImageActionBottomDrawerContent(
              actions: actions,
              onSelected: close,
            ),
      );
  if (inlineFullscreenDrawer != null) {
    return inlineFullscreenDrawer;
  }

  return showAppBottomDrawer<AppImageActionType>(
    context: context,
    drawerKey: const Key('app-image-action-bottom-drawer'),
    heightFactor: heightFactor,
    ignoreTopSafeArea: true,
    builder:
        (drawerContext) => _AppImageActionBottomDrawerContent(
          actions: actions,
          onSelected: (action) => Navigator.of(drawerContext).pop(action),
        ),
  );
}

class _AppImageActionBottomDrawerContent extends StatelessWidget {
  const _AppImageActionBottomDrawerContent({
    required this.actions,
    required this.onSelected,
  });

  final List<AppImageActionDescriptor> actions;
  final ValueChanged<AppImageActionType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: actions.length,
      separatorBuilder:
          (context, index) =>
              Divider(height: 1, color: context.appColors.borderSubtle),
      itemBuilder: (context, index) {
        final action = actions[index];
        final color = _resolveActionColor(context, action);
        return ListTile(
          key: Key('app-image-action-bottom-drawer-action-${action.type.name}'),
          enabled: action.enabled,
          leading: Icon(action.icon, color: color),
          title: Text(
            action.label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ).copyWith(color: color),
          ),
          onTap: action.enabled ? () => onSelected(action.type) : null,
        );
      },
    );
  }
}

Color? _resolveActionColor(
  BuildContext context,
  AppImageActionDescriptor action,
) {
  if (!action.enabled) {
    return Colors.grey.shade400;
  }
  if (action.destructive) {
    return Colors.red.shade600;
  }
  return null;
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
