import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/decor/app_ambient_backdrop.dart';

/// 移动端玻璃页的环境光背景。
class AppMobileAmbientBackdrop extends StatelessWidget {
  const AppMobileAmbientBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppAmbientBackdrop(mobile: true, child: child);
  }
}
