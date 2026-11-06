import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/configuration_tab_request_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_clients_provider.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/downloads/data/download_source_link.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/series_import/movie_search_stream_update.dart';
import 'package:sakuramedia/features/movies/data/movie_number_matcher.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/file_picker_with_bytes.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collections_overview_provider.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/pick_video_collection_single_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/video_collection_picker_field.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_switch.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 手动提交成功后的返回值；`clientName` 用于页面 toast。
class ManualDownloadResult {
  const ManualDownloadResult({
    required this.response,
    required this.clientName,
  });

  final DownloadRequestResponseDto response;
  final String clientName;
}

/// 从评论等上下文打开手动下载时的预填信息。
///
/// 传入后弹窗进入紧凑模式：来源、影片和下载类型都视为已确定，只保留来源
/// 输入、影片卡片和下载器选择，不再要求用户重新查询番号。
class ManualDownloadPrefill {
  const ManualDownloadPrefill({
    required this.sourceUri,
    this.sourceKind = DownloadSourceKind.magnet,
    required this.movieNumber,
    this.movieTitle,
    this.movieCoverUrl,
  });

  final String sourceUri;
  final DownloadSourceKind sourceKind;
  final String movieNumber;
  final String? movieTitle;
  final String? movieCoverUrl;
}

/// 打开手动添加下载表单：桌面居中弹窗，移动端底部抽屉。
Future<ManualDownloadResult?> showManualDownloadDialog(
  BuildContext hostContext, {
  ManualDownloadPrefill? prefill,
}) {
  return showAppAdaptiveModal<ManualDownloadResult>(
    context: hostContext,
    modalKey: const Key('manual-download-modal'),
    desktopWidth: hostContext.appLayoutTokens.dialogWidthMd,
    mobileHeightFactor: 0.9,
    // 预填场景字段少，让抽屉按内容收缩，避免在评论弹窗上再盖一个近乎全屏的
    // 抽屉；完整表单仍保持原来的 90% 高度。
    mobileMaxHeightFactor: prefill == null ? null : 0.72,
    // 表单在请求期间不能被 X / 下拉 / 点遮罩关掉；关闭入口在内容区，由
    // _isSubmitting 控制。遮罩仍由内部 PopScope 兜底。
    enableDrag: false,
    showDrawerHandle: false,
    showDesktopCloseButton: false,
    builder: (_) =>
        _ManualDownloadDialog(hostContext: hostContext, prefill: prefill),
  );
}

enum _MovieResolutionPhase { idle, resolving, resolved, failed }

enum _MovieResolutionSource { local, online, currentMovie }

enum _ManualDownloadSourceMode { link, torrent }

typedef _ResolvedDownloadSource = ({
  _ManualDownloadSourceMode? mode,
  DownloadSourceKind? kind,
  bool supported,
});

/// 弹窗内展示影片时只需要这三个字段；预填场景不强行构造一个完整的
/// [MovieListItemDto]。
@immutable
class _MovieSummary {
  const _MovieSummary({
    required this.movieNumber,
    required this.title,
    this.coverUrl,
  });

  final String movieNumber;
  final String title;
  final String? coverUrl;

  factory _MovieSummary.fromListItem(MovieListItemDto movie) {
    final thinCover = movie.thinCoverImage?.origin.trim() ?? '';
    final wideCover = movie.coverImage?.origin.trim() ?? '';
    return _MovieSummary(
      movieNumber: movie.movieNumber,
      title: movie.title,
      coverUrl: thinCover.isNotEmpty
          ? thinCover
          : (wideCover.isNotEmpty ? wideCover : null),
    );
  }
}

@immutable
class _MovieResolution {
  const _MovieResolution.idle({this.rawInput = ''})
    : phase = _MovieResolutionPhase.idle,
      parsedNumber = null,
      message = null,
      movie = null,
      source = null;

  const _MovieResolution.resolving({
    required this.rawInput,
    this.parsedNumber,
    required this.message,
  }) : phase = _MovieResolutionPhase.resolving,
       movie = null,
       source = null;

  const _MovieResolution.resolved({
    required this.rawInput,
    required this.parsedNumber,
    required this.movie,
    required this.source,
  }) : phase = _MovieResolutionPhase.resolved,
       message = null;

  const _MovieResolution.failed({
    required this.rawInput,
    required this.message,
    this.parsedNumber,
  }) : phase = _MovieResolutionPhase.failed,
       movie = null,
       source = null;

  final _MovieResolutionPhase phase;

  /// 发起查询时的输入文本（trim 后），用于判断结果是否已过期。
  final String rawInput;

  /// parse-number 返回的查找键；可能不是最终规范番号。
  final String? parsedNumber;

  /// 进度或错误文案。
  final String? message;

  /// 仅在 resolved 阶段有值。
  final _MovieSummary? movie;

  final _MovieResolutionSource? source;

  bool get isResolving => phase == _MovieResolutionPhase.resolving;

  bool get isResolved =>
      phase == _MovieResolutionPhase.resolved && movie != null;
}

class _ManualDownloadDialog extends ConsumerStatefulWidget {
  const _ManualDownloadDialog({required this.hostContext, this.prefill});

  /// 打开弹层的页面 context；弹层自身 context 在 pop 后失效，导航要用它。
  final BuildContext hostContext;

  /// 从评论等上下文带入的预填信息；非空时使用紧凑表单。
  final ManualDownloadPrefill? prefill;

  @override
  ConsumerState<_ManualDownloadDialog> createState() =>
      _ManualDownloadDialogState();
}

class _ManualDownloadDialogState extends ConsumerState<_ManualDownloadDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _movieNumberController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  _ManualDownloadSourceMode _sourceMode = _ManualDownloadSourceMode.link;
  ManualDownloadMediaKind _mediaKind = ManualDownloadMediaKind.jav;
  int? _clientId;
  int? _collectionId;
  PickedFileWithBytes? _torrentFile;
  String? _fileError;
  String? _submitError;
  bool _deleteSourceAfterImport = false;
  bool _isSubmitting = false;

  _MovieResolution _movieResolution = const _MovieResolution.idle();
  int _movieQueryVersion = 0;
  StreamSubscription<MovieSearchStreamUpdate>? _activeMovieSearch;
  bool _hasAttemptedSubmit = false;

  bool get _isCompact => widget.prefill != null;

  DownloadSourceLink? get _detectedLink =>
      parseDetectedDownloadSourceLink(_sourceController.text);

  double get _sourceBlockHeight =>
      context.appFormTokens.fieldVerticalPadding * 2 +
      context.appTextScale.s14 * 3;

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    if (prefill == null) return;

    _sourceController.text = prefill.sourceUri;
    _movieNumberController.text = prefill.movieNumber;
    _sourceMode = prefill.sourceKind == DownloadSourceKind.torrent
        ? _ManualDownloadSourceMode.torrent
        : _ManualDownloadSourceMode.link;
    _mediaKind = ManualDownloadMediaKind.jav;
    final coverUrl = prefill.movieCoverUrl?.trim() ?? '';
    _movieResolution = _MovieResolution.resolved(
      rawInput: prefill.movieNumber,
      parsedNumber: prefill.movieNumber,
      movie: _MovieSummary(
        movieNumber: prefill.movieNumber,
        title: prefill.movieTitle?.trim() ?? '',
        coverUrl: coverUrl.isEmpty ? null : coverUrl,
      ),
      source: _MovieResolutionSource.currentMovie,
    );
  }

  @override
  void dispose() {
    _movieQueryVersion++;
    final active = _activeMovieSearch;
    _activeMovieSearch = null;
    if (active != null) {
      unawaited(active.cancel());
    }
    _sourceController.dispose();
    _movieNumberController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  DownloadClientDto? _findClient(
    List<DownloadClientDto> clients,
    int? clientId,
  ) {
    for (final client in clients) {
      if (client.id == clientId) return client;
    }
    return null;
  }

  DownloadClientDto? _selectedClient(List<DownloadClientDto> clients) {
    final selected = _findClient(clients, _clientId);
    if (selected != null) return selected;
    if (clients.isEmpty) return null;
    if (_isCompact) {
      final preferredKind = _detectedLink?.kind ?? widget.prefill?.sourceKind;
      if (preferredKind != null) {
        for (final client in clients) {
          if (client.supportedSourceKinds.contains(preferredKind.apiValue)) {
            return client;
          }
        }
      }
    }
    return clients.first;
  }

  bool _supportsSourceKind(
    DownloadClientDto? client,
    DownloadSourceKind kind,
  ) => client?.supportedSourceKinds.contains(kind.apiValue) ?? false;

  Set<_ManualDownloadSourceMode> _availableSourceModes(
    DownloadClientDto? client,
  ) {
    return <_ManualDownloadSourceMode>{
      if (_supportsSourceKind(client, DownloadSourceKind.magnet) ||
          _supportsSourceKind(client, DownloadSourceKind.ed2k) ||
          _supportsSourceKind(client, DownloadSourceKind.http))
        _ManualDownloadSourceMode.link,
      if (_supportsSourceKind(client, DownloadSourceKind.torrent))
        _ManualDownloadSourceMode.torrent,
    };
  }

  _ManualDownloadSourceMode? _effectiveSourceMode(DownloadClientDto? client) {
    final available = _availableSourceModes(client);
    if (available.contains(_sourceMode)) return _sourceMode;
    return available.isEmpty ? null : available.first;
  }

  DownloadSourceKind? _linkSourceKind() {
    return _detectedLink?.kind ??
        (_isCompact ? widget.prefill?.sourceKind : null);
  }

  _ResolvedDownloadSource _resolveSource(DownloadClientDto? client) {
    final mode = _isCompact ? _sourceMode : _effectiveSourceMode(client);
    final kind = switch (mode) {
      null => null,
      _ManualDownloadSourceMode.torrent => DownloadSourceKind.torrent,
      _ManualDownloadSourceMode.link => _linkSourceKind(),
    };
    final supported =
        client != null &&
        mode != null &&
        (kind == null || _supportsSourceKind(client, kind));
    return (mode: mode, kind: kind, supported: supported);
  }

  String? _validateLink(String? value) {
    final l10n = AppLocalizations.of(context);
    final text = value?.trim() ?? '';
    if (text.isEmpty) return l10n.downloadSourceRequired;
    if (text.contains('\n') || text.contains('\r')) {
      return l10n.downloadSourceSingleOnly;
    }
    if (parseDetectedDownloadSourceLink(text) != null) return null;
    return l10n.downloadLinkInvalid;
  }

  void _onLinkChanged(String _) {
    setState(() {
      _submitError = null;
    });
    if (_hasAttemptedSubmit) {
      _formKey.currentState?.validate();
    }
  }

  void _onSourceModeChanged(_ManualDownloadSourceMode value) {
    if (value == _sourceMode) return;
    setState(() {
      _sourceMode = value;
      _submitError = null;
      _fileError = null;
    });
    if (_hasAttemptedSubmit) {
      _formKey.currentState?.validate();
    }
  }

  void _onClientChanged(int? clientId, List<DownloadClientDto> clients) {
    final client = _findClient(clients, clientId);
    final availableModes = _availableSourceModes(client);
    final sourceMode = _isCompact || availableModes.contains(_sourceMode)
        ? _sourceMode
        : (availableModes.isEmpty ? _sourceMode : availableModes.first);
    setState(() {
      _clientId = clientId;
      _sourceMode = sourceMode;
      _submitError = null;
      _fileError = null;
    });
  }

  String _sourceKindLabel(AppLocalizations l10n, DownloadSourceKind kind) {
    return switch (kind) {
      DownloadSourceKind.magnet => l10n.downloadMagnetLabel,
      DownloadSourceKind.ed2k => l10n.downloadEd2kLabel,
      DownloadSourceKind.http => l10n.downloadHttpLabel,
      DownloadSourceKind.torrent => l10n.downloadTorrentLabel,
    };
  }

  String? _validateMovieNumber(String? value) {
    final l10n = AppLocalizations.of(context);
    final text = value?.trim() ?? '';
    if (text.isEmpty) return l10n.downloadMovieNumberRequired;
    final resolution = _movieResolution;
    if (resolution.isResolving) return l10n.downloadMovieNumberResolving;
    if (!resolution.isResolved || resolution.rawInput != text) {
      return l10n.downloadMovieNumberQueryFirst;
    }
    return null;
  }

  bool get _canQueryMovieNumber =>
      !_isSubmitting &&
      !_movieResolution.isResolving &&
      _movieNumberController.text.trim().isNotEmpty;

  int _invalidateMovieQuery() {
    final version = ++_movieQueryVersion;
    final active = _activeMovieSearch;
    _activeMovieSearch = null;
    if (active != null) {
      unawaited(active.cancel());
    }
    return version;
  }

  bool _isCurrentMovieQuery(int version) =>
      mounted && version == _movieQueryVersion;

  void _onMovieNumberChanged(String value) {
    final text = value.trim();
    if (text == _movieResolution.rawInput) return;
    _invalidateMovieQuery();
    setState(() {
      _movieResolution = _MovieResolution.idle(rawInput: text);
    });
  }

  void _onMediaKindChanged(ManualDownloadMediaKind value) {
    if (value == _mediaKind) return;
    _invalidateMovieQuery();
    setState(() {
      _mediaKind = value;
      _movieResolution = const _MovieResolution.idle();
    });
  }

  Future<void> _resolveMovieNumber() async {
    if (_isSubmitting || _movieResolution.isResolving) return;
    final l10n = AppLocalizations.of(context);
    final raw = _movieNumberController.text.trim();
    if (raw.isEmpty) return;
    final version = _invalidateMovieQuery();
    setState(() {
      _movieResolution = _MovieResolution.resolving(
        rawInput: raw,
        message: l10n.downloadMovieNumberParsing,
      );
    });
    try {
      final parsed = await ref
          .read(moviesApiProvider)
          .parseMovieNumber(query: raw);
      if (!_isCurrentMovieQuery(version)) return;
      final number = parsed.movieNumber?.trim() ?? '';
      if (!parsed.parsed || number.isEmpty) {
        _setMovieResolutionFailed(
          version,
          raw,
          l10n.downloadMovieNumberUnrecognized,
        );
        return;
      }
      setState(() {
        _movieResolution = _MovieResolution.resolving(
          rawInput: raw,
          parsedNumber: number,
          message: l10n.downloadMovieNumberParsed(number),
        );
      });
      final page = await ref
          .read(moviesApiProvider)
          .getMovies(query: number, pageSize: 50);
      if (!_isCurrentMovieQuery(version)) return;
      final local = _findExactLocalMovie(page.items, number);
      if (local != null) {
        _setMovieResolved(
          version,
          raw,
          number,
          local,
          _MovieResolutionSource.local,
        );
        return;
      }
      _startOnlineMovieSearch(version, raw, number);
    } catch (error) {
      if (!_isCurrentMovieQuery(version)) return;
      _setMovieResolutionFailed(
        version,
        raw,
        apiErrorMessage(
          error,
          fallback: l10n.downloadMovieNumberQueryFailed,
          l10n: l10n,
        ),
      );
    }
  }

  MovieListItemDto? _findExactLocalMovie(
    List<MovieListItemDto> items,
    String query,
  ) {
    final matches = items
        .where(
          (movie) => isExactMovieNumberMatch(
            storedMovieNumber: movie.movieNumber,
            query: query,
          ),
        )
        .toList(growable: false);
    if (matches.isEmpty) return null;
    final queryUpper = query.trim().toUpperCase();
    for (final movie in matches) {
      if (movie.movieNumber.trim().toUpperCase() == queryUpper) {
        return movie;
      }
    }
    return matches.first;
  }

  void _startOnlineMovieSearch(int version, String raw, String parsed) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _movieResolution = _MovieResolution.resolving(
        rawInput: raw,
        parsedNumber: parsed,
        message: l10n.downloadMovieNumberLocalNotFound,
      );
    });
    var settled = false;
    late final StreamSubscription<MovieSearchStreamUpdate> subscription;
    subscription = ref
        .read(moviesApiProvider)
        .searchOnlineMoviesStream(movieNumber: parsed)
        .listen(
          (update) {
            if (!_isCurrentMovieQuery(version) || settled) return;
            if (!update.isComplete) {
              setState(() {
                _movieResolution = _MovieResolution.resolving(
                  rawInput: raw,
                  parsedNumber: parsed,
                  message: update.message.isEmpty
                      ? l10n.downloadMovieNumberOnlineSearching
                      : update.message,
                );
              });
              return;
            }
            settled = true;
            final movie = update.results
                .where((item) => item.movieNumber.trim().isNotEmpty)
                .firstOrNull;
            if (update.success == true && movie != null) {
              _setMovieResolved(
                version,
                raw,
                parsed,
                movie,
                _MovieResolutionSource.online,
              );
            } else if (update.reason == 'movie_not_found' ||
                update.reason == 'movie_number_not_found') {
              _setMovieResolutionFailed(
                version,
                raw,
                l10n.downloadMovieNumberNotFound(parsed),
                parsed,
              );
            } else {
              _setMovieResolutionFailed(
                version,
                raw,
                l10n.downloadMovieNumberOnlineSearchFailed,
                parsed,
              );
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!_isCurrentMovieQuery(version) || settled) return;
            settled = true;
            _setMovieResolutionFailed(
              version,
              raw,
              apiErrorMessage(
                error,
                fallback: l10n.downloadMovieNumberOnlineSearchFailed,
                l10n: l10n,
              ),
              parsed,
            );
          },
          onDone: () {
            if (_isCurrentMovieQuery(version) && !settled) {
              _setMovieResolutionFailed(
                version,
                raw,
                l10n.downloadMovieNumberOnlineNoResult,
                parsed,
              );
            }
            if (identical(_activeMovieSearch, subscription)) {
              _activeMovieSearch = null;
            }
          },
          cancelOnError: false,
        );
    _activeMovieSearch = subscription;
  }

  void _setMovieResolved(
    int version,
    String raw,
    String? parsed,
    MovieListItemDto movie,
    _MovieResolutionSource source,
  ) {
    if (!_isCurrentMovieQuery(version)) return;
    setState(() {
      _movieResolution = _MovieResolution.resolved(
        rawInput: raw,
        parsedNumber: parsed,
        movie: _MovieSummary.fromListItem(movie),
        source: source,
      );
    });
    if (_hasAttemptedSubmit) {
      _formKey.currentState?.validate();
    }
  }

  void _setMovieResolutionFailed(
    int version,
    String raw,
    String message, [
    String? parsed,
  ]) {
    if (!_isCurrentMovieQuery(version)) return;
    setState(() {
      _movieResolution = _MovieResolution.failed(
        rawInput: raw,
        parsedNumber: parsed,
        message: message,
      );
    });
    if (_hasAttemptedSubmit) {
      _formKey.currentState?.validate();
    }
  }

  Future<void> _pickTorrentFile() async {
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final l10n = AppLocalizations.of(context);
    try {
      final picked = await pickFileWithBytes(
        type: isMobile ? FileType.any : FileType.custom,
        allowedExtensions: isMobile ? null : const <String>['torrent'],
        maxBytes: DownloadsApi.maxManualTorrentBytes,
        tooLargeMessage: l10n.downloadTorrentTooLarge,
        l10n: l10n,
        unreadableMessage: l10n.downloadTorrentUnreadable,
        pickerUnavailableMessage: l10n.downloadTorrentPickerUnavailable,
        openFailureMessage: l10n.downloadTorrentPickerOpenFailed,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _torrentFile = picked;
        _fileError = picked.bytes.length > DownloadsApi.maxManualTorrentBytes
            ? l10n.downloadTorrentTooLarge
            : null;
      });
    } on FilePickerWithBytesException catch (error) {
      if (mounted) {
        setState(() => _fileError = error.message);
      }
    }
  }

  Future<void> _pickCollection() async {
    final result = await showPickVideoCollectionSingleDialog(
      context,
      selectedCollectionId: _collectionId,
    );
    if (result == null || !mounted) return;
    setState(() => _collectionId = result.collectionId);
  }

  Future<void> _createCollection() async {
    final created = await showVideoCollectionDialog(
      context,
      presentation: AppPlatformScope.maybeOf(context) == AppPlatform.mobile
          ? VideoCollectionEditPresentation.bottomDrawer
          : VideoCollectionEditPresentation.dialog,
    );
    if (created == null || !mounted) return;
    // 先选中，避免随后 refresh 失败时丢掉选择。
    setState(() => _collectionId = created.id);
    await ref.read(videoCollectionsOverviewProvider.notifier).refresh();
  }

  void _goConfigureClients() {
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    if (!isMobile) {
      // 配置页是常驻路由分支，用一次性信号让它落到「下载器」分类。
      ref
          .read(configurationTabRequestProvider.notifier)
          .request('configuration-tab-downloads');
    }
    Navigator.of(context).pop();
    if (!widget.hostContext.mounted) return;
    if (isMobile) {
      MobileRoutes.settingsDownloaders().push(widget.hostContext);
    } else {
      widget.hostContext.goPrimary(AppRouteId.desktopConfiguration);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || _movieResolution.isResolving) return;
    final clients =
        ref.read(downloadClientsProvider).value ?? const <DownloadClientDto>[];
    final client = _selectedClient(clients);
    if (client == null) return;
    final l10n = AppLocalizations.of(context);
    final source = _resolveSource(client);
    if (!source.supported) {
      setState(() => _submitError = l10n.downloadSourceUnsupported);
      return;
    }

    _hasAttemptedSubmit = true;
    final formValid = _formKey.currentState?.validate() ?? false;
    final link = source.mode == _ManualDownloadSourceMode.link
        ? _detectedLink
        : null;
    if (source.mode == _ManualDownloadSourceMode.torrent) {
      final file = _torrentFile;
      if (file == null) {
        setState(() => _fileError = l10n.downloadTorrentFileRequired);
        return;
      }
      if (file.bytes.length > DownloadsApi.maxManualTorrentBytes) {
        setState(() => _fileError = l10n.downloadTorrentTooLarge);
        return;
      }
    }
    if (!formValid) return;

    if (_mediaKind == ManualDownloadMediaKind.jav) {
      final resolution = _movieResolution;
      final text = _movieNumberController.text.trim();
      if (!resolution.isResolved || resolution.rawInput != text) {
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
      _fileError = null;
    });

    final movieNumber = _mediaKind == ManualDownloadMediaKind.jav
        ? _movieResolution.movie!.movieNumber
        : null;
    final collectionId = _mediaKind == ManualDownloadMediaKind.video
        ? _collectionId
        : null;
    final displayName = _displayNameController.text.trim();

    try {
      final api = ref.read(downloadsApiProvider);
      final response = source.mode == _ManualDownloadSourceMode.link
          ? await api.createManualDownloadRequest(
              clientId: client.id,
              mediaKind: _mediaKind,
              sourceUri: _sourceController.text.trim(),
              sourceKind: link!.kind.apiValue,
              movieNumber: movieNumber,
              collectionId: collectionId,
              displayName: displayName,
              deleteSourceAfterImport: _deleteSourceAfterImport,
            )
          : await api.createManualTorrentDownloadRequest(
              clientId: client.id,
              mediaKind: _mediaKind,
              torrentBytes: _torrentFile!.bytes,
              fileName: _torrentFile!.fileName,
              movieNumber: movieNumber,
              collectionId: collectionId,
              displayName: displayName,
              deleteSourceAfterImport: _deleteSourceAfterImport,
            );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(ManualDownloadResult(response: response, clientName: client.name));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = apiErrorMessage(
          error,
          fallback: l10n.downloadCreateTaskFailed,
          l10n: l10n,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final clientsAsync = ref.watch(downloadClientsProvider);
    final clients = clientsAsync.value ?? const <DownloadClientDto>[];
    final selectedClient = _selectedClient(clients);
    final l10n = AppLocalizations.of(context);
    final source = _resolveSource(selectedClient);
    final canSubmit =
        !_isSubmitting && !_movieResolution.isResolving && source.supported;

    return PopScope(
      canPop: !_isSubmitting,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCompact
                            ? l10n.downloadLinkDialogTitle
                            : l10n.downloadManualAddTitle,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s16,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.primary,
                        ),
                      ),
                      SizedBox(height: spacing.xs),
                      Text(
                        _isCompact
                            ? l10n.downloadSourcePrefilledDescription
                            : l10n.downloadManualAddDescription,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing.sm),
                AppIconButton(
                  key: const Key('manual-download-close-button'),
                  tooltip: l10n.downloadClose,
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),
            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _isCompact
                        ? _buildCompactFormChildren(
                            clientsAsync,
                            selectedClient,
                            source,
                          )
                        : _buildFullFormChildren(
                            clientsAsync,
                            selectedClient,
                            source,
                          ),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    key: const Key('manual-download-cancel-button'),
                    label: l10n.commonCancel,
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: AppButton(
                    key: const Key('manual-download-submit-button'),
                    label: l10n.downloadSubmit,
                    variant: AppButtonVariant.primary,
                    isLoading: _isSubmitting,
                    onPressed: canSubmit ? _submit : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 完整表单：先选下载器，再展示该下载器支持的来源类型。
  List<Widget> _buildFullFormChildren(
    AsyncValue<List<DownloadClientDto>> clientsAsync,
    DownloadClientDto? selectedClient,
    _ResolvedDownloadSource source,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final availableSourceModes = _availableSourceModes(selectedClient);
    return <Widget>[
      _FormSectionLabel(l10n.downloadSectionSettings),
      SizedBox(height: spacing.sm),
      _buildClientField(clientsAsync, selectedClient),
      SizedBox(height: spacing.xl),
      if (selectedClient != null) ...[
        Row(
          children: [
            _FormSectionLabel(l10n.downloadSectionSource),
            if (availableSourceModes.length > 1) ...[
              const Spacer(),
              _buildSourceModeControl(availableSourceModes, source.mode!),
            ],
          ],
        ),
        SizedBox(height: spacing.sm),
        if (source.mode == null)
          _buildSourceUnsupportedBanner(
            key: const Key('manual-download-source-unsupported'),
          )
        else ...[
          if (source.mode == _ManualDownloadSourceMode.torrent)
            _buildTorrentField(context)
          else
            _buildLinkField(),
          if (!source.supported)
            Padding(
              padding: EdgeInsets.only(top: spacing.sm),
              child: _buildSourceUnsupportedBanner(
                key: const Key('manual-download-source-selected-unsupported'),
              ),
            ),
        ],
        SizedBox(height: spacing.md),
      ],
      _buildChoiceRow<ManualDownloadMediaKind>(
        options: [
          (ManualDownloadMediaKind.jav, l10n.downloadMediaKindJav),
          (ManualDownloadMediaKind.video, 'PornBox'),
        ],
        selected: _mediaKind,
        keyOf: (value) => Key('manual-download-kind-${value.apiValue}'),
        onChanged: _onMediaKindChanged,
      ),
      SizedBox(height: spacing.md),
      if (_mediaKind == ManualDownloadMediaKind.jav)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              fieldKey: const Key('manual-download-movie-number-field'),
              controller: _movieNumberController,
              label: l10n.downloadMovieNumberLabel,
              hintText: l10n.downloadMovieNumberHint,
              helperText: l10n.downloadMovieNumberHelper,
              enabled: !_isSubmitting,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => unawaited(_resolveMovieNumber()),
              onChanged: _onMovieNumberChanged,
              validator: _validateMovieNumber,
              // 紧凑按钮后缀：保留 tightSuffix 以维持 32/36 的 token 高度，
              // 不被默认 48px 后缀最小约束拉伸；左右留白与输入文字、边框
              // 拉开距离。
              tightSuffix: true,
              suffix: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: spacing.xs,
                  end: spacing.sm,
                ),
                child: AppTextButton(
                  key: const Key('manual-download-movie-number-query-button'),
                  label: _movieResolution.isResolving
                      ? l10n.downloadQuerying
                      : l10n.downloadQuery,
                  icon: const Icon(Icons.search_rounded),
                  size: AppTextButtonSize.small,
                  emphasis: AppTextButtonEmphasis.accent,
                  isLoading: _movieResolution.isResolving,
                  onPressed: _canQueryMovieNumber
                      ? () => unawaited(_resolveMovieNumber())
                      : null,
                ),
              ),
            ),
            _buildMovieResolutionStatus(context),
          ],
        )
      else
        _VideoCollectionField(
          collectionId: _collectionId,
          onTap: _pickCollection,
          onCreate: _createCollection,
          enabled: !_isSubmitting,
        ),
      SizedBox(height: spacing.md),
      AppTextField(
        fieldKey: const Key('manual-download-display-name-field'),
        controller: _displayNameController,
        label: l10n.downloadDisplayNameLabel,
        helperText: l10n.downloadDisplayNameHelper,
        enabled: !_isSubmitting,
      ),
      SizedBox(height: spacing.md),
      _buildDeleteSourceRow(context),
      _buildSubmitError(),
    ];
  }

  /// 预填表单：来源和影片已由调用方确定，只让用户确认下载器。
  ///
  /// 紧凑模式不再画「资源 / 下载设置」分组标题，下载器也不带字段名——
  /// 这里只有来源、影片和下载器三项，字段自身已经说明用途。
  List<Widget> _buildCompactFormChildren(
    AsyncValue<List<DownloadClientDto>> clientsAsync,
    DownloadClientDto? selectedClient,
    _ResolvedDownloadSource source,
  ) {
    final spacing = context.appSpacing;
    return <Widget>[
      _buildClientField(clientsAsync, selectedClient, showLabel: false),
      SizedBox(height: spacing.md),
      if (selectedClient != null && !source.supported)
        _buildSourceUnsupportedBanner(
          key: const Key('manual-download-source-selected-unsupported'),
        )
      else if (selectedClient != null &&
          source.mode == _ManualDownloadSourceMode.torrent)
        _buildTorrentField(context)
      else if (selectedClient != null)
        _buildLinkField(compact: true),
      _buildMovieResolutionStatus(context),
      _buildSubmitError(),
    ];
  }

  Widget _buildSourceUnsupportedBanner({required Key key}) {
    return AppInlineErrorBanner(
      key: key,
      message: AppLocalizations.of(context).downloadSourceUnsupported,
      tone: AppInlineErrorTone.error,
    );
  }

  Widget _buildSubmitError() {
    final error = _submitError;
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: context.appSpacing.md),
      child: AppInlineErrorBanner(
        key: const Key('manual-download-submit-error'),
        message: error,
        tone: AppInlineErrorTone.error,
      ),
    );
  }

  Widget _buildLinkField({bool compact = false}) {
    final l10n = AppLocalizations.of(context);
    final detectedLink = _detectedLink;
    return AppTextField(
      fieldKey: const Key('manual-download-link-field'),
      controller: _sourceController,
      hintText: compact
          ? l10n.downloadSourceCompactHelper
          : l10n.downloadLinkHelper,
      suffix: detectedLink == null
          ? null
          : Padding(
              padding: EdgeInsets.only(right: context.appSpacing.md),
              child: AppBadge(
                key: const Key('manual-download-detected-source-kind'),
                label: _sourceKindLabel(l10n, detectedLink.kind),
                tone: AppBadgeTone.neutral,
                size: AppBadgeSize.compact,
              ),
            ),
      tightSuffix: true,
      minLines: 3,
      maxLines: 3,
      keyboardType: TextInputType.url,
      enabled: !_isSubmitting,
      onChanged: _onLinkChanged,
      validator: _validateLink,
    );
  }

  Widget _buildSourceModeControl(
    Set<_ManualDownloadSourceMode> available,
    _ManualDownloadSourceMode selected,
  ) {
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      ignoring: _isSubmitting,
      child: Opacity(
        opacity: _isSubmitting ? 0.5 : 1,
        child: AppSegmentedControl<_ManualDownloadSourceMode>(
          key: const Key('manual-download-source-mode'),
          items: [
            for (final mode in _ManualDownloadSourceMode.values)
              if (available.contains(mode))
                AppSegmentedItem<_ManualDownloadSourceMode>(
                  key: Key('manual-download-source-mode-${mode.name}'),
                  value: mode,
                  label: switch (mode) {
                    _ManualDownloadSourceMode.link =>
                      l10n.downloadLinkModeLabel,
                    _ManualDownloadSourceMode.torrent =>
                      l10n.downloadTorrentLabel,
                  },
                ),
          ],
          selected: selected,
          size: AppSegmentedSize.compact,
          onChanged: _onSourceModeChanged,
        ),
      ),
    );
  }

  Widget _buildChoiceRow<T>({
    required List<(T, String)> options,
    required T selected,
    required ValueChanged<T> onChanged,
    Key Function(T value)? keyOf,
  }) {
    return Row(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) SizedBox(width: context.appSpacing.sm),
          Expanded(
            child: AppButton(
              key: keyOf?.call(options[index].$1),
              label: options[index].$2,
              size: AppButtonSize.small,
              variant: AppButtonVariant.secondary,
              isSelected: options[index].$1 == selected,
              onPressed: _isSubmitting
                  ? null
                  : () => onChanged(options[index].$1),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildClientField(
    AsyncValue<List<DownloadClientDto>> clientsAsync,
    DownloadClientDto? selectedClient, {
    bool showLabel = true,
  }) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    if (clientsAsync.isLoading && !clientsAsync.hasValue) {
      return Row(
        children: [
          const AppInlineSpinner(),
          SizedBox(width: spacing.sm),
          Text(
            l10n.downloadLoadingClients,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      );
    }
    if (clientsAsync.hasError && !clientsAsync.hasValue) {
      return AppInlineErrorBanner(
        message: apiErrorMessage(
          clientsAsync.error!,
          fallback: l10n.downloadClientsLoadFailed,
          l10n: l10n,
        ),
        retryKey: const Key('manual-download-clients-retry'),
        onRetry: () => ref.read(downloadClientsProvider.notifier).reload(),
      );
    }

    final clients = clientsAsync.value ?? const <DownloadClientDto>[];
    if (clients.isEmpty) {
      return Container(
        key: const Key('manual-download-no-clients'),
        padding: EdgeInsets.all(spacing.md),
        decoration: BoxDecoration(
          color: context.appColors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
          border: Border.all(color: context.appColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.downloadClientsEmpty,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              l10n.downloadClientsEmptyHint,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.muted,
              ),
            ),
            SizedBox(height: spacing.sm),
            AppButton(
              key: const Key('manual-download-configure-clients-button'),
              label: l10n.downloadConfigureClients,
              size: AppButtonSize.xSmall,
              onPressed: _isSubmitting ? null : _goConfigureClients,
            ),
          ],
        ),
      );
    }

    return AppSelectField<int?>(
      key: const Key('manual-download-client-field'),
      label: showLabel ? l10n.downloadClientLabel : null,
      value: selectedClient?.id,
      placeholder: l10n.downloadSelectClient,
      items: clients
          .map(
            (client) => DropdownMenuItem<int?>(
              value: client.id,
              child: Text(client.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: _isSubmitting
          ? null
          : (value) => _onClientChanged(value, clients),
    );
  }

  Widget _buildTorrentField(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final file = _torrentFile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _sourceBlockHeight,
          child: Container(
            key: const Key('manual-download-torrent-dropzone'),
            width: double.infinity,
            padding: EdgeInsets.all(spacing.sm),
            decoration: BoxDecoration(
              color: context.appColors.surfaceMuted,
              borderRadius: context.appRadius.mdBorder,
              border: Border.all(color: context.appColors.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: context.appComponentTokens.iconSizeMd,
                  color: context.appTextPalette.secondary,
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file?.fileName ?? l10n.downloadTorrentNotSelected,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          tone: file == null
                              ? AppTextTone.muted
                              : AppTextTone.primary,
                        ),
                      ),
                      SizedBox(height: spacing.xs / 2),
                      Text(
                        file == null
                            ? l10n.downloadTorrentSelectHint
                            : formatFileSize(file.bytes.length),
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          tone: AppTextTone.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing.sm),
                AppButton(
                  key: const Key('manual-download-pick-torrent-button'),
                  label: file == null
                      ? l10n.downloadChooseFile
                      : l10n.downloadChooseFileAgain,
                  size: AppButtonSize.xSmall,
                  onPressed: _isSubmitting ? null : _pickTorrentFile,
                ),
              ],
            ),
          ),
        ),
        if (_fileError != null) ...[
          SizedBox(height: spacing.xs),
          Text(
            _fileError!,
            key: const Key('manual-download-file-error'),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeleteSourceRow(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return AppInteractiveSurface(
      key: const Key('manual-download-delete-source-row'),
      onTap: _isSubmitting
          ? null
          : () => setState(
              () => _deleteSourceAfterImport = !_deleteSourceAfterImport,
            ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.downloadDeleteSourceAfterImport,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    l10n.downloadDeleteSourceAfterImportHint,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: spacing.md),
            AppSwitch(
              key: const Key('manual-download-delete-source-switch'),
              value: _deleteSourceAfterImport,
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _deleteSourceAfterImport = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieResolutionStatus(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final resolution = _movieResolution;
    switch (resolution.phase) {
      case _MovieResolutionPhase.idle:
        return const SizedBox.shrink();
      case _MovieResolutionPhase.resolving:
        return Padding(
          padding: EdgeInsets.only(top: spacing.sm),
          child: Row(
            key: const Key('manual-download-movie-resolution-loading'),
            children: [
              const AppInlineSpinner(),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  resolution.message ??
                      l10n.downloadMovieNumberResolvingFallback,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.muted,
                  ),
                ),
              ),
            ],
          ),
        );
      case _MovieResolutionPhase.failed:
        return Padding(
          padding: EdgeInsets.only(top: spacing.sm),
          child: AppInlineErrorBanner(
            key: const Key('manual-download-movie-resolution-error'),
            message:
                resolution.message ?? l10n.downloadMovieNumberQueryFailedTitle,
            tone: AppInlineErrorTone.error,
          ),
        );
      case _MovieResolutionPhase.resolved:
        final movie = resolution.movie;
        if (movie == null) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(top: spacing.sm),
          child: _ResolvedMovieCard(
            movie: movie,
            source: resolution.source ?? _MovieResolutionSource.local,
          ),
        );
    }
  }
}

class _ResolvedMovieCard extends StatelessWidget {
  const _ResolvedMovieCard({required this.movie, required this.source});

  final _MovieSummary movie;
  final _MovieResolutionSource source;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final coverUrl = movie.coverUrl ?? '';
    return Container(
      key: const Key('manual-download-movie-resolution-card'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: context.appRadius.xsBorder,
            child: SizedBox(
              width: 48,
              height: 64,
              child: coverUrl.isEmpty
                  ? Container(
                      color: context.appColors.surfaceMuted,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.movie_creation_outlined,
                        size: context.appComponentTokens.iconSizeMd,
                        color: context.appTextPalette.muted,
                      ),
                    )
                  : MaskedImage(url: coverUrl, fit: BoxFit.cover),
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        movie.movieNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.xs),
                    AppBadge(
                      key: const Key('manual-download-movie-resolution-source'),
                      label: switch (source) {
                        _MovieResolutionSource.local =>
                          l10n.downloadMovieSourceLocal,
                        _MovieResolutionSource.online =>
                          l10n.downloadMovieSourceOnline,
                        _MovieResolutionSource.currentMovie =>
                          l10n.downloadMovieSourceCurrent,
                      },
                      tone: source == _MovieResolutionSource.local
                          ? AppBadgeTone.neutral
                          : AppBadgeTone.info,
                      size: AppBadgeSize.compact,
                    ),
                  ],
                ),
                SizedBox(height: spacing.xs),
                Text(
                  movie.title.trim().isEmpty
                      ? l10n.downloadUnknownTitle
                      : movie.title.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.medium,
        tone: AppTextTone.secondary,
      ),
    );
  }
}

/// 视频合集只读触发条：外观对齐 [AppTextField]，点击打开可搜索单选弹层。
class _VideoCollectionField extends ConsumerWidget {
  const _VideoCollectionField({
    required this.collectionId,
    required this.onTap,
    required this.onCreate,
    required this.enabled,
  });

  final int? collectionId;
  final VoidCallback onTap;
  final VoidCallback onCreate;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections =
        ref.watch(videoCollectionsOverviewProvider).value ??
        const <VideoCollectionDto>[];
    String? name;
    if (collectionId != null) {
      for (final collection in collections) {
        if (collection.id == collectionId) {
          name = collection.name;
          break;
        }
      }
    }
    return VideoCollectionPickerField(
      valueLabel: name,
      onTap: onTap,
      onCreate: onCreate,
      enabled: enabled,
      fieldKey: const Key('manual-download-collection-field'),
      createButtonKey: const Key('manual-download-create-collection-button'),
    );
  }
}
