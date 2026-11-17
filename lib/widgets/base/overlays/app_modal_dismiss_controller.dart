import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 控制弹层是否允许被返回、遮罩、下拉手势关闭。
class AppModalDismissController extends ChangeNotifier {
  bool _locked = false;

  bool get locked => _locked;

  void setLocked(bool locked) {
    if (_locked == locked) {
      return;
    }
    _locked = locked;
    notifyListeners();
  }
}

/// 给弹层内容加返回拦截；锁定时统一提示正在提交。
///
/// 同一个 controller 的嵌套 scope 会复用最外层拦截，避免重复 toast。
class AppModalDismissScope extends StatelessWidget {
  const AppModalDismissScope({
    super.key,
    required this.controller,
    required this.child,
    this.onBlocked,
  });

  final AppModalDismissController controller;
  final Widget child;
  final VoidCallback? onBlocked;

  static AppModalDismissController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AppModalDismissAncestor>()
        ?.controller;
  }

  @override
  Widget build(BuildContext context) {
    if (identical(maybeOf(context), controller)) {
      return child;
    }
    return _AppModalDismissAncestor(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          return PopScope<void>(
            canPop: !controller.locked,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) {
                return;
              }
              final blocked = onBlocked;
              if (blocked != null) {
                blocked();
                return;
              }
              showToast(
                appL10n(context).commonSubmittingPleaseWait,
                context: context,
              );
            },
            child: child!,
          );
        },
        child: child,
      ),
    );
  }
}

class _AppModalDismissAncestor extends InheritedWidget {
  const _AppModalDismissAncestor({
    required this.controller,
    required super.child,
  });

  final AppModalDismissController controller;

  @override
  bool updateShouldNotify(_AppModalDismissAncestor oldWidget) {
    return !identical(controller, oldWidget.controller);
  }
}
