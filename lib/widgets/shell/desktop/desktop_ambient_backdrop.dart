import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/decor/app_ambient_backdrop.dart';

/// 桌面壳层的主题色环境光背景；窗口毛玻璃关闭时回退为纯页面底色。
class DesktopAmbientBackdrop extends StatelessWidget {
  const DesktopAmbientBackdrop({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppAmbientBackdrop(enabled: enabled);
  }
}
