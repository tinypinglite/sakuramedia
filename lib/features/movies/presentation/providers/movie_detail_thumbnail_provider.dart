import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';

part 'movie_detail_thumbnail_provider.g.dart';

const int _defaultIntervalSeconds = 10;

@immutable
class MovieDetailThumbnailState {
  const MovieDetailThumbnailState({
    this.allThumbnails = const <MovieMediaThumbnailDto>[],
    this.thumbnails = const <MovieMediaThumbnailDto>[],
    this.isLoading = false,
    this.hasLoaded = false,
    this.columns,
    this.hasManualColumnOverride = false,
    this.activeIndex,
    this.errorMessage,
    this.selectedIntervalSeconds = _defaultIntervalSeconds,
    this.clipSelectionMode = false,
    this.clipStartIndex,
    this.clipEndIndex,
  });

  static const MovieDetailThumbnailState initial = MovieDetailThumbnailState();

  final List<MovieMediaThumbnailDto> allThumbnails;
  final List<MovieMediaThumbnailDto> thumbnails;
  final bool isLoading;
  final bool hasLoaded;
  final int? columns;
  final bool hasManualColumnOverride;
  final int? activeIndex;
  final String? errorMessage;
  final int selectedIntervalSeconds;
  final bool clipSelectionMode;
  final int? clipStartIndex;
  final int? clipEndIndex;

  bool get usesAutoColumns => !hasManualColumnOverride;

  MovieMediaThumbnailDto? get clipStartThumbnail => _thumbnailAt(clipStartIndex);
  MovieMediaThumbnailDto? get clipEndThumbnail => _thumbnailAt(clipEndIndex);

  bool get canCreateClip {
    final start = clipStartIndex;
    final end = clipEndIndex;
    return start != null && end != null && start != end;
  }

  int? get clipSelectionDurationSeconds {
    final start = clipStartThumbnail;
    final end = clipEndThumbnail;
    if (start == null || end == null) return null;
    return (end.offsetSeconds - start.offsetSeconds).abs();
  }

  MovieMediaThumbnailDto? _thumbnailAt(int? index) {
    if (index == null || index < 0 || index >= thumbnails.length) return null;
    return thumbnails[index];
  }

  MovieDetailThumbnailState copyWith({
    List<MovieMediaThumbnailDto>? allThumbnails,
    List<MovieMediaThumbnailDto>? thumbnails,
    bool? isLoading,
    bool? hasLoaded,
    Object? columns = _sentinel,
    bool? hasManualColumnOverride,
    Object? activeIndex = _sentinel,
    Object? errorMessage = _sentinel,
    int? selectedIntervalSeconds,
    bool? clipSelectionMode,
    Object? clipStartIndex = _sentinel,
    Object? clipEndIndex = _sentinel,
  }) {
    return MovieDetailThumbnailState(
      allThumbnails: allThumbnails ?? this.allThumbnails,
      thumbnails: thumbnails ?? this.thumbnails,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      columns: identical(columns, _sentinel) ? this.columns : columns as int?,
      hasManualColumnOverride:
          hasManualColumnOverride ?? this.hasManualColumnOverride,
      activeIndex: identical(activeIndex, _sentinel)
          ? this.activeIndex
          : activeIndex as int?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      selectedIntervalSeconds:
          selectedIntervalSeconds ?? this.selectedIntervalSeconds,
      clipSelectionMode: clipSelectionMode ?? this.clipSelectionMode,
      clipStartIndex: identical(clipStartIndex, _sentinel)
          ? this.clipStartIndex
          : clipStartIndex as int?,
      clipEndIndex: identical(clipEndIndex, _sentinel)
          ? this.clipEndIndex
          : clipEndIndex as int?,
    );
  }
}

const Object _sentinel = Object();

@riverpod
class MovieDetailThumbnail extends _$MovieDetailThumbnail {
  bool _isDisposed = false;
  KeepAliveLink? _cacheLink;

  @override
  MovieDetailThumbnailState build({required int? mediaId}) {
    ref.onDispose(() {
      _isDisposed = true;
      _cacheLink?.close();
      _cacheLink = null;
    });
    _cacheLink ??= ref.keepAlive();
    return MovieDetailThumbnailState.initial;
  }

  KeepAliveLink? get cacheLink => _cacheLink;

  Future<void> loadIfNeeded() async {
    if (state.hasLoaded || state.isLoading) return;
    await _load();
  }

  Future<void> retry() async {
    if (state.isLoading) return;
    await _load();
  }

  void applyAutoColumns(int columns) {
    if (_isDisposed ||
        state.hasManualColumnOverride ||
        state.columns == columns) {
      return;
    }
    state = state.copyWith(columns: columns);
  }

  void setColumns(int columns) {
    if (_isDisposed) return;
    if (state.columns == columns && state.hasManualColumnOverride) return;
    state = state.copyWith(columns: columns, hasManualColumnOverride: true);
  }

  void selectIndex(int index) {
    if (_isDisposed ||
        index < 0 ||
        index >= state.thumbnails.length ||
        state.activeIndex == index) {
      return;
    }
    state = state.copyWith(activeIndex: index);
  }

  void setIntervalSeconds(int seconds) {
    if (_isDisposed || state.selectedIntervalSeconds == seconds) return;
    final preservedThumbnailId = _selectedThumbnailId(state);
    final nextThumbnails = _filterThumbnails(
      state.allThumbnails,
      seconds,
    );
    state = state.copyWith(
      selectedIntervalSeconds: seconds,
      clipStartIndex: null,
      clipEndIndex: null,
      thumbnails: nextThumbnails,
      activeIndex: _resolveActiveIndex(
        nextThumbnails,
        preservedThumbnailId: preservedThumbnailId,
      ),
    );
  }

  void toggleClipSelectionMode() {
    if (_isDisposed) return;
    state = state.copyWith(
      clipSelectionMode: !state.clipSelectionMode,
      clipStartIndex: null,
      clipEndIndex: null,
    );
  }

  void handleClipSelectionTap(int index) {
    if (_isDisposed || index < 0 || index >= state.thumbnails.length) return;
    if (state.clipStartIndex == null) {
      state = state.copyWith(clipStartIndex: index, clipEndIndex: null);
    } else if (state.clipEndIndex == null) {
      if (index == state.clipStartIndex) return;
      state = state.copyWith(clipEndIndex: index);
    } else {
      state = state.copyWith(clipStartIndex: index, clipEndIndex: null);
    }
  }

  void clearClipSelection() {
    if (_isDisposed ||
        (state.clipStartIndex == null && state.clipEndIndex == null)) {
      return;
    }
    state = state.copyWith(clipStartIndex: null, clipEndIndex: null);
  }

  Future<void> _load() async {
    if (_isDisposed) return;
    if (mediaId == null) {
      state = state.copyWith(
        allThumbnails: const <MovieMediaThumbnailDto>[],
        thumbnails: const <MovieMediaThumbnailDto>[],
        errorMessage: null,
        activeIndex: null,
        hasLoaded: true,
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final all = await ref
          .read(moviesApiProvider)
          .getMediaThumbnails(mediaId: mediaId!);
      if (_isDisposed) return;
      final filtered = _filterThumbnails(all, state.selectedIntervalSeconds);
      state = state.copyWith(
        allThumbnails: all,
        thumbnails: filtered,
        activeIndex:
            _resolveActiveIndex(filtered, preservedThumbnailId: null),
        errorMessage: null,
      );
    } catch (_) {
      if (_isDisposed) return;
      state = state.copyWith(
        allThumbnails: const <MovieMediaThumbnailDto>[],
        thumbnails: const <MovieMediaThumbnailDto>[],
        errorMessage: '请稍后重试。',
        activeIndex: null,
      );
    } finally {
      if (!_isDisposed) {
        state = state.copyWith(isLoading: false, hasLoaded: true);
      }
    }
  }

  int? _resolveActiveIndex(
    List<MovieMediaThumbnailDto> thumbnails, {
    required int? preservedThumbnailId,
  }) {
    if (thumbnails.isEmpty) return null;
    if (preservedThumbnailId != null) {
      final index = thumbnails.indexWhere(
        (t) => t.thumbnailId == preservedThumbnailId,
      );
      if (index >= 0) return index;
    }
    return 0;
  }

  int? _selectedThumbnailId(MovieDetailThumbnailState current) {
    final active = current.activeIndex;
    if (active == null || active < 0 || active >= current.thumbnails.length) {
      return null;
    }
    return current.thumbnails[active].thumbnailId;
  }

  List<MovieMediaThumbnailDto> _filterThumbnails(
    List<MovieMediaThumbnailDto> thumbnails,
    int selectedIntervalSeconds,
  ) {
    if (thumbnails.length < 2) return thumbnails;
    final stepSeconds = _resolveSourceFrameStepSeconds(thumbnails);
    final stride = math.max(1, selectedIntervalSeconds ~/ stepSeconds);
    if (stride <= 1) return thumbnails;

    return List<MovieMediaThumbnailDto>.generate(
      (thumbnails.length / stride).ceil(),
      (index) => thumbnails[index * stride],
      growable: false,
    );
  }

  int _resolveSourceFrameStepSeconds(List<MovieMediaThumbnailDto> thumbnails) {
    if (thumbnails.length < 2) return _defaultIntervalSeconds;
    final offsets = thumbnails
        .map((t) => t.offsetSeconds)
        .toList(growable: false)
      ..sort();
    int? minPositiveDiff;
    for (var i = 1; i < offsets.length; i++) {
      final diff = offsets[i] - offsets[i - 1];
      if (diff <= 0) continue;
      minPositiveDiff =
          minPositiveDiff == null ? diff : math.min(minPositiveDiff, diff);
    }
    return minPositiveDiff ?? _defaultIntervalSeconds;
  }
}
