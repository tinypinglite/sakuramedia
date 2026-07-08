import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/missav_thumbnail_result_dto.dart';
import 'package:sakuramedia/features/movies/data/missav_thumbnail_stream_update.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_stream_status.dart';

enum MovieDetailMissavThumbnailState { idle, loading, success, empty, error }

class MovieDetailMissavThumbnailController extends ChangeNotifier {
  static const int defaultIntervalSeconds = 10;
  static const int _sourceFrameStepSeconds = 2;

  MovieDetailMissavThumbnailController({
    required this.movieNumber,
    required this.fetchMissavThumbnailsStream,
  });

  final String movieNumber;
  final Stream<MissavThumbnailStreamUpdate> Function({
    required String movieNumber,
    bool refresh,
  })
  fetchMissavThumbnailsStream;

  List<MissavThumbnailItemDto> _allItems = const <MissavThumbnailItemDto>[];
  MovieDetailMissavThumbnailState _state = MovieDetailMissavThumbnailState.idle;
  List<MissavThumbnailItemDto> _items = const <MissavThumbnailItemDto>[];
  CatalogSearchStreamStatus? _status;
  String? _errorMessage;
  int? _columns;
  bool _hasManualColumnOverride = false;
  int? _activeIndex;
  int _selectedIntervalSeconds = defaultIntervalSeconds;
  StreamSubscription<MissavThumbnailStreamUpdate>? _subscription;
  bool _isDisposed = false;

  MovieDetailMissavThumbnailState get state => _state;
  bool get isLoading => _state == MovieDetailMissavThumbnailState.loading;
  List<MissavThumbnailItemDto> get items => _items;
  CatalogSearchStreamStatus? get status => _status;
  String? get errorMessage => _errorMessage;
  bool get usesAutoColumns => !_hasManualColumnOverride;
  int? get columns => _columns;
  int? get activeIndex => _activeIndex;
  int get selectedIntervalSeconds => _selectedIntervalSeconds;

  Future<void> load() async {
    if (isLoading) {
      return;
    }

    await _subscription?.cancel();
    _subscription = null;
    _state = MovieDetailMissavThumbnailState.loading;
    _allItems = const <MissavThumbnailItemDto>[];
    _items = const <MissavThumbnailItemDto>[];
    _errorMessage = null;
    _activeIndex = null;
    _status = const CatalogSearchStreamStatus(
      message: '正在获取 MissAV 缩略图',
      isRunning: true,
      isFailure: false,
    );
    notifyListeners();

    final completer = Completer<void>();
    final subscription = fetchMissavThumbnailsStream(
      movieNumber: movieNumber,
    ).listen(
      (update) {
        _applyUpdate(update);
        if (update.isComplete && !completer.isCompleted) {
          completer.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _state = MovieDetailMissavThumbnailState.error;
        _allItems = const <MissavThumbnailItemDto>[];
        _items = const <MissavThumbnailItemDto>[];
        _activeIndex = null;
        _errorMessage = apiErrorMessage(
          error,
          fallback: 'MissAV 缩略图获取失败，请稍后重试。',
        );
        _status = CatalogSearchStreamStatus(
          message: _errorMessage!,
          isRunning: false,
          isFailure: true,
        );
        _notifySafely();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onDone: () {
        if (_state == MovieDetailMissavThumbnailState.loading) {
          _state = MovieDetailMissavThumbnailState.error;
          _allItems = const <MissavThumbnailItemDto>[];
          _items = const <MissavThumbnailItemDto>[];
          _activeIndex = null;
          _errorMessage = 'MissAV 缩略图流已中断，请稍后重试。';
          _status = const CatalogSearchStreamStatus(
            message: 'MissAV 缩略图流已中断，请稍后重试。',
            isRunning: false,
            isFailure: true,
          );
          _notifySafely();
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      cancelOnError: false,
    );

    _subscription = subscription;
    await completer.future;
    if (identical(_subscription, subscription)) {
      _subscription = null;
    }
  }

  void applyAutoColumns(int columns) {
    if (_hasManualColumnOverride || _columns == columns) {
      return;
    }
    _columns = columns;
    notifyListeners();
  }

  void setColumns(int columns) {
    _hasManualColumnOverride = true;
    if (_columns == columns) {
      return;
    }
    _columns = columns;
    notifyListeners();
  }

  void selectIndex(int index) {
    if (index < 0 || index >= _items.length || _activeIndex == index) {
      return;
    }
    _activeIndex = index;
    notifyListeners();
  }

  void setIntervalSeconds(int seconds) {
    if (_selectedIntervalSeconds == seconds) {
      return;
    }
    final preservedItemIndex = _selectedItemIndex;
    _selectedIntervalSeconds = seconds;
    _rebuildFilteredItems(preservedItemIndex: preservedItemIndex);
    notifyListeners();
  }

  void _applyUpdate(MissavThumbnailStreamUpdate update) {
    final isFailure = update.isComplete && update.success == false;
    _status = CatalogSearchStreamStatus(
      message: update.message,
      isRunning: !update.isComplete,
      isFailure: isFailure,
      current: update.current,
      total: update.total,
    );

    if (update.isComplete) {
      if (update.success == true) {
        final nextItems =
            update.result?.items ?? const <MissavThumbnailItemDto>[];
        _allItems = nextItems;
        _rebuildFilteredItems();
        _errorMessage = null;
        _state =
            _items.isEmpty
                ? MovieDetailMissavThumbnailState.empty
                : MovieDetailMissavThumbnailState.success;
      } else {
        _allItems = const <MissavThumbnailItemDto>[];
        _items = const <MissavThumbnailItemDto>[];
        _activeIndex = null;
        _errorMessage = _resolveCompletedError(update);
        _state = MovieDetailMissavThumbnailState.error;
        _status = CatalogSearchStreamStatus(
          message: _errorMessage!,
          isRunning: false,
          isFailure: true,
          current: update.current,
          total: update.total,
        );
      }
    }

    _notifySafely();
  }

  int? get _selectedItemIndex {
    final activeIndex = _activeIndex;
    if (activeIndex == null ||
        activeIndex < 0 ||
        activeIndex >= _items.length) {
      return null;
    }
    return _items[activeIndex].index;
  }

  void _rebuildFilteredItems({int? preservedItemIndex}) {
    _items = _filterItems(_allItems);
    if (_items.isEmpty) {
      _activeIndex = null;
      return;
    }

    if (preservedItemIndex != null) {
      final preservedIndex = _items.indexWhere(
        (item) => item.index == preservedItemIndex,
      );
      if (preservedIndex >= 0) {
        _activeIndex = preservedIndex;
        return;
      }
    }

    _activeIndex = 0;
  }

  List<MissavThumbnailItemDto> _filterItems(
    List<MissavThumbnailItemDto> items,
  ) {
    if (items.length < 2) {
      return items;
    }

    final stride = math.max(
      1,
      _selectedIntervalSeconds ~/ _sourceFrameStepSeconds,
    );
    if (stride <= 1) {
      return items;
    }

    return List<MissavThumbnailItemDto>.generate(
      (items.length / stride).ceil(),
      (index) => items[index * stride],
      growable: false,
    );
  }

  String _resolveCompletedError(MissavThumbnailStreamUpdate update) {
    if (update.detail != null && update.detail!.trim().isNotEmpty) {
      return update.detail!;
    }
    switch (update.reason) {
      case 'missav_thumbnail_not_found':
        return 'MissAV 未找到可用缩略图。';
      case 'missav_thumbnail_fetch_failed':
        return 'MissAV 缩略图获取失败，请稍后重试。';
      default:
        return 'MissAV 缩略图获取失败，请稍后重试。';
    }
  }

  void _notifySafely() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
