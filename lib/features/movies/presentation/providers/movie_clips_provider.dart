import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clip_mutation_events_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';

part 'movie_clips_provider.g.dart';

/// 影片详情页「切片」区块状态。迁移前对应
/// `MovieClipsController extends ChangeNotifier`（挂 clip mutation 广播）。
@immutable
class MovieClipsState {
  const MovieClipsState({
    this.clips = const <MediaClipDto>[],
    this.isLoading = false,
    this.errorMessage,
  });

  static const MovieClipsState initial = MovieClipsState();

  final List<MediaClipDto> clips;
  final bool isLoading;
  final String? errorMessage;

  MovieClipsState copyWith({
    List<MediaClipDto>? clips,
    bool? isLoading,
    Object? errorMessage = _sentinel,
  }) {
    return MovieClipsState(
      clips: clips ?? this.clips,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _sentinel = Object();

@riverpod
class MovieClips extends _$MovieClips {
  static const int _limit = 30;

  bool _isDisposed = false;
  KeepAliveLink? _cacheLink;

  @override
  MovieClipsState build(String movieNumber) {
    ref.onDispose(() {
      _isDisposed = true;
      _cacheLink?.close();
      _cacheLink = null;
    });
    _cacheLink ??= ref.keepAlive();

    // 监听切片广播：外部删除切片时就地移除。
    ref.listen(clipMutationEventsProvider, (_, next) {
      final change = next.value;
      if (change == null) return;
      if (change.kind == ClipMutationKind.deleted && change.clipId != null) {
        removeClip(change.clipId!);
      }
    });

    return MovieClipsState.initial;
  }

  KeepAliveLink? get cacheLink => _cacheLink;

  Future<void> load() async {
    if (_isDisposed) return;
    // 番号缺失无从过滤，直接落空态。
    if (movieNumber.trim().isEmpty) {
      state = state.copyWith(
        clips: const <MediaClipDto>[],
        isLoading: false,
        errorMessage: null,
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final clips = await ref
          .read(clipsApiProvider)
          .getClipsByMovieNumber(movieNumber: movieNumber, limit: _limit);
      if (_isDisposed) return;
      state = state.copyWith(clips: clips, errorMessage: null);
    } catch (_) {
      if (_isDisposed) return;
      state = state.copyWith(
        errorMessage: ref.read(appLocalizationsProvider).errorClipLoadFailed,
      );
    } finally {
      if (!_isDisposed) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> retry() => load();

  /// 重命名后用更新项就地替换同 id 切片（无该 id 则忽略）。
  void replaceClip(MediaClipDto updated) {
    if (_isDisposed) return;
    final index = state.clips.indexWhere((c) => c.clipId == updated.clipId);
    if (index < 0) return;
    final next = List<MediaClipDto>.of(state.clips);
    next[index] = updated;
    state = state.copyWith(clips: List<MediaClipDto>.unmodifiable(next));
  }

  /// 从列表精准移除指定切片（删除广播 / 本地删除共用）。
  void removeClip(int clipId) {
    if (_isDisposed) return;
    final before = state.clips.length;
    final next = state.clips
        .where((c) => c.clipId != clipId)
        .toList(growable: false);
    if (next.length != before) {
      state = state.copyWith(clips: next);
    }
  }
}
