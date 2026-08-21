import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/config_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_preference_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'download_preference_provider.g.dart';

@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class DownloadPreference extends _$DownloadPreference
    with AsyncNotifierDisposeGuardMixin<DownloadPreferenceState> {
  @override
  Future<DownloadPreferenceState> build() async {
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    final resource = await ref.read(configApiProvider).get();
    final kinds = resource.downloads.preferredClientKinds;
    return DownloadPreferenceState(savedKinds: kinds, draftKinds: kinds);
  }

  void updateDraft(List<DownloadClientKind> kinds) {
    final current = state.value;
    if (current == null || current.isSaving) return;
    state = AsyncData(current.copyWith(draftKinds: List.of(kinds)));
  }

  Future<List<String>> save() async {
    final current = state.value;
    if (current == null || current.isSaving) {
      return const <String>[];
    }
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      final result = await ref.read(configApiProvider).patch(<String, dynamic>{
        'downloads': <String, dynamic>{
          'preferred_client_kinds': current.draftKinds
              .map((kind) => kind.wireValue)
              .toList(growable: false),
        },
      });
      if (!isDisposed) {
        final kinds = result.values.downloads.preferredClientKinds;
        state = AsyncData(
          DownloadPreferenceState(savedKinds: kinds, draftKinds: kinds),
        );
      }
      return result.restartRequired;
    } catch (_) {
      if (!isDisposed) state = AsyncData(current.copyWith(isSaving: false));
      rethrow;
    }
  }
}
