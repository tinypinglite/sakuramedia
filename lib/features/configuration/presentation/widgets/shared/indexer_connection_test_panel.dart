import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';

/// 展示已保存 Torznab 索引器配置的真实搜索测试，并供桌面和移动设置页复用。
class IndexerConnectionTestPanel extends StatelessWidget {
  const IndexerConnectionTestPanel({
    super.key,
    required this.isTesting,
    required this.isTestEnabled,
    required this.onTest,
    required this.result,
    required this.requestError,
    this.disabledMessage,
    this.testButtonKey,
    this.resultKey,
  });

  final bool isTesting;
  final bool isTestEnabled;
  final VoidCallback? onTest;
  final IndexerConnectionTestResultDto? result;
  final String? requestError;
  final String? disabledMessage;
  final Key? testButtonKey;
  final Key? resultKey;

  bool get _hasResult => result != null || requestError != null;

  bool get _isHealthy => result?.healthy == true;

  String _statusLabel(AppLocalizations l10n) {
    if (isTesting) return l10n.indexerTestStatusTesting;
    if (!_hasResult) return l10n.indexerTestStatusPending;
    return _isHealthy
        ? l10n.indexerTestStatusHealthy
        : l10n.indexerTestStatusFailed;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.indexerTestPanelTitle,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
            AppStatusChip(
              label: _statusLabel(l10n),
              palette: AppStatusChipPalette.forSemantic(
                isTesting
                    ? AppStatusSemantic.inProgress
                    : !_hasResult
                    ? AppStatusSemantic.neutral
                    : _isHealthy
                    ? AppStatusSemantic.success
                    : AppStatusSemantic.error,
              ),
              isBusy: isTesting,
              dense: true,
            ),
          ],
        ),
        SizedBox(height: spacing.xs),
        Text(
          l10n.indexerTestPanelDescription,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.md),
        AppButton(
          key: testButtonKey,
          label: _hasResult ? l10n.indexerTestAgain : l10n.indexerTestStart,
          icon: isTesting ? null : const Icon(Icons.radar_rounded),
          size: AppButtonSize.small,
          isLoading: isTesting,
          onPressed: isTestEnabled && !isTesting ? onTest : null,
        ),
        if (!isTestEnabled && disabledMessage != null) ...[
          SizedBox(height: spacing.sm),
          Text(
            disabledMessage!,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
        if (_hasResult) ...[
          SizedBox(height: spacing.md),
          _ResultSummary(
            key: resultKey,
            result: result,
            requestError: requestError,
          ),
        ],
      ],
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({
    super.key,
    required this.result,
    required this.requestError,
  });

  final IndexerConnectionTestResultDto? result;
  final String? requestError;

  bool get _isHealthy => result?.healthy == true;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final backgroundColor = _isHealthy
        ? colors.successSurface
        : colors.errorSurface;
    final tone = _isHealthy ? AppTextTone.success : AppTextTone.error;
    final result = this.result;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _headline(l10n),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.medium,
              tone: tone,
            ),
          ),
          if (result != null) ...[
            SizedBox(height: spacing.xs),
            Wrap(
              spacing: spacing.md,
              runSpacing: spacing.xs,
              children: [
                _MetricText(
                  label: l10n.indexerTestMetricQuery,
                  value: result.query,
                ),
                _MetricText(
                  label: l10n.indexerTestMetricIndexers,
                  value: l10n.indexerTestCountIndexers(result.indexersChecked),
                ),
                _MetricText(
                  label: l10n.indexerTestMetricResults,
                  value: l10n.indexerTestCountResults(result.resultCount),
                ),
                _MetricText(
                  label: l10n.indexerTestMetricElapsed,
                  value: '${result.elapsedMs} ms',
                ),
              ],
            ),
            if (!_isHealthy && result.error?.type.isNotEmpty == true) ...[
              SizedBox(height: spacing.xs),
              Text(
                result.error!.type,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s10,
                  weight: AppTextWeight.regular,
                  tone: tone,
                ),
              ),
            ],
          ],
          if (!_isHealthy) ...[
            SizedBox(height: spacing.xs),
            Text(
              _fixHint(l10n),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s10,
                weight: AppTextWeight.regular,
                tone: tone,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _headline(AppLocalizations l10n) {
    final result = this.result;
    if (result == null) {
      return requestError ?? l10n.indexerTestRequestFailed;
    }
    if (result.healthy) {
      return result.resultCount == 0
          ? l10n.indexerTestHealthyNoResults
          : l10n.indexerTestHealthy;
    }
    return result.error?.message.isNotEmpty == true
        ? result.error!.message
        : l10n.indexerTestIncomplete;
  }

  String _fixHint(AppLocalizations l10n) {
    if (result?.error?.type == 'no_indexers_configured') {
      return l10n.indexerTestFixNoIndexers;
    }
    return l10n.indexerTestFixGeneric;
  }
}

class _MetricText extends StatelessWidget {
  const _MetricText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context).metricText(label, value),
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s10,
        weight: AppTextWeight.regular,
        tone: AppTextTone.secondary,
      ),
    );
  }
}
