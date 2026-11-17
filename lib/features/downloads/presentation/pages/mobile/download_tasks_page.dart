import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/downloads/presentation/pages/desktop/download_tasks_page.dart';

/// 移动端下载任务入口。
///
/// 列表、筛选、多选和轮询由跨端的 [DesktopDownloadTasksPage] 内容层承载；
/// 移动路由只提供子页面壳。
class MobileDownloadTasksPage extends StatelessWidget {
  const MobileDownloadTasksPage({super.key, this.initialDownloadMovieNumber});

  /// 打开后按番号过滤，与桌面入口 `downloadMovieNumber` 对称。
  final String? initialDownloadMovieNumber;

  @override
  Widget build(BuildContext context) => DesktopDownloadTasksPage(
    initialDownloadMovieNumber: initialDownloadMovieNumber,
  );
}
