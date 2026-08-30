import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/relative_time_label.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/controllers/system_diagnostics_controller.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/diagnostic_category_card.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_page_frame.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';

class DesktopSystemDiagnosticsPage extends ConsumerStatefulWidget {
  const DesktopSystemDiagnosticsPage({super.key});

  @override
  ConsumerState<DesktopSystemDiagnosticsPage> createState() =>
      _DesktopSystemDiagnosticsPageState();
}

class _DesktopSystemDiagnosticsPageState
    extends ConsumerState<DesktopSystemDiagnosticsPage> {
  bool _isResettingImageSearch = false;
  @override
  void initState() {
    super.initState();
    // 进入页面直接跑一次 —— 页面本身是低频访问入口，不需要用户再点一次按钮才能看到结果。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(
            systemDiagnosticsProvider(
              SystemDiagnosticsHost.desktopPage,
            ).notifier,
          )
          .runAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final diagnostics = ref.watch(
      systemDiagnosticsProvider(SystemDiagnosticsHost.desktopPage),
    );
    return AppPageFrame(
      title: '',
      child: Column(
        key: const Key('desktop-system-diagnostics-page'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, diagnostics),
          SizedBox(height: spacing.xl),
          for (final cat in diagnostics.categories) ...[
            DiagnosticCategoryCard(
              key: Key('diagnostic-category-${cat.label}'),
              category: cat,
            ),
            SizedBox(height: spacing.lg),
          ],
          _buildImageSearchMaintenanceCard(context),
        ],
      ),
    );
  }

  Widget _buildImageSearchMaintenanceCard(BuildContext context) {
    final spacing = context.appSpacing;
    return AppContentCard(
      title: '图搜索维护',
      child: Row(
        children: [
          Expanded(
            child: Text(
              '更换嵌入模型后，重建索引以重新生成全部图片向量。重建期间图搜索结果可能暂时不完整。',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
          SizedBox(width: spacing.lg),
          AppButton(
            key: const Key('desktop-image-search-reset-index'),
            label: '重建索引',
            variant: AppButtonVariant.primary,
            isLoading: _isResettingImageSearch,
            onPressed: _isResettingImageSearch
                ? null
                : _confirmImageSearchReset,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmImageSearchReset() async {
    setState(() => _isResettingImageSearch = true);
    try {
      final confirmed = await showAppConfirmDialog(
        context,
        title: '重建图搜索索引',
        message: '这会清空现有图片索引并重新开始构建，确认继续吗？',
        confirmLabel: '重建索引',
        danger: true,
        dialogKey: const Key('desktop-image-search-reset-confirm-dialog'),
        confirmKey: const Key('desktop-image-search-reset-confirm'),
        cancelKey: const Key('desktop-image-search-reset-cancel'),
        onConfirm: () => ref.read(statusApiProvider).resetImageSearch(),
        failureFallback: '重建图搜索索引失败',
      );
      if (confirmed && mounted) {
        showToast('图搜索索引已开始重建');
      }
    } finally {
      if (mounted) {
        setState(() => _isResettingImageSearch = false);
      }
    }
  }

  Widget _buildHeader(
    BuildContext context,
    SystemDiagnosticsState diagnostics,
  ) {
    final spacing = context.appSpacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '组件诊断',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s20,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                _buildSubtitle(diagnostics),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: spacing.md),
        AppButton(
          key: const Key('desktop-system-diagnostics-rerun'),
          label: '重新检测',
          variant: AppButtonVariant.primary,
          icon: const Icon(Icons.refresh),
          isLoading: diagnostics.isRunning,
          onPressed: diagnostics.isRunning
              ? null
              : ref
                    .read(
                      systemDiagnosticsProvider(
                        SystemDiagnosticsHost.desktopPage,
                      ).notifier,
                    )
                    .runAll,
        ),
      ],
    );
  }

  String _buildSubtitle(SystemDiagnosticsState c) {
    if (c.isRunning) {
      return '正在检测 ${c.completedItemCount}/${c.totalItemCount}…';
    }
    if (c.lastRunAt == null) {
      return '尚未检测。点右上角开始一次完整检测。';
    }
    if (c.unhealthyCount > 0) {
      return '上次检测：${formatRelativeTimeLabel(c.lastRunAt!)} · '
          '${c.unhealthyCount} 项异常';
    }
    return '上次检测：${formatRelativeTimeLabel(c.lastRunAt!)} · 全部通过';
  }
}
