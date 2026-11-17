import 'package:sakuramedia/l10n/app_localizations.dart';

/// Provider-owned opaque source reference selected from the browse response.
class MediaImportSource {
  const MediaImportSource({required this.sourceRef});

  final Map<String, dynamic> sourceRef;

  Map<String, dynamic> toJson() => <String, dynamic>{'source_ref': sourceRef};
}

/// How the storage provider should handle the source after a successful import.
enum SourceDisposition { keep, deleteAfterCommit, inPlace }

extension SourceDispositionX on SourceDisposition {
  String get wireValue => switch (this) {
    SourceDisposition.keep => 'keep',
    SourceDisposition.deleteAfterCommit => 'delete_after_commit',
    SourceDisposition.inPlace => 'in_place',
  };

  /// 当前语言的处置方式名。
  String labelWith({required AppLocalizations l10n}) => switch (this) {
    SourceDisposition.keep => l10n.mediaImportDispositionKeep,
    SourceDisposition.deleteAfterCommit =>
      l10n.mediaImportDispositionDeleteAfterCommit,
    SourceDisposition.inPlace => l10n.mediaImportDispositionInPlace,
  };

  /// 当前语言的处置方式说明。
  String descriptionWith({required AppLocalizations l10n}) => switch (this) {
    SourceDisposition.keep => l10n.mediaImportDispositionKeepDescription,
    SourceDisposition.deleteAfterCommit =>
      l10n.mediaImportDispositionDeleteAfterCommitDescription,
    SourceDisposition.inPlace => l10n.mediaImportDispositionInPlaceDescription,
  };
}
