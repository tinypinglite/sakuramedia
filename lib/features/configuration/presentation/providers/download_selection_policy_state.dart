import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_selection_policy_dto.dart';

@immutable
class DownloadSelectionPolicyState {
  const DownloadSelectionPolicyState({
    required this.saved,
    required this.draft,
    this.isSaving = false,
    this.hasVersionConflict = false,
    this.preview,
    this.isPreviewing = false,
    this.previewError,
    this.previewMovieNumber,
  });

  factory DownloadSelectionPolicyState.fromPolicy(
    DownloadSelectionPolicyDto policy,
  ) {
    return DownloadSelectionPolicyState(saved: policy, draft: policy.rules);
  }

  final DownloadSelectionPolicyDto saved;
  final DownloadSelectionRulesDto draft;
  final bool isSaving;
  final bool hasVersionConflict;
  final DownloadSelectionPreviewDto? preview;
  final bool isPreviewing;
  final String? previewError;
  final String? previewMovieNumber;

  bool get isDirty =>
      saved.rules.semanticFingerprint != draft.semanticFingerprint;

  DownloadSelectionPolicyState copyWith({
    DownloadSelectionPolicyDto? saved,
    DownloadSelectionRulesDto? draft,
    bool? isSaving,
    bool? hasVersionConflict,
    Object? preview = _sentinel,
    bool? isPreviewing,
    Object? previewError = _sentinel,
    Object? previewMovieNumber = _sentinel,
  }) {
    return DownloadSelectionPolicyState(
      saved: saved ?? this.saved,
      draft: draft ?? this.draft,
      isSaving: isSaving ?? this.isSaving,
      hasVersionConflict: hasVersionConflict ?? this.hasVersionConflict,
      preview: identical(preview, _sentinel)
          ? this.preview
          : preview as DownloadSelectionPreviewDto?,
      isPreviewing: isPreviewing ?? this.isPreviewing,
      previewError: identical(previewError, _sentinel)
          ? this.previewError
          : previewError as String?,
      previewMovieNumber: identical(previewMovieNumber, _sentinel)
          ? this.previewMovieNumber
          : previewMovieNumber as String?,
    );
  }
}

const Object _sentinel = Object();
