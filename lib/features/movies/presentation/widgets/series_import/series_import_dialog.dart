import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/presentation/providers/series_import_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/series_import_state.dart';
import 'package:sakuramedia/features/search/data/catalog_search_stream_stats.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

Future<bool> showSeriesImportDialog(BuildContext context, int seriesId) async {
  final platform = Theme.of(context).platform;
  final isMobile =
      platform == TargetPlatform.iOS || platform == TargetPlatform.android;

  if (isMobile) {
    final spacing = context.appSpacing;
    final result = await showAppBottomDrawer<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      maxHeightFactor: 1.0,
      useSafeArea: true,
      ignoreTopSafeArea: true,
      contentPadding: EdgeInsets.fromLTRB(
        spacing.xl,
        spacing.md + spacing.lg,
        spacing.xl,
        spacing.xl,
      ),
      builder: (ctx) => _SeriesImportSheet(seriesId: seriesId),
    );
    return result ?? false;
  } else {
    final result = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SeriesImportDesktopDialog(seriesId: seriesId),
    );
    return result ?? false;
  }
}

// ─── 共用 provider 生命周期管理 ──────────────────────────────────────────────

class _SeriesImportHost extends ConsumerStatefulWidget {
  const _SeriesImportHost({required this.seriesId, required this.builder});

  final int seriesId;
  final Widget Function(
    BuildContext context,
    SeriesImportState state,
    SeriesImport notifier,
    void Function(bool) dismiss,
  )
  builder;

  @override
  ConsumerState<_SeriesImportHost> createState() => _SeriesImportHostState();
}

class _SeriesImportHostState extends ConsumerState<_SeriesImportHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(seriesImportProvider(widget.seriesId).notifier).startImport();
      }
    });
  }

  void _dismiss(bool hasNewMovies) {
    Navigator.of(context).pop(hasNewMovies);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(seriesImportProvider(widget.seriesId));
    final notifier = ref.read(seriesImportProvider(widget.seriesId).notifier);
    return widget.builder(context, state, notifier, _dismiss);
  }
}

// ─── 移动端底部弹出 ───────────────────────────────────────────────────────────

class _SeriesImportSheet extends StatelessWidget {
  const _SeriesImportSheet({required this.seriesId});

  final int seriesId;

  @override
  Widget build(BuildContext context) {
    return _SeriesImportHost(
      seriesId: seriesId,
      builder: (context, state, notifier, dismiss) {
        return PopScope(
          canPop: state.canDismiss,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) dismiss(state.hasNewMovies);
          },
          child: _SeriesImportContent(
            state: state,
            onDone: () => dismiss(state.hasNewMovies),
            onRetry: notifier.startImport,
          ),
        );
      },
    );
  }
}

// ─── 桌面端对话框 ─────────────────────────────────────────────────────────────

class _SeriesImportDesktopDialog extends StatelessWidget {
  const _SeriesImportDesktopDialog({required this.seriesId});

  final int seriesId;

  @override
  Widget build(BuildContext context) {
    return _SeriesImportHost(
      seriesId: seriesId,
      builder: (context, state, notifier, dismiss) {
        final spacing = context.appSpacing;

        return PopScope(
          canPop: state.canDismiss,
          child: AppDesktopDialog(
            width: 460,
            showCloseButton: state.canDismiss,
            onClose: () => dismiss(state.hasNewMovies),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).movieWidgetSeriesImportTitle,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s16,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: spacing.lg),
                _SeriesImportContent(
                  state: state,
                  onDone: () => dismiss(state.hasNewMovies),
                  onRetry: notifier.startImport,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── 共用内容区域 ─────────────────────────────────────────────────────────────

class _SeriesImportContent extends StatelessWidget {
  const _SeriesImportContent({
    required this.state,
    required this.onDone,
    required this.onRetry,
  });

  final SeriesImportState state;
  final VoidCallback onDone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    if (state.hasFailed) {
      return _FailureView(
        errorMessage:
            state.errorMessage ??
            AppLocalizations.of(context).errorImportFailed,
        onRetry: onRetry,
        onClose: onDone,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusRow(state: state),
        SizedBox(height: spacing.md),
        _ProgressBar(state: state),
        if (state.isCompleted && state.stats != null) ...[
          SizedBox(height: spacing.lg),
          _StatsCard(stats: state.stats!),
        ],
        SizedBox(height: spacing.xl),
        _ActionRow(state: state, onDone: onDone),
      ],
    );
  }
}

// ─── 状态行（图标 + 文字 + 进度数字） ────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.state});

  final SeriesImportState state;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    Widget icon;
    if (state.isCompleted && !state.hasFailed) {
      icon = Icon(
        Icons.check_circle_rounded,
        color: _successColor(context),
        size: 22,
      );
    } else if (state.hasFailed) {
      icon = Icon(Icons.error_rounded, color: _errorColor(context), size: 22);
    } else {
      icon = AppInlineSpinner(color: _accentColor(context));
    }

    return Row(
      children: [
        icon,
        SizedBox(width: spacing.sm),
        Expanded(
          child: Text(
            state.statusMessage,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.medium,
              tone: AppTextTone.primary,
            ),
          ),
        ),
        if (state.current != null && state.total != null)
          Text(
            '${state.current} / ${state.total}',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
      ],
    );
  }
}

// ─── 进度条 ───────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.state});

  final SeriesImportState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;

    return ClipRRect(
      borderRadius: context.appRadius.xsBorder,
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 5,
        backgroundColor: context.appColors.borderSubtle,
        color: state.hasFailed
            ? _errorColor(context)
            : state.isCompleted
            ? _successColor(context)
            : _accentColor(context),
      ),
    );
  }
}

// ─── 完成统计卡片 ─────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final CatalogSearchStreamStats stats;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final radius = context.appRadius;
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      decoration: BoxDecoration(
        color: context.appColors.successSurface,
        borderRadius: radius.smBorder,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            label: l10n.movieWidgetSeriesCreated,
            value: stats.createdCount,
          ),
          _StatDivider(),
          _StatItem(
            label: l10n.movieWidgetSeriesAlreadyExists,
            value: stats.alreadyExistsCount,
          ),
          if (stats.failedCount > 0) ...[
            _StatDivider(),
            _StatItem(
              label: l10n.movieWidgetSeriesFailed,
              value: stats.failedCount,
              isError: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.isError = false,
  });

  final String label;
  final int value;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s20,
            weight: AppTextWeight.semibold,
            tone: isError ? AppTextTone.error : AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: VerticalDivider(color: context.appColors.borderSubtle, width: 1),
    );
  }
}

// ─── 操作按钮行 ───────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.state, required this.onDone});

  final SeriesImportState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        label: state.hasNewMovies
            ? l10n.movieWidgetSeriesImportDoneWithRefresh
            : l10n.commonDone,
        variant: AppButtonVariant.primary,
        onPressed: state.canDismiss ? onDone : null,
      ),
    );
  }
}

// ─── 失败视图 ─────────────────────────────────────────────────────────────────

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.errorMessage,
    required this.onRetry,
    required this.onClose,
  });

  final String errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final radius = context.appRadius;
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: context.appColors.errorSurface,
            borderRadius: radius.smBorder,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: _errorColor(context),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  errorMessage,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.error,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.movieWidgetClose,
                onPressed: onClose,
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: AppButton(
                label: l10n.commonRetry,
                variant: AppButtonVariant.primary,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── 颜色辅助 ─────────────────────────────────────────────────────────────────

Color _accentColor(BuildContext context) =>
    resolveAppTextToneColor(context, AppTextTone.accent);

Color _successColor(BuildContext context) =>
    resolveAppTextToneColor(context, AppTextTone.success);

Color _errorColor(BuildContext context) =>
    resolveAppTextToneColor(context, AppTextTone.error);
