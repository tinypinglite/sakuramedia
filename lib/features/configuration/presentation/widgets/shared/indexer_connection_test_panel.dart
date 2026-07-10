import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';

/// 展示已保存 Jackett 配置的真实搜索测试，并供桌面和移动设置页复用。
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

  String get _statusLabel {
    if (isTesting) return '测试中';
    if (!_hasResult) return '待测试';
    return _isHealthy ? '连通正常' : '连通失败';
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Jackett 连通性',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
            AppStatusChip(
              label: _statusLabel,
              palette: _statusPalette(context),
              isBusy: isTesting,
              dense: true,
            ),
          ],
        ),
        SizedBox(height: spacing.xs),
        Text(
          '使用已保存的配置执行一次真实 Torznab 搜索，不会修改 Jackett 数据。',
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
          label: _hasResult ? '重新测试' : '测试 Jackett 连通性',
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

  AppStatusChipPalette _statusPalette(BuildContext context) {
    final colors = context.appColors;
    if (isTesting) {
      return AppStatusChipPalette(
        background: colors.selectionSurface,
        borderColor: colors.selectionBorder,
        tone: AppTextTone.accent,
        foreground: resolveAppTextToneColor(context, AppTextTone.accent),
        icon: Icons.radar_rounded,
      );
    }
    if (!_hasResult) {
      return AppStatusChipPalette(
        background: colors.surfaceMuted,
        borderColor: colors.borderSubtle,
        tone: AppTextTone.secondary,
        foreground: context.appTextPalette.secondary,
        icon: Icons.hourglass_empty_rounded,
      );
    }
    if (_isHealthy) {
      return AppStatusChipPalette(
        background: colors.successSurface,
        borderColor: null,
        tone: AppTextTone.success,
        foreground: resolveAppTextToneColor(context, AppTextTone.success),
        icon: Icons.check_circle_outline,
      );
    }
    return AppStatusChipPalette(
      background: colors.errorSurface,
      borderColor: null,
      tone: AppTextTone.error,
      foreground: resolveAppTextToneColor(context, AppTextTone.error),
      icon: Icons.error_outline,
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
    final backgroundColor =
        _isHealthy ? colors.successSurface : colors.errorSurface;
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
            _headline,
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
                _MetricText(label: '查询', value: result.query),
                _MetricText(label: '索引器', value: '${result.indexersChecked} 个'),
                _MetricText(label: '候选', value: '${result.resultCount} 条'),
                _MetricText(label: '耗时', value: '${result.elapsedMs} ms'),
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
              _fixHint,
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

  String get _headline {
    final result = this.result;
    if (result == null) return requestError ?? '请求 Jackett 测试接口失败';
    if (result.healthy) {
      return result.resultCount == 0
          ? 'Jackett 已连通，测试查询未返回候选。'
          : 'Jackett 已连通，真实搜索已完成。';
    }
    return result.error?.message.isNotEmpty == true
        ? result.error!.message
        : 'Jackett 未能完成本次连通性测试。';
  }

  String get _fixHint {
    if (result?.error?.type == 'no_indexers_configured') {
      return '请添加至少一个索引器并保存配置后再测试。';
    }
    return '请检查 Jackett 服务、API Key 和索引器地址后重试。';
  }
}

class _MetricText extends StatelessWidget {
  const _MetricText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label：$value',
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s10,
        weight: AppTextWeight.regular,
        tone: AppTextTone.secondary,
      ),
    );
  }
}
