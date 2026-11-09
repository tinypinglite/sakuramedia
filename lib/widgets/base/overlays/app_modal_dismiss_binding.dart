import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';

/// 把表单页面的提交状态同步到可选的 modal dismiss controller。
mixin AppModalDismissBinding<T extends StatefulWidget> on State<T> {
  AppModalDismissController? _controller;
  bool _ownsController = false;

  AppModalDismissController? dismissControllerFor(T widget);
  bool isDismissLockedFor(T widget);

  AppModalDismissController get boundDismissController => _controller!;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      dismissControllerFor(oldWidget),
      dismissControllerFor(widget),
    )) {
      _release();
      _bind();
    } else if (isDismissLockedFor(oldWidget) != isDismissLockedFor(widget)) {
      _controller?.setLocked(isDismissLockedFor(widget));
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _bind() {
    final supplied = dismissControllerFor(widget);
    _ownsController = supplied == null;
    _controller = supplied ?? AppModalDismissController();
    _controller!.setLocked(isDismissLockedFor(widget));
  }

  void _release() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    controller.setLocked(false);
    if (_ownsController) {
      controller.dispose();
    }
    _controller = null;
  }
}
