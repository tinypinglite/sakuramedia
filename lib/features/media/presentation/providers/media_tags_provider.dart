import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_api_provider.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_tags_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'media_tags_provider.g.dart';

@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class MediaTags extends _$MediaTags
    with AsyncNotifierDisposeGuardMixin<List<MediaTagDto>> {
  @override
  Future<List<MediaTagDto>> build() async {
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    return ref.read(mediaTagsApiProvider).getTags();
  }

  Future<void> reload() async {
    state = const AsyncLoading<List<MediaTagDto>>();
    final next = await AsyncValue.guard(
      () => ref.read(mediaTagsApiProvider).getTags(),
    );
    if (!isDisposed) state = next;
  }

  Future<String?> refresh() async {
    final current = state.value;
    if (current == null) {
      await reload();
      return state.hasError
          ? ref.apiErrorMessage(
              state.error!,
              fallback: ref
                  .read(appLocalizationsProvider)
                  .errorMediaTagsLoadFailed,
            )
          : null;
    }
    try {
      final next = await ref.read(mediaTagsApiProvider).getTags();
      if (!isDisposed) state = AsyncData(next);
      return null;
    } catch (error) {
      return ref.apiErrorMessage(
        error,
        fallback: ref.read(appLocalizationsProvider).errorMediaTagsLoadFailed,
      );
    }
  }

  Future<MediaTagDto> create(MediaTagUpsertPayload payload) async {
    final created = await ref.read(mediaTagsApiProvider).createTag(payload);
    upsert(created);
    return created;
  }

  Future<MediaTagDto> updateTag({
    required int tagId,
    required MediaTagUpsertPayload payload,
  }) async {
    final updated = await ref
        .read(mediaTagsApiProvider)
        .updateTag(tagId: tagId, payload: payload);
    upsert(updated);
    return updated;
  }

  Future<void> delete(int tagId) async {
    await ref.read(mediaTagsApiProvider).deleteTag(tagId);
    if (isDisposed) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.where((tag) => tag.id != tagId).toList(growable: false),
    );
  }

  Future<void> triggerRetag() async {
    await ref.read(activityApiProvider).triggerJob(taskKey: 'media_tag_retag');
  }

  void upsert(MediaTagDto tag) {
    if (isDisposed) return;
    final current = state.value;
    if (current == null) {
      // 列表还没加载成功（错误态）时无法就地合并；改为重新拉取，
      // 否则新建/编辑的结果会被静默丢弃，用户看不到自己刚存的规则。
      unawaited(reload());
      return;
    }
    final index = current.indexWhere((item) => item.id == tag.id);
    final next = List<MediaTagDto>.from(current);
    if (index < 0) {
      next.add(tag);
    } else {
      next[index] = tag;
    }
    next.sort((a, b) {
      final byCount = b.mediaCount.compareTo(a.mediaCount);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
    state = AsyncData(List<MediaTagDto>.unmodifiable(next));
  }
}
