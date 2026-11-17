import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';

@immutable
class IndexerSettingsState {
  const IndexerSettingsState({
    required this.saved,
    required this.draft,
    this.isSaving = false,
  });

  factory IndexerSettingsState.fromDto(IndexerSettingsDto value) {
    return IndexerSettingsState(saved: value, draft: value);
  }

  final IndexerSettingsDto saved;
  final IndexerSettingsDto draft;
  final bool isSaving;

  bool get isDirty =>
      !listEquals(saved.indexers, draft.indexers);

  IndexerSettingsState copyWith({
    IndexerSettingsDto? draft,
    bool? isSaving,
  }) {
    return IndexerSettingsState(
      saved: saved,
      draft: draft ?? this.draft,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
