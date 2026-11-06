import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/shared/clip_collections_content.dart';

/// 切片合集列表页：全部合集网格 + 新建 / 编辑 / 删除。
class DesktopClipCollectionsPage extends StatelessWidget {
  const DesktopClipCollectionsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const ClipCollectionsContent(mobile: false);
}
