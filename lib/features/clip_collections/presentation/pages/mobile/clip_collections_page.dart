import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clip_collections/presentation/pages/shared/clip_collections_content.dart';

/// 移动端切片合集列表页：全部合集网格 + 新建 / 编辑 / 删除（编辑与确认走底部抽屉）。
class MobileClipCollectionsPage extends StatelessWidget {
  const MobileClipCollectionsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const ClipCollectionsContent(mobile: true);
}
