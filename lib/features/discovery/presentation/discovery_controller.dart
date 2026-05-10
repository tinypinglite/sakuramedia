import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/discovery/data/daily_recommendation_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/discovery_api.dart';
import 'package:sakuramedia/features/discovery/data/moment_recommendation_dto.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';

class DiscoveryController extends ChangeNotifier {
  DiscoveryController({
    required DiscoveryApi discoveryApi,
    this.dailyPageSize = 12,
    this.momentPageSize = 12,
  }) : _discoveryApi = discoveryApi;

  final DiscoveryApi _discoveryApi;
  final int dailyPageSize;
  final int momentPageSize;

  final List<DailyRecommendationMovieDto> _dailyItems =
      <DailyRecommendationMovieDto>[];
  final List<MomentRecommendationDto> _momentItems =
      <MomentRecommendationDto>[];

  bool _isLoadingDaily = false;
  bool _isLoadingMoments = false;
  bool _isDisposed = false;
  String? _dailyErrorMessage;
  String? _momentErrorMessage;
  int _dailyTotal = 0;
  int _momentTotal = 0;

  UnmodifiableListView<DailyRecommendationMovieDto> get dailyItems =>
      UnmodifiableListView<DailyRecommendationMovieDto>(_dailyItems);
  UnmodifiableListView<MomentRecommendationDto> get momentItems =>
      UnmodifiableListView<MomentRecommendationDto>(_momentItems);
  bool get isLoadingDaily => _isLoadingDaily;
  bool get isLoadingMoments => _isLoadingMoments;
  String? get dailyErrorMessage => _dailyErrorMessage;
  String? get momentErrorMessage => _momentErrorMessage;
  int get dailyTotal => _dailyTotal;
  int get momentTotal => _momentTotal;

  Future<void> load() async {
    await Future.wait(<Future<void>>[
      _loadDaily(clearExisting: true),
      _loadMoments(clearExisting: true),
    ]);
  }

  Future<void> refresh() async {
    await Future.wait(<Future<void>>[
      _loadDaily(clearExisting: false),
      _loadMoments(clearExisting: false),
    ]);
  }

  Future<void> _loadDaily({required bool clearExisting}) async {
    if (_isLoadingDaily) {
      return;
    }

    _isLoadingDaily = true;
    _dailyErrorMessage = null;
    if (clearExisting) {
      _dailyTotal = 0;
      _dailyItems.clear();
    }
    _notifySafely();

    try {
      final response = await _discoveryApi.getDailyRecommendations(
        page: 1,
        pageSize: dailyPageSize,
      );
      if (_isDisposed) {
        return;
      }
      _dailyItems
        ..clear()
        ..addAll(response.items);
      _dailyTotal = response.total;
      _dailyErrorMessage = null;
    } catch (_) {
      if (!_isDisposed && (clearExisting || _dailyItems.isEmpty)) {
        _dailyErrorMessage = '今日推荐加载失败，请稍后重试';
      }
    } finally {
      if (!_isDisposed) {
        _isLoadingDaily = false;
        _notifySafely();
      }
    }
  }

  Future<void> _loadMoments({required bool clearExisting}) async {
    if (_isLoadingMoments) {
      return;
    }

    _isLoadingMoments = true;
    _momentErrorMessage = null;
    if (clearExisting) {
      _momentTotal = 0;
      _momentItems.clear();
    }
    _notifySafely();

    try {
      final response = await _discoveryApi.getMomentRecommendations(
        page: 1,
        pageSize: momentPageSize,
      );
      if (_isDisposed) {
        return;
      }
      _momentItems
        ..clear()
        ..addAll(response.items);
      _momentTotal = response.total;
      _momentErrorMessage = null;
    } catch (_) {
      if (!_isDisposed && (clearExisting || _momentItems.isEmpty)) {
        _momentErrorMessage = '推荐时刻加载失败，请稍后重试';
      }
    } finally {
      if (!_isDisposed) {
        _isLoadingMoments = false;
        _notifySafely();
      }
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
    super.dispose();
  }
}

extension MomentRecommendationMomentItem on MomentRecommendationDto {
  MomentListItem toMomentListItem() {
    return MomentListItem(
      pointId: recommendationId,
      mediaId: mediaId,
      movieNumber: movie.movieNumber,
      thumbnailId: thumbnailId,
      offsetSeconds: offsetSeconds,
      createdAt: null,
      image: image,
    );
  }
}
