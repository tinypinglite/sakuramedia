import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_selection_policy_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_selection_policy_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_selection_policy_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'download_selection_policy_provider.g.dart';

@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class DownloadSelectionPolicy extends _$DownloadSelectionPolicy
    with AsyncNotifierDisposeGuardMixin<DownloadSelectionPolicyState> {
  int _previewGeneration = 0;

  static const versionConflictCode =
      'download_selection_policy_version_conflict';

  @override
  Future<DownloadSelectionPolicyState> build() async {
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    final policy = await ref
        .read(downloadSelectionPolicyApiProvider)
        .getPolicy();
    return DownloadSelectionPolicyState.fromPolicy(policy);
  }

  Future<void> reload() async {
    _previewGeneration++;
    state = const AsyncLoading<DownloadSelectionPolicyState>();
    final next = await AsyncValue.guard(() async {
      final policy = await ref
          .read(downloadSelectionPolicyApiProvider)
          .getPolicy();
      return DownloadSelectionPolicyState.fromPolicy(policy);
    });
    if (!isDisposed) state = next;
  }

  void updateDraft(DownloadSelectionRulesDto rules) {
    final current = state.value;
    if (current == null || current.isSaving) return;
    if (current.draft.semanticFingerprint == rules.semanticFingerprint) return;
    _previewGeneration++;
    state = AsyncData(
      current.copyWith(
        draft: rules,
        hasVersionConflict: false,
        preview: null,
        isPreviewing: false,
        previewError: null,
        previewMovieNumber: null,
      ),
    );
  }

  void discardDraft() {
    final current = state.value;
    if (current == null || current.isSaving) return;
    _previewGeneration++;
    state = AsyncData(
      current.copyWith(
        draft: current.saved.rules,
        hasVersionConflict: false,
        preview: null,
        isPreviewing: false,
        previewError: null,
        previewMovieNumber: null,
      ),
    );
  }

  Future<bool> save() async {
    final current = state.value;
    if (current == null || current.isSaving || !current.isDirty) return true;
    state = AsyncData(
      current.copyWith(isSaving: true, hasVersionConflict: false),
    );
    try {
      final saved = await ref
          .read(downloadSelectionPolicyApiProvider)
          .updatePolicy(
            expectedVersion: current.saved.version,
            rules: current.draft,
          );
      if (!isDisposed) {
        state = AsyncData(DownloadSelectionPolicyState.fromPolicy(saved));
      }
      return true;
    } on ApiException catch (error) {
      if (isDisposed) return false;
      final conflict = error.error?.code == versionConflictCode;
      state = AsyncData(
        current.copyWith(isSaving: false, hasVersionConflict: conflict),
      );
      if (conflict) return false;
      rethrow;
    } catch (_) {
      if (!isDisposed) {
        state = AsyncData(current.copyWith(isSaving: false));
      }
      rethrow;
    }
  }

  void clearPreview() {
    final current = state.value;
    if (current == null) return;
    if (current.preview == null &&
        current.previewError == null &&
        current.previewMovieNumber == null &&
        !current.isPreviewing) {
      return;
    }
    _previewGeneration++;
    state = AsyncData(
      current.copyWith(
        preview: null,
        isPreviewing: false,
        previewError: null,
        previewMovieNumber: null,
      ),
    );
  }

  Future<void> preview(String movieNumber, {String? inputMovieNumber}) async {
    final current = state.value;
    final normalized = movieNumber.trim();
    final input = (inputMovieNumber ?? movieNumber).trim();
    if (current == null || normalized.isEmpty || current.isPreviewing) return;
    final generation = ++_previewGeneration;
    state = AsyncData(
      current.copyWith(
        preview: null,
        isPreviewing: true,
        previewError: null,
        previewMovieNumber: input,
      ),
    );
    try {
      final result = await ref
          .read(downloadSelectionPolicyApiProvider)
          .preview(movieNumber: normalized, rules: current.draft);
      if (isDisposed || generation != _previewGeneration) return;
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          preview: result,
          isPreviewing: false,
          previewError: null,
        ),
      );
    } catch (error) {
      if (isDisposed || generation != _previewGeneration) return;
      final latest = state.value;
      if (latest == null) return;
      state = AsyncData(
        latest.copyWith(
          isPreviewing: false,
          previewError: apiErrorMessage(
            error,
            fallback: ref
                .read(appLocalizationsProvider)
                .downloadSelectionPreviewFailed,
            l10n: ref.read(appLocalizationsProvider),
          ),
        ),
      );
    }
  }
}
