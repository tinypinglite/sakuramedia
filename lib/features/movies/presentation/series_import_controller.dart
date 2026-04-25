import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/movie_search_stream_update.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/search/data/catalog_search_stream_stats.dart';

class SeriesImportController extends ChangeNotifier {
  SeriesImportController({required MoviesApi moviesApi})
    : _moviesApi = moviesApi;

  final MoviesApi _moviesApi;

  bool _isRunning = false;
  bool _isCompleted = false;
  bool _hasFailed = false;
  bool _hasNewMovies = false;
  String _statusMessage = '准备就绪';
  int? _current;
  int? _total;
  CatalogSearchStreamStats? _stats;
  String? _errorMessage;
  StreamSubscription<MovieSearchStreamUpdate>? _subscription;
  bool _isDisposed = false;

  bool get isRunning => _isRunning;
  bool get isCompleted => _isCompleted;
  bool get hasFailed => _hasFailed;
  bool get hasNewMovies => _hasNewMovies;
  bool get canDismiss => _isCompleted || _hasFailed;
  String get statusMessage => _statusMessage;
  int? get current => _current;
  int? get total => _total;
  CatalogSearchStreamStats? get stats => _stats;
  String? get errorMessage => _errorMessage;

  double? get progress {
    final c = _current;
    final t = _total;
    if (c == null || t == null || t == 0) {
      return null;
    }
    return (c / t).clamp(0.0, 1.0);
  }

  Future<void> startImport(int seriesId) async {
    if (_isRunning) {
      return;
    }
    _isRunning = true;
    _isCompleted = false;
    _hasFailed = false;
    _hasNewMovies = false;
    _statusMessage = '正在连接服务器...';
    _current = null;
    _total = null;
    _stats = null;
    _errorMessage = null;
    _notifySafely();

    final subscription = _moviesApi
        .importSeriesMoviesStream(seriesId: seriesId)
        .listen(
          _applyUpdate,
          onError: (Object error, StackTrace _) {
            if (_isDisposed) {
              return;
            }
            _isRunning = false;
            _hasFailed = true;
            _errorMessage = apiErrorMessage(error, fallback: '导入失败，请稍后重试');
            _notifySafely();
          },
          onDone: () {
            if (_isDisposed) {
              return;
            }
            if (_isRunning && !_isCompleted) {
              _isRunning = false;
              _hasFailed = true;
              _errorMessage = '连接意外断开，请重试';
              _notifySafely();
            }
          },
          cancelOnError: false,
        );

    _subscription = subscription;
  }

  void _applyUpdate(MovieSearchStreamUpdate update) {
    _statusMessage = update.message;
    if (update.current != null) {
      _current = update.current;
    }
    if (update.total != null) {
      _total = update.total;
    }
    if (update.stats != null) {
      _stats = update.stats;
    }

    if (update.isComplete) {
      _isRunning = false;
      _isCompleted = true;
      final s = update.stats;
      _hasNewMovies = s != null && s.createdCount > 0;
      if (update.success == false) {
        _hasFailed = true;
        _errorMessage = _resolveFailureMessage(update.reason);
      }
    }

    _notifySafely();
  }

  String _resolveFailureMessage(String? reason) {
    switch (reason) {
      case 'series_not_found':
        return '本地系列不存在';
      case 'javdb_series_not_found':
        return '未能在 JAVDB 找到匹配的系列，请确认系列名称';
      default:
        return '导入失败，请稍后重试';
    }
  }

  Future<void> cancel() async {
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
    if (_isRunning) {
      _isRunning = false;
      _notifySafely();
    }
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
