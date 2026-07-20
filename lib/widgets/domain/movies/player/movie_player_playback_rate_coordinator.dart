import 'package:flutter/foundation.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_mobile_drawers.dart';

/// 播放速率状态机（从 `_MoviePlayerSurfaceState` 抽出的引擎件）。
///
/// 语义：
/// - [currentRate] 为权威速率，[hasExplicitSelection] 记录是否曾被用户显式选择。
/// - [select] 用户选择一档：先本地乐观置值并记 pending → 调 setRate → 失败回滚。
/// - [onRateStreamEvent] 供 `player.stream.rate` 事件喂入：pending 存在且值不匹配
///   时忽略（避免旧的自然速率事件覆盖新选择），匹配后清 pending 并同步 current。
/// - [resetMobileDisplayForNewMedia] 换片时**只**把移动端速率显示复位到播放器
///   当前速率（`hasExplicitSelection: false`）；权威 `_currentRate` /
///   `_hasExplicitSelection` / `_pendingRate` 保持不动——桌面下拉沿用旧选择，
///   media_kit 会在开始播放后通过 rate 流事件把它们自然带回同步态。此行为从
///   拆分前的宿主里如实迁移过来，非本 coordinator 引入。
///
/// 状态变化经 [ChangeNotifier] 通知；宿主 State 监听后 setState。
/// 移动端底部控件通过 [mobileSpeedDisplay] 独立监听快照，无需整个 surface 重建。
class MoviePlayerPlaybackRateCoordinator extends ChangeNotifier {
  MoviePlayerPlaybackRateCoordinator({
    required Future<void> Function(double rate) setRate,
    required double initialRate,
  })  : _setRate = setRate,
        _currentRate = initialRate,
        _mobileSpeedDisplay = ValueNotifier<MoviePlayerMobileSpeedDisplayState>(
          MoviePlayerMobileSpeedDisplayState(
            rate: initialRate,
            hasExplicitSelection: false,
          ),
        );

  final Future<void> Function(double rate) _setRate;
  final ValueNotifier<MoviePlayerMobileSpeedDisplayState> _mobileSpeedDisplay;

  double _currentRate;
  bool _hasExplicitSelection = false;
  double? _pendingRate;

  double get currentRate => _currentRate;
  bool get hasExplicitSelection => _hasExplicitSelection;

  ValueListenable<MoviePlayerMobileSpeedDisplayState> get mobileSpeedDisplay =>
      _mobileSpeedDisplay;

  /// 供 `player.stream.rate` 事件喂入。
  void onRateStreamEvent(double rate) {
    debugPrint(
      '[player-debug] playback_rate_stream rate=$rate pending=$_pendingRate current=$_currentRate',
    );
    final pendingRate = _pendingRate;
    if (pendingRate != null && (pendingRate - rate).abs() >= 0.001) {
      debugPrint(
        '[player-debug] playback_rate_stream_ignored rate=$rate pending=$pendingRate',
      );
      return;
    }
    if (pendingRate != null && (pendingRate - rate).abs() < 0.001) {
      _pendingRate = null;
    }
    final display = _mobileSpeedDisplay.value;
    if ((display.rate - rate).abs() >= 0.001) {
      _mobileSpeedDisplay.value = display.copyWith(rate: rate);
    }
    if ((_currentRate - rate).abs() < 0.001) {
      return;
    }
    _currentRate = rate;
    notifyListeners();
  }

  /// 用户显式选中一档速率（桌面下拉入口）。
  Future<void> select(double rate) async {
    debugPrint(
      '[player-debug] playback_rate_selected rate=$rate current=$_currentRate explicit=$_hasExplicitSelection',
    );
    final previousRate = _currentRate;
    final previousSelection = _hasExplicitSelection;
    _pendingRate = rate;
    _currentRate = rate;
    _hasExplicitSelection = true;
    notifyListeners();
    try {
      await _setRate(rate);
      _pendingRate = null;
      debugPrint('[player-debug] playback_rate_applied requested=$rate');
    } catch (error) {
      _pendingRate = null;
      debugPrint(
        '[player-debug] playback_rate_select_error rate=$rate error=$error',
      );
      _currentRate = previousRate;
      _hasExplicitSelection = previousSelection;
      notifyListeners();
    }
  }

  /// 移动端速率抽屉选中：先乐观刷新显示（避免抽屉关闭时闪回旧值），
  /// 再走标准 [select]，最后再按最新权威状态重同步一次。
  Future<void> selectFromMobile(double rate) async {
    _mobileSpeedDisplay.value = MoviePlayerMobileSpeedDisplayState(
      rate: rate,
      hasExplicitSelection: true,
    );
    await select(rate);
    _mobileSpeedDisplay.value = MoviePlayerMobileSpeedDisplayState(
      rate: _currentRate,
      hasExplicitSelection: _hasExplicitSelection,
    );
  }

  /// 换片时把移动端速率显示复位到播放器当前速率；权威 `_currentRate` /
  /// `_hasExplicitSelection` / `_pendingRate` 由 rate 流后续自然带回同步态。
  void resetMobileDisplayForNewMedia(double newInitialRate) {
    _mobileSpeedDisplay.value = MoviePlayerMobileSpeedDisplayState(
      rate: newInitialRate,
      hasExplicitSelection: false,
    );
  }

  @override
  void dispose() {
    _mobileSpeedDisplay.dispose();
    super.dispose();
  }
}
