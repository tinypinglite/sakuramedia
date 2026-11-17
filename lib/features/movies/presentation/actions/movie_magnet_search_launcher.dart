import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_inspector_panel.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 磁力搜索的独立入口（订阅列表等只有番号的场景）：自适应壳 + 同一个面板。
///
/// 内容、标题与 KeepAliveLink 收编都由 [MovieDetailInspectorPanel] 承担，
/// 这里只负责选壳（桌面弹窗 / 移动底部抽屉）。
Future<void> showMovieMagnetSearchDialog({
  required BuildContext context,
  required String movieNumber,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    modalKey: const Key('movie-magnet-search-dialog'),
    desktopWidth: context.appComponentTokens.movieDetailDialogWidth,
    desktopHeight: context.appComponentTokens.movieDetailDialogMinHeight,
    builder: (_) => MovieDetailInspectorPanel(
      movieNumber: movieNumber,
      selectedMedia: null,
      pane: MovieDetailInspectorPane.magnetSearch,
    ),
  );
}
