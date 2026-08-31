import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'media_libraries_provider.g.dart';

/// 跨桌面 configuration tab 与移动设置页共享的媒体库列表。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class MediaLibraries extends _$MediaLibraries
    with AsyncNotifierDisposeGuardMixin<List<MediaLibraryDto>> {
  @override
  Future<List<MediaLibraryDto>> build() async {
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    return ref.read(mediaLibrariesApiProvider).getLibraries();
  }

  Future<void> reload() async {
    state = const AsyncLoading<List<MediaLibraryDto>>();
    final next = await AsyncValue.guard(
      () => ref.read(mediaLibrariesApiProvider).getLibraries(),
    );
    if (!isDisposed) state = next;
  }

  /// 下拉刷新保留已呈现的列表；失败由调用方显示轻提示。
  Future<String?> refresh() async {
    final current = state.value;
    if (current == null) {
      await reload();
      return state.hasError
          ? apiErrorMessage(state.error!, fallback: '媒体库加载失败，请稍后重试。')
          : null;
    }
    try {
      final next = await ref.read(mediaLibrariesApiProvider).getLibraries();
      if (!isDisposed) state = AsyncData(next);
      return null;
    } catch (error) {
      return apiErrorMessage(error, fallback: '媒体库加载失败，请稍后重试。');
    }
  }

  Future<MediaLibraryDto> create(CreateMediaLibraryPayload payload) async {
    final created = await ref
        .read(mediaLibrariesApiProvider)
        .createLibrary(payload);
    upsert(created);
    return created;
  }

  Future<MediaLibraryDto> updateLibrary({
    required int libraryId,
    required UpdateMediaLibraryPayload payload,
  }) async {
    final updated = await ref
        .read(mediaLibrariesApiProvider)
        .updateLibrary(libraryId: libraryId, payload: payload);
    upsert(updated);
    return updated;
  }

  Future<void> delete(int libraryId) async {
    await ref.read(mediaLibrariesApiProvider).deleteLibrary(libraryId);
    if (isDisposed) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current
          .where((library) => library.id != libraryId)
          .toList(growable: false),
    );
  }

  void upsert(MediaLibraryDto library) {
    if (isDisposed) return;
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((item) => item.id == library.id);
    final next = List<MediaLibraryDto>.from(current);
    if (index < 0) {
      next.insert(0, library);
    } else {
      next[index] = library;
    }
    state = AsyncData(next);
  }
}
