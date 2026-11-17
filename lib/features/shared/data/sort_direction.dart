import 'package:sakuramedia/l10n/app_localizations.dart';

/// 通用升/降序枚举。跨 feature 共用（movies / rankings / playlists / …）。
///
/// 各域按需 re-export 或直接引用，避免下游反向依赖具体 feature 的 presentation 层。
enum SortDirection { asc, desc }

extension SortDirectionX on SortDirection {
  String get apiValue => switch (this) {
    SortDirection.asc => 'asc',
    SortDirection.desc => 'desc',
  };

  /// 排序方向的展示文案，按当前语言渲染。
  String label(AppLocalizations l10n) => switch (this) {
    SortDirection.asc => l10n.sharedSortAscending,
    SortDirection.desc => l10n.sharedSortDescending,
  };

  /// 排序入口摘要里使用的方向符号。
  String get symbol => switch (this) {
    SortDirection.asc => '↑',
    SortDirection.desc => '↓',
  };
}
