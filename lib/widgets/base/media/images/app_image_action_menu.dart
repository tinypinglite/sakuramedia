import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';

/// 图片 / 影片媒体菜单的动作类型（跨页面共用的领域枚举）。
enum AppImageActionType {
  searchSimilar,
  saveToLocal,
  toggleMark,
  addToCollection,
  play,
  setCover,
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

/// 描述符 → 统一菜单项：过滤 [AppImageActionDescriptor.visible]、按固定顺序排序，
/// 破坏性动作统一红色，并保留稳定的测试锚点 key。渲染由 [showAppActionMenu] 负责。
List<AppMenuItem<AppImageActionType>> buildImageActionMenuItems(
  List<AppImageActionDescriptor> actions,
) {
  final visibleActions = actions.where((action) => action.visible).toList()
    ..sort(
      (left, right) =>
          _actionOrder(left.type).compareTo(_actionOrder(right.type)),
    );
  return <AppMenuItem<AppImageActionType>>[
    for (final action in visibleActions)
      AppMenuItem(
        key: Key('app-image-action-${action.type.name}'),
        value: action.type,
        label: action.label,
        icon: action.icon,
        enabled: action.enabled,
        tone: action.destructive ? AppTextTone.error : AppTextTone.primary,
      ),
  ];
}

/// 图片动作菜单的抽屉锚点，测试与全屏宿主共用。
const Key kAppImageActionMenuDrawerKey = Key('app-image-action-menu');

int _actionOrder(AppImageActionType type) {
  switch (type) {
    case AppImageActionType.searchSimilar:
      return 0;
    case AppImageActionType.saveToLocal:
      return 1;
    case AppImageActionType.toggleMark:
      return 2;
    case AppImageActionType.addToCollection:
      return 3;
    case AppImageActionType.play:
      return 4;
    case AppImageActionType.setCover:
      return 5;
    case AppImageActionType.movieDetail:
      return 6;
  }
}
