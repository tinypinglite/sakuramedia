import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';

enum MovieDetailMagnetSortField { sizeBytes, seeders }

enum MovieDetailMagnetSortDirection { asc, desc }

extension MovieDetailMagnetSortFieldValue on MovieDetailMagnetSortField {
  String get label => switch (this) {
    MovieDetailMagnetSortField.sizeBytes => '文件大小',
    MovieDetailMagnetSortField.seeders => '做种人数',
  };
}

extension MovieDetailMagnetSortDirectionValue
    on MovieDetailMagnetSortDirection {
  bool get isAscending => this == MovieDetailMagnetSortDirection.asc;
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

  List<DownloadCandidateDto> _items = const <DownloadCandidateDto>[];
  MovieDetailMagnetSortField _selectedSortField =
      MovieDetailMagnetSortField.sizeBytes;
  MovieDetailMagnetSortDirection _selectedSortDirection =
      MovieDetailMagnetSortDirection.desc;
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  String? _submittingCandidateKey;

  List<DownloadCandidateDto> get items => _items;
  MovieDetailMagnetSortField get selectedSortField => _selectedSortField;
  MovieDetailMagnetSortDirection get selectedSortDirection =>
      _selectedSortDirection;
  List<DownloadCandidateDto> get sortedItems {
    final sorted = List<DownloadCandidateDto>.from(_items);
    sorted.sort(_compareCandidate);
    return List<DownloadCandidateDto>.unmodifiable(sorted);
  }

  bool get isLoading => _isLoading;
  bool get hasSearched => _hasSearched;
  String? get errorMessage => _errorMessage;
  String? get submittingCandidateKey => _submittingCandidateKey;

  void setSortField(MovieDetailMagnetSortField field) {
    if (_selectedSortField == field) {
      return;
    }
    _selectedSortField = field;
    notifyListeners();
  }

  void toggleSortDirection() {
    _selectedSortDirection =
        _selectedSortDirection == MovieDetailMagnetSortDirection.desc
            ? MovieDetailMagnetSortDirection.asc
            : MovieDetailMagnetSortDirection.desc;
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
      _items = await searchCandidates(movieNumber: movieNumber);
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

  int _compareCandidate(DownloadCandidateDto left, DownloadCandidateDto right) {
    final primary = switch (_selectedSortField) {
      MovieDetailMagnetSortField.sizeBytes => left.sizeBytes.compareTo(
        right.sizeBytes,
      ),
      MovieDetailMagnetSortField.seeders => left.seeders.compareTo(
        right.seeders,
      ),
    };
    final directionalPrimary =
        _selectedSortDirection.isAscending ? primary : -primary;
    if (directionalPrimary != 0) {
      return directionalPrimary;
    }
    return left.title.compareTo(right.title);
  }
}
