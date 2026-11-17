import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clips/presentation/pages/shared/clips_overview_content.dart';

/// 移动概览页「切片」tab 壳：移动布局差异收在共享内容层内。
class MobileOverviewClipsTab extends StatelessWidget {
  const MobileOverviewClipsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClipsOverviewContent(mobile: true);
  }
}
