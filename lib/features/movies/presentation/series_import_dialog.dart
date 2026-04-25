import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/series_import_controller.dart';
import 'package:sakuramedia/features/search/data/catalog_search_stream_stats.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';

Future<bool> showSeriesImportDialog(
  BuildContext context,
  int seriesId,
) async {
  final platform = Theme.of(context).platform;
  final isMobile =
      platform == TargetPlatform.iOS || platform == TargetPlatform.android;

  if (isMobile) {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _SeriesImportSheet(
            seriesId: seriesId,
            moviesApi: context.read<MoviesApi>(),
          ),
    );
    return result ?? false;
  } else {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _SeriesImportDesktopDialog(
            seriesId: seriesId,
            moviesApi: context.read<MoviesApi>(),
          ),
    );
    return result ?? false;
  }
}

// ─── 共用 controller 生命周期管理 ────────────────────────────────────────────

class _SeriesImportHost extends StatefulWidget {
  const _SeriesImportHost({
    required this.seriesId,
    required this.moviesApi,
    required this.builder,
  });

  final int seriesId;
  final MoviesApi moviesApi;
  final Widget Function(
    BuildContext context,
    SeriesImportController controller,
    void Function(bool) dismiss,
  ) builder;

  @override
  State<_SeriesImportHost> createState() => _SeriesImportHostState();
}

class _SeriesImportHostState extends State<_SeriesImportHost> {
  late final SeriesImportController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SeriesImportController(moviesApi: widget.moviesApi);
    _controller.startImport(widget.seriesId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss(bool hasNewMovies) {
    Navigator.of(context).pop(hasNewMovies);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, _) => widget.builder(ctx, _controller, _dismiss),
    );
  }
}

// ─── 移动端底部弹出 ───────────────────────────────────────────────────────────

class _SeriesImportSheet extends StatelessWidget {
  const _SeriesImportSheet({required this.seriesId, required this.moviesApi});

  final int seriesId;
  final MoviesApi moviesApi;

  @override
  Widget build(BuildContext context) {
    return _SeriesImportHost(
      seriesId: seriesId,
      moviesApi: moviesApi,
      builder: (context, controller, dismiss) {
        final spacing = context.appSpacing;
        final radius = context.appRadius;

        return PopScope(
          canPop: controller.canDismiss,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) dismiss(controller.hasNewMovies);
          },
          child: Container(
            decoration: BoxDecoration(
              color: context.appColors.surfaceCard,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(radius.lg),
                topRight: Radius.circular(radius.lg),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              spacing.xl,
              spacing.md,
              spacing.xl,
              spacing.xl + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DragHandle(),
                SizedBox(height: spacing.md),
                _SeriesImportContent(
                  controller: controller,
                  onDone: () => dismiss(controller.hasNewMovies),
                  onRetry: () => controller.startImport(seriesId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── 桌面端对话框 ─────────────────────────────────────────────────────────────

class _SeriesImportDesktopDialog extends StatelessWidget {
  const _SeriesImportDesktopDialog({
    required this.seriesId,
    required this.moviesApi,
  });

  final int seriesId;
  final MoviesApi moviesApi;

  @override
  Widget build(BuildContext context) {
    return _SeriesImportHost(
      seriesId: seriesId,
      moviesApi: moviesApi,
      builder: (context, controller, dismiss) {
        final spacing = context.appSpacing;

        return PopScope(
          canPop: controller.canDismiss,
          child: AppDesktopDialog(
            width: 460,
            showCloseButton: controller.canDismiss,
            onClose: () => dismiss(controller.hasNewMovies),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '导入系列影片',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s16,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: spacing.lg),
                _SeriesImportContent(
                  controller: controller,
                  onDone: () => dismiss(controller.hasNewMovies),
                  onRetry: () => controller.startImport(seriesId),
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
    required this.controller,
    required this.onDone,
    required this.onRetry,
  });

  final SeriesImportController controller;
  final VoidCallback onDone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    if (controller.hasFailed) {
      return _FailureView(
        errorMessage: controller.errorMessage ?? '导入失败，请稍后重试',
        onRetry: onRetry,
        onClose: onDone,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusRow(controller: controller),
        SizedBox(height: spacing.md),
        _ProgressBar(controller: controller),
        if (controller.isCompleted && controller.stats != null) ...[
          SizedBox(height: spacing.lg),
          _StatsCard(stats: controller.stats!),
        ],
        SizedBox(height: spacing.xl),
        _ActionRow(
          controller: controller,
          onDone: onDone,
        ),
      ],
    );
  }
}

// ─── 状态行（图标 + 文字 + 进度数字） ────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.controller});

  final SeriesImportController controller;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    Widget icon;
    if (controller.isCompleted && !controller.hasFailed) {
      icon = Icon(
        Icons.check_circle_rounded,
        color: _successColor(context),
        size: 22,
      );
    } else if (controller.hasFailed) {
      icon = Icon(
        Icons.error_rounded,
        color: _errorColor(context),
        size: 22,
      );
    } else {
      icon = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: _accentColor(context),
        ),
      );
    }

    return Row(
      children: [
        icon,
        SizedBox(width: spacing.sm),
        Expanded(
          child: Text(
            controller.statusMessage,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.medium,
              tone: AppTextTone.primary,
            ),
          ),
        ),
        if (controller.current != null && controller.total != null)
          Text(
            '${controller.current} / ${controller.total}',
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
  const _ProgressBar({required this.controller});

  final SeriesImportController controller;

  @override
  Widget build(BuildContext context) {
    final progress = controller.progress;

    return ClipRRect(
      borderRadius: context.appRadius.xsBorder,
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 5,
        backgroundColor: context.appColors.borderSubtle,
        color: controller.hasFailed
            ? _errorColor(context)
            : controller.isCompleted
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
          _StatItem(label: '新增', value: stats.createdCount),
          _StatDivider(),
          _StatItem(label: '已存在', value: stats.alreadyExistsCount),
          if (stats.failedCount > 0) ...[
            _StatDivider(),
            _StatItem(label: '失败', value: stats.failedCount, isError: true),
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
  const _ActionRow({required this.controller, required this.onDone});

  final SeriesImportController controller;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: controller.canDismiss ? onDone : null,
        child: Text(controller.hasNewMovies ? '完成（刷新列表）' : '完成'),
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
              child: OutlinedButton(
                onPressed: onClose,
                child: const Text('关闭'),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: FilledButton(
                onPressed: onRetry,
                child: const Text('重试'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── 移动端拖动手柄 ───────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: context.appColors.borderStrong,
        borderRadius: context.appRadius.xsBorder,
      ),
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
