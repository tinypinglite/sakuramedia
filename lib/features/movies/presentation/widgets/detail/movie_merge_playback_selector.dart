import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_technical.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_merge_playback_models.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer_scroll_region.dart';

Future<MovieMergePlaybackSubmission?> showMovieMergePlaybackSelector({
  required BuildContext context,
  required MovieDetailDto movie,
  required String modeDescription,
  required bool mobile,
  Set<int>? externalMergeSupportedLibraryIds,
  required Future<MovieMergePlaybackSubmission> Function(
    MovieMergePlaybackSelection selection,
  )
  onSubmit,
}) {
  return showAppAdaptiveModal<MovieMergePlaybackSubmission>(
    context: context,
    variant: mobile
        ? AppAdaptiveModalVariant.drawer
        : AppAdaptiveModalVariant.dialog,
    dialogKey: const Key('movie-merge-playback-dialog'),
    drawerKey: const Key('movie-merge-playback-drawer'),
    desktopConstraints: BoxConstraints(
      maxWidth: context.appLayoutTokens.dialogWidthMd,
      maxHeight: MediaQuery.sizeOf(context).height * 0.78,
    ),
    mobileHeightFactor: 0.9,
    barrierDismissible: false,
    builder: (_) => MovieMergePlaybackSelector(
      movie: movie,
      modeDescription: modeDescription,
      externalMergeSupportedLibraryIds: externalMergeSupportedLibraryIds,
      onSubmit: onSubmit,
    ),
  );
}

class MovieMergePlaybackSelector extends StatefulWidget {
  const MovieMergePlaybackSelector({
    super.key,
    required this.movie,
    required this.modeDescription,
    this.externalMergeSupportedLibraryIds,
    required this.onSubmit,
  });

  final MovieDetailDto movie;
  final String modeDescription;
  final Set<int>? externalMergeSupportedLibraryIds;
  final Future<MovieMergePlaybackSubmission> Function(
    MovieMergePlaybackSelection selection,
  )
  onSubmit;

  @override
  State<MovieMergePlaybackSelector> createState() =>
      _MovieMergePlaybackSelectorState();
}

class _MovieMergePlaybackSelectorState
    extends State<MovieMergePlaybackSelector> {
  final List<MovieMediaItemDto> _selected = <MovieMediaItemDto>[];
  bool _isSubmitting = false;
  String? _errorMessage;

  int? get _selectedLibraryId =>
      _selected.isEmpty ? null : _selected.first.libraryId;

  bool get _canSubmit =>
      _selected.length >= 2 &&
      _selected.every((media) => media.valid && media.hasPlayableUrl);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = _buildGroups();
    final selectedLibraryName = _libraryName(l10n, _selectedLibraryId, groups);

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.moviePageMergedPlayback,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s20,
            weight: AppTextWeight.semibold,
          ),
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          widget.modeDescription,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        Expanded(
          child: AppBottomDrawerScrollRegion(
            enabled:
                AppAdaptiveModalShellScope.maybeOf(context)?.isDrawer != false,
            builder: (context, controller) => ListView.separated(
              key: const Key('movie-merge-playback-list'),
              controller: controller,
              padding: EdgeInsets.zero,
              itemCount: groups.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: context.appSpacing.md),
              itemBuilder: (context, index) {
                final group = groups[index];
                return _LibraryGroupCard(
                  group: group,
                  libraryName: _libraryName(l10n, group.libraryId, groups),
                  selectedLibraryId: _selectedLibraryId,
                  externalMergeSupportedLibraryIds:
                      widget.externalMergeSupportedLibraryIds,
                  selectedItems: _selected,
                  enabled: !_isSubmitting,
                  onToggle: _toggle,
                );
              },
            ),
          ),
        ),
        SizedBox(height: context.appSpacing.md),
        if (_errorMessage != null) ...[
          AppInlineErrorBanner(
            message: _errorMessage!,
            tone: AppInlineErrorTone.error,
          ),
          SizedBox(height: context.appSpacing.md),
        ],
        _SelectionFooter(
          selected: _selected,
          selectedLibraryName: selectedLibraryName,
          isSubmitting: _isSubmitting,
          canSubmit: _canSubmit,
          onClear: _clearSelection,
          onCancel: _isSubmitting
              ? null
              : () => Navigator.of(context).maybePop(),
          onSubmit: _canSubmit && !_isSubmitting ? _submit : null,
        ),
      ],
    );
  }

  List<_LibraryGroup> _buildGroups() {
    final grouped = <int, List<MovieMediaItemDto>>{};
    for (final media in widget.movie.mediaItems) {
      final libraryId = media.libraryId;
      if (libraryId == null) continue;
      grouped.putIfAbsent(libraryId, () => <MovieMediaItemDto>[]).add(media);
    }
    final libraryIds = grouped.keys.toList()..sort();
    return [
      for (final libraryId in libraryIds)
        _LibraryGroup(
          libraryId: libraryId,
          mediaItems: grouped[libraryId]!..sort(_compareMediaForDisplay),
        ),
    ];
  }

  String _libraryName(
    AppLocalizations l10n,
    int? libraryId,
    List<_LibraryGroup> groups,
  ) {
    if (libraryId == null) {
      return '';
    }
    var name = '';
    for (final group in groups) {
      if (group.libraryId == libraryId) {
        name = group.mediaItems.first.libraryName?.trim() ?? '';
        break;
      }
    }
    return name.isNotEmpty ? name : l10n.mediaLibraryFallback(libraryId);
  }

  void _toggle(MovieMediaItemDto media) {
    if (_isSubmitting || !media.valid || !media.hasPlayableUrl) {
      return;
    }
    final selectedLibraryId = _selectedLibraryId;
    if (selectedLibraryId != null && selectedLibraryId != media.libraryId) {
      return;
    }
    setState(() {
      _errorMessage = null;
      final index = _selected.indexWhere(
        (item) => item.mediaId == media.mediaId,
      );
      if (index >= 0) {
        _selected.removeAt(index);
      } else {
        _selected.add(media);
      }
    });
  }

  void _clearSelection() {
    if (_isSubmitting) return;
    setState(() {
      _selected.clear();
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final selection = MovieMergePlaybackSelection(
      mediaItems: List<MovieMediaItemDto>.unmodifiable(_selected),
    );
    try {
      final submission = await widget.onSubmit(selection);
      if (!mounted) return;
      Navigator.of(context).pop(submission);
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isSubmitting = false;
        _errorMessage = switch (error) {
          MovieMergePlaybackSubmitException(:final message) => message,
          _ => apiErrorMessage(
            error,
            fallback: l10n.movieActionMergedPlaybackStartFailed,
            l10n: l10n,
          ),
        };
      });
    }
  }
}

class _LibraryGroupCard extends StatelessWidget {
  const _LibraryGroupCard({
    required this.group,
    required this.libraryName,
    required this.selectedLibraryId,
    required this.externalMergeSupportedLibraryIds,
    required this.selectedItems,
    required this.enabled,
    required this.onToggle,
  });

  final _LibraryGroup group;
  final String libraryName;
  final int? selectedLibraryId;
  final Set<int>? externalMergeSupportedLibraryIds;
  final List<MovieMediaItemDto> selectedItems;
  final bool enabled;
  final ValueChanged<MovieMediaItemDto> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playableCount = group.mediaItems
        .where((media) => media.valid && media.hasPlayableUrl)
        .length;
    final externalUnsupported =
        externalMergeSupportedLibraryIds != null &&
        !externalMergeSupportedLibraryIds!.contains(group.libraryId);
    final notEnoughPlayable = playableCount < 2;
    final disabledBySelection =
        selectedLibraryId != null && selectedLibraryId != group.libraryId;
    final disabled =
        externalUnsupported || notEnoughPlayable || disabledBySelection;
    final hint = externalUnsupported
        ? l10n.movieMergePlaybackExternalUnsupportedHint
        : notEnoughPlayable
        ? l10n.movieMergePlaybackNotEnoughHint
        : disabledBySelection
        ? l10n.movieMergePlaybackLibraryDisabledHint
        : l10n.movieMergePlaybackPlayableCount(playableCount);
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: AppContentCard(
        key: Key('movie-merge-playback-group-${group.libraryId}'),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(context.appSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: context.appComponentTokens.iconSizeSm,
                    color: context.appTextPalette.secondary,
                  ),
                  SizedBox(width: context.appSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          libraryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: resolveAppTextStyle(
                            context,
                            size: AppTextSize.s14,
                            weight: AppTextWeight.semibold,
                          ),
                        ),
                        SizedBox(height: context.appSpacing.xs / 2),
                        Text(
                          hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: resolveAppTextStyle(
                            context,
                            size: AppTextSize.s12,
                            tone: AppTextTone.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppBadge(
                    label: l10n.movieMergePlaybackFilesCount(
                      group.mediaItems.length,
                    ),
                    tone: AppBadgeTone.neutral,
                    size: AppBadgeSize.compact,
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: context.appColors.divider),
            for (
              var index = 0;
              index < group.mediaItems.length;
              index += 1
            ) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: context.appColors.divider,
                ),
              _MediaSelectionRow(
                media: group.mediaItems[index],
                selectedItems: selectedItems,
                enabled: enabled && !disabled,
                onTap: () => onToggle(group.mediaItems[index]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaSelectionRow extends StatelessWidget {
  const _MediaSelectionRow({
    required this.media,
    required this.selectedItems,
    required this.enabled,
    required this.onTap,
  });

  final MovieMediaItemDto media;
  final List<MovieMediaItemDto> selectedItems;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedIndex = selectedItems.indexWhere(
      (item) => item.mediaId == media.mediaId,
    );
    final selected = selectedIndex >= 0;
    final playable = media.valid && media.hasPlayableUrl;
    final canToggle = enabled && playable;
    final technicalSummary = _technicalSummary(media);

    return AppInteractiveSurface(
      key: Key('movie-merge-playback-file-${media.mediaId}'),
      enabled: canToggle,
      onTap: canToggle ? onTap : null,
      semanticLabel: l10n.movieMergePlaybackSelectFile,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : context.appMotion.fast,
        color: selected ? context.appColors.surfaceMuted : null,
        padding: EdgeInsets.symmetric(
          horizontal: context.appSpacing.md,
          vertical: context.appSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IgnorePointer(
              child: Checkbox(
                key: Key('movie-merge-playback-checkbox-${media.mediaId}'),
                value: selected,
                onChanged: canToggle ? (_) {} : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            SizedBox(width: context.appSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          media.fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: resolveAppTextStyle(
                            context,
                            size: AppTextSize.s14,
                            weight: AppTextWeight.medium,
                          ),
                        ),
                      ),
                      if (selected) ...[
                        SizedBox(width: context.appSpacing.sm),
                        AppBadge(
                          key: Key(
                            'movie-merge-playback-order-${media.mediaId}',
                          ),
                          label: '${selectedIndex + 1}',
                          tone: AppBadgeTone.primary,
                          size: AppBadgeSize.compact,
                        ),
                      ],
                      if (!playable) ...[
                        SizedBox(width: context.appSpacing.sm),
                        AppBadge(
                          label: l10n.movieMergePlaybackUnavailable,
                          tone: AppBadgeTone.error,
                          size: AppBadgeSize.compact,
                        ),
                      ],
                    ],
                  ),
                  if (technicalSummary != null) ...[
                    SizedBox(height: context.appSpacing.xs),
                    Text(
                      technicalSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _technicalSummary(MovieMediaItemDto media) {
    final videoInfo = media.videoInfo;
    final parts = <String>[
      if (media.resolution?.trim().isNotEmpty == true) media.resolution!.trim(),
      ?formatVideoCodecName(videoInfo?.video?.codecName),
      ?formatVideoBitRate(
        videoInfo?.video?.bitRate,
        videoInfo?.container?.bitRate,
      ),
      if (media.fileSizeBytes > 0) formatFileSize(media.fileSizeBytes),
      if (media.durationSeconds > 0) formatMediaTimecode(media.durationSeconds),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _SelectionFooter extends StatelessWidget {
  const _SelectionFooter({
    required this.selected,
    required this.selectedLibraryName,
    required this.isSubmitting,
    required this.canSubmit,
    required this.onClear,
    required this.onCancel,
    required this.onSubmit,
  });

  final List<MovieMediaItemDto> selected;
  final String selectedLibraryName;
  final bool isSubmitting;
  final bool canSubmit;
  final VoidCallback onClear;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.isEmpty
                        ? l10n.movieMergePlaybackSelectHint
                        : l10n.movieMergePlaybackSelectedSummary(
                            selected.length,
                            selectedLibraryName,
                          ),
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      weight: AppTextWeight.medium,
                    ),
                  ),
                  if (selected.isNotEmpty) ...[
                    SizedBox(height: spacing.xs),
                    Text(
                      '${l10n.movieMergePlaybackOrderHint} · '
                      '${l10n.movieMergePlaybackSameLibraryHint}',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected.isNotEmpty && !isSubmitting)
              AppTextButton(
                key: const Key('movie-merge-playback-clear'),
                label: l10n.movieMergePlaybackClearSelection,
                onPressed: onClear,
                emphasis: AppTextButtonEmphasis.secondary,
              ),
          ],
        ),
        SizedBox(height: spacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.commonCancel,
                variant: AppButtonVariant.secondary,
                onPressed: onCancel,
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              flex: 2,
              child: AppButton(
                key: const Key('movie-merge-playback-submit'),
                label: l10n.moviePageMergedPlayback,
                variant: AppButtonVariant.primary,
                isLoading: isSubmitting,
                onPressed: canSubmit || isSubmitting ? onSubmit : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LibraryGroup {
  const _LibraryGroup({required this.libraryId, required this.mediaItems});

  final int libraryId;
  final List<MovieMediaItemDto> mediaItems;
}

int _compareMediaForDisplay(MovieMediaItemDto a, MovieMediaItemDto b) {
  final resolutionCompare = _resolutionHeight(
    b.resolution,
  ).compareTo(_resolutionHeight(a.resolution));
  if (resolutionCompare != 0) {
    return resolutionCompare;
  }
  return _naturalCompare(a.fileName, b.fileName);
}

int _resolutionHeight(String? resolution) {
  final parts = resolution?.toLowerCase().split('x');
  if (parts == null || parts.length != 2) {
    return 0;
  }
  return int.tryParse(parts.last.trim()) ?? 0;
}

int _naturalCompare(String left, String right) {
  final leftParts = _naturalParts(left);
  final rightParts = _naturalParts(right);
  final length = leftParts.length < rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var index = 0; index < length; index += 1) {
    final leftPart = leftParts[index];
    final rightPart = rightParts[index];
    final leftNumber = int.tryParse(leftPart);
    final rightNumber = int.tryParse(rightPart);
    final compare = leftNumber != null && rightNumber != null
        ? leftNumber.compareTo(rightNumber)
        : leftPart.toLowerCase().compareTo(rightPart.toLowerCase());
    if (compare != 0) {
      return compare;
    }
  }
  return leftParts.length.compareTo(rightParts.length);
}

List<String> _naturalParts(String value) {
  final parts = <String>[];
  final buffer = StringBuffer();
  bool? digit;
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final currentDigit = RegExp(r'\d').hasMatch(char);
    if (digit != null && digit != currentDigit) {
      parts.add(buffer.toString());
      buffer.clear();
    }
    buffer.write(char);
    digit = currentDigit;
  }
  if (buffer.isNotEmpty) {
    parts.add(buffer.toString());
  }
  return parts;
}
