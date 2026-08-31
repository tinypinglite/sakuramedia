import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';

@immutable
class DownloadPreferenceState {
  const DownloadPreferenceState({
    required this.savedKinds,
    required this.draftKinds,
    this.isSaving = false,
  });

  final List<DownloadClientKind> savedKinds;
  final List<DownloadClientKind> draftKinds;
  final bool isSaving;

  bool get isDirty => !listEquals(savedKinds, draftKinds);

  DownloadPreferenceState copyWith({
    List<DownloadClientKind>? savedKinds,
    List<DownloadClientKind>? draftKinds,
    bool? isSaving,
  }) {
    return DownloadPreferenceState(
      savedKinds: savedKinds ?? this.savedKinds,
      draftKinds: draftKinds ?? this.draftKinds,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
