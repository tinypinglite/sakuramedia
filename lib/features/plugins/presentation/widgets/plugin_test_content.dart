import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/app_date_format.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';

class PluginTestContent extends ConsumerStatefulWidget {
  const PluginTestContent({super.key, required this.plugin});

  final PluginSummaryDto plugin;

  @override
  ConsumerState<PluginTestContent> createState() => _PluginTestContentState();
}

class _PluginTestContentState extends ConsumerState<PluginTestContent> {
  final Map<PluginTestCapability, _PluginTestEntry> _entries = {};
  bool _testingAll = false;

  List<PluginTestCapability> get _capabilities =>
      widget.plugin.testCapabilities;

  bool get _anyTesting =>
      _testingAll || _entries.values.any((entry) => entry.isTesting);

  @override
  void initState() {
    super.initState();
    for (final capability in _capabilities) {
      _entries[capability] = const _PluginTestEntry();
    }
  }

  Future<void> _runOne(PluginTestCapability capability) async {
    setState(() {
      _entries[capability] = const _PluginTestEntry(isTesting: true);
    });
    try {
      final result = await ref
          .read(pluginsApiProvider)
          .testCapability(widget.plugin.pluginId, capability);
      if (!mounted) {
        return;
      }
      setState(() {
        _entries[capability] = _PluginTestEntry(result: result);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _entries[capability] = _PluginTestEntry(
          requestError: apiErrorMessage(
            error,
            fallback: l10n.pluginTestRequestFailed,
            l10n: l10n,
          ),
        );
      });
    }
  }

  Future<void> _runAll() async {
    if (_anyTesting) {
      return;
    }
    setState(() => _testingAll = true);
    try {
      for (final capability in _capabilities) {
        if (!mounted) {
          return;
        }
        await _runOne(capability);
      }
    } finally {
      if (mounted) {
        setState(() => _testingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final movieNumber = widget.plugin.testMovieNumber ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.pluginTestTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          '${widget.plugin.displayName} · v${widget.plugin.version}',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: spacing.lg),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppNoticeCard(
                  leadingIcon: Icons.science_outlined,
                  description: movieNumber.isEmpty
                      ? l10n.pluginTestConfigNoticeWithoutNumber
                      : l10n.pluginTestConfigNotice(movieNumber),
                ),
                SizedBox(height: spacing.lg),
                if (_capabilities.isEmpty)
                  Text(
                    l10n.pluginTestNoCapabilities,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.secondary,
                    ),
                  )
                else
                  AppContentCard(
                    title: l10n.pluginTestCapabilitiesTitle,
                    padding: EdgeInsets.fromLTRB(
                      spacing.lg,
                      spacing.lg,
                      spacing.lg,
                      0,
                    ),
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < _capabilities.length;
                          index++
                        ) ...[
                          _PluginTestCapabilityRow(
                            capability: _capabilities[index],
                            entry: _entries[_capabilities[index]]!,
                            enabled: !_anyTesting,
                            onRun: () =>
                                unawaited(_runOne(_capabilities[index])),
                          ),
                          if (index != _capabilities.length - 1)
                            Divider(
                              height: 1,
                              indent:
                                  context.appComponentTokens.iconSizeXl +
                                  spacing.sm +
                                  spacing.md,
                              color: context.appColors.divider,
                            ),
                        ],
                      ],
                    ),
                  ),
                SizedBox(height: spacing.lg),
                AppButton(
                  key: const Key('plugin-test-run-all-button'),
                  label: l10n.pluginTestRunAll,
                  icon: const Icon(Icons.playlist_play_rounded),
                  variant: AppButtonVariant.primary,
                  isLoading: _testingAll,
                  onPressed: _capabilities.isEmpty || _anyTesting
                      ? null
                      : () => unawaited(_runAll()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PluginTestEntry {
  const _PluginTestEntry({
    this.isTesting = false,
    this.result,
    this.requestError,
  });

  final bool isTesting;
  final PluginTestResultDto? result;
  final String? requestError;
}

class _PluginTestCapabilityRow extends StatelessWidget {
  const _PluginTestCapabilityRow({
    required this.capability,
    required this.entry,
    required this.enabled,
    required this.onRun,
  });

  final PluginTestCapability capability;
  final _PluginTestEntry entry;
  final bool enabled;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final status = _status(l10n);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.appComponentTokens.iconSizeXl + spacing.sm,
            height: context.appComponentTokens.iconSizeXl + spacing.sm,
            decoration: BoxDecoration(
              color: context.appColors.surfaceMuted,
              borderRadius: context.appRadius.smBorder,
            ),
            child: Icon(
              _icon,
              size: context.appComponentTokens.iconSizeMd,
              color: context.appTextPalette.secondary,
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(l10n),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: spacing.xs / 2),
                Text(
                  _description(l10n),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.secondary,
                  ),
                ),
                if (_hasResult) ...[
                  SizedBox(height: spacing.sm),
                  _PluginTestResultBox(capability: capability, entry: entry),
                ],
              ],
            ),
          ),
          SizedBox(width: spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppStatusChip(
                label: status.label,
                palette: status.palette,
                isBusy: entry.isTesting,
                dense: true,
              ),
              SizedBox(height: spacing.sm),
              AppButton(
                key: Key('plugin-test-run-${capability.wireValue}'),
                label: l10n.pluginTestRun,
                size: AppButtonSize.xSmall,
                onPressed: enabled ? onRun : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasResult => entry.result != null || entry.requestError != null;

  IconData get _icon => switch (capability) {
    PluginTestCapability.metadata => Icons.description_outlined,
    PluginTestCapability.stats => Icons.query_stats_rounded,
    PluginTestCapability.reviews => Icons.chat_bubble_outline_rounded,
  };

  String _label(AppLocalizations l10n) => switch (capability) {
    PluginTestCapability.metadata => l10n.pluginTestCapabilityMetadata,
    PluginTestCapability.stats => l10n.pluginTestCapabilityStats,
    PluginTestCapability.reviews => l10n.pluginTestCapabilityReviews,
  };

  String _description(AppLocalizations l10n) => switch (capability) {
    PluginTestCapability.metadata =>
      l10n.pluginTestCapabilityMetadataDescription,
    PluginTestCapability.stats => l10n.pluginTestCapabilityStatsDescription,
    PluginTestCapability.reviews => l10n.pluginTestCapabilityReviewsDescription,
  };

  _PluginTestStatus _status(AppLocalizations l10n) {
    if (entry.isTesting) {
      return _PluginTestStatus(
        label: l10n.pluginTestStatusTesting,
        palette: AppStatusChipPalette.info(),
      );
    }
    final result = entry.result;
    if (result == null) {
      return entry.requestError == null
          ? _PluginTestStatus(
              label: l10n.pluginTestStatusPending,
              palette: AppStatusChipPalette.neutral(),
            )
          : _PluginTestStatus(
              label: l10n.pluginTestStatusFailed,
              palette: AppStatusChipPalette.error(),
            );
    }
    return switch (result.status) {
      PluginTestStatus.ok => _PluginTestStatus(
        label: l10n.pluginTestStatusOk,
        palette: AppStatusChipPalette.success(),
      ),
      PluginTestStatus.empty => _PluginTestStatus(
        label: l10n.pluginTestStatusEmpty,
        palette: AppStatusChipPalette.warning(),
      ),
      PluginTestStatus.failed => _PluginTestStatus(
        label: l10n.pluginTestStatusFailed,
        palette: AppStatusChipPalette.error(),
      ),
    };
  }
}

class _PluginTestStatus {
  const _PluginTestStatus({required this.label, required this.palette});

  final String label;
  final AppStatusChipPalette palette;
}

class _PluginTestResultBox extends StatelessWidget {
  const _PluginTestResultBox({required this.capability, required this.entry});

  final PluginTestCapability capability;
  final _PluginTestEntry entry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final result = entry.result;
    final failed =
        entry.requestError != null || result?.status == PluginTestStatus.failed;
    final empty = result?.status == PluginTestStatus.empty;
    final background = failed
        ? context.appColors.errorSurface
        : empty
        ? context.appColors.warningSurface
        : context.appColors.successSurface;
    final tone = failed
        ? AppTextTone.error
        : empty
        ? AppTextTone.warning
        : AppTextTone.success;
    final text = _summary(context, l10n);
    return Container(
      key: Key('plugin-test-result-${capability.wireValue}'),
      width: double.infinity,
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.medium,
              tone: tone,
            ),
          ),
          if (result != null) ...[
            SizedBox(height: spacing.xs / 2),
            Text(
              l10n.pluginTestElapsed(result.durationMs),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s10,
                tone: AppTextTone.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _summary(BuildContext context, AppLocalizations l10n) {
    final error = entry.requestError;
    if (error != null) {
      return error;
    }
    final result = entry.result!;
    if (result.status == PluginTestStatus.failed) {
      return result.errorMessage?.trim().isNotEmpty == true
          ? result.errorMessage!
          : l10n.pluginTestFailedGeneric;
    }
    if (result.status == PluginTestStatus.empty) {
      return switch (result.capability) {
        PluginTestCapability.metadata => l10n.pluginTestEmptyMetadata,
        PluginTestCapability.stats => l10n.pluginTestEmptyStats,
        PluginTestCapability.reviews => l10n.pluginTestEmptyReviews,
      };
    }
    return switch (result.capability) {
      PluginTestCapability.metadata => _metadataSummary(l10n, result),
      PluginTestCapability.stats => _statsSummary(l10n, result),
      PluginTestCapability.reviews => _reviewsSummary(l10n, result),
    };
  }

  String _metadataSummary(AppLocalizations l10n, PluginTestResultDto result) {
    final metadata = result.metadata;
    if (metadata == null) {
      return l10n.pluginTestFailedGeneric;
    }
    final date = metadata.releaseDate;
    final dateLabel = date == null ? '' : ' · ${formatAppDate(date)}';
    return l10n.pluginTestMetadataSummary(
          metadata.title,
          metadata.actorCount,
          metadata.tagCount,
          metadata.imageCount,
        ) +
        dateLabel;
  }

  String _statsSummary(AppLocalizations l10n, PluginTestResultDto result) {
    final stats = result.stats;
    if (stats == null) {
      return l10n.pluginTestFailedGeneric;
    }
    return l10n.pluginTestStatsSummary(
      formatAppCompactCount(stats.heat),
      stats.fieldCount,
    );
  }

  String _reviewsSummary(AppLocalizations l10n, PluginTestResultDto result) {
    final reviews = result.reviews;
    if (reviews == null) {
      return l10n.pluginTestFailedGeneric;
    }
    final username = reviews.firstUsername?.trim() ?? '';
    final excerpt = reviews.firstExcerpt?.trim() ?? '';
    final base = l10n.pluginTestReviewsSummary(reviews.itemCount);
    return <String>[
      base,
      if (username.isNotEmpty) '@$username',
      if (excerpt.isNotEmpty) excerpt,
    ].join(' · ');
  }
}
