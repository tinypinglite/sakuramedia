import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';

enum MovieDetailMagnetIndexerKind { all, pt, bt }

extension MovieDetailMagnetIndexerKindValue on MovieDetailMagnetIndexerKind {
  String get label => switch (this) {
    MovieDetailMagnetIndexerKind.all => '全部',
    MovieDetailMagnetIndexerKind.pt => 'PT',
    MovieDetailMagnetIndexerKind.bt => 'BT',
  };

  String? get apiValue => switch (this) {
    MovieDetailMagnetIndexerKind.all => null,
    MovieDetailMagnetIndexerKind.pt => 'pt',
    MovieDetailMagnetIndexerKind.bt => 'bt',
  };
}

class MovieDetailMagnetController extends ChangeNotifier {
  MovieDetailMagnetController({
    required this.movieNumber,
    required this.searchCandidates,
    required this.createDownloadRequest,
  });

  final String movieNumber;
  final Future<List<DownloadCandidateDto>> Function({
    required String movieNumber,
    String? indexerKind,
  })
  searchCandidates;
  final Future<DownloadRequestResponseDto> Function({
    required String movieNumber,
    required int clientId,
    required DownloadCandidateDto candidate,
  })
  createDownloadRequest;

  MovieDetailMagnetIndexerKind _selectedIndexerKind =
      MovieDetailMagnetIndexerKind.all;
  List<DownloadCandidateDto> _items = const <DownloadCandidateDto>[];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  String? _submittingCandidateKey;

  MovieDetailMagnetIndexerKind get selectedIndexerKind => _selectedIndexerKind;
  List<DownloadCandidateDto> get items => _items;
  bool get isLoading => _isLoading;
  bool get hasSearched => _hasSearched;
  String? get errorMessage => _errorMessage;
  String? get submittingCandidateKey => _submittingCandidateKey;

  void setIndexerKind(MovieDetailMagnetIndexerKind kind) {
    if (_selectedIndexerKind == kind) {
      return;
    }
    _selectedIndexerKind = kind;
    _items = const <DownloadCandidateDto>[];
    _errorMessage = null;
    _hasSearched = false;
    notifyListeners();
  }

  Future<void> search() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _hasSearched = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await searchCandidates(
        movieNumber: movieNumber,
        indexerKind: _selectedIndexerKind.apiValue,
      );
      _errorMessage = null;
    } catch (_) {
      _items = const <DownloadCandidateDto>[];
      _errorMessage = '搜索资源失败，请稍后重试。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DownloadRequestResponseDto> submitCandidate(
    DownloadCandidateDto candidate,
  ) async {
    if (_submittingCandidateKey != null) {
      throw StateError('download request already running');
    }

    _submittingCandidateKey = candidate.submitKey;
    notifyListeners();

    try {
      return await createDownloadRequest(
        movieNumber: movieNumber,
        clientId: candidate.resolvedClientId,
        candidate: candidate,
      );
    } finally {
      _submittingCandidateKey = null;
      notifyListeners();
    }
  }
}
