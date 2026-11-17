import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clips/presentation/pages/shared/clips_overview_content.dart';

/// 桌面切片首页壳：桌面布局差异收在共享内容层内。
class DesktopClipsPage extends StatelessWidget {
  const DesktopClipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClipsOverviewContent(mobile: false);
  }
}
