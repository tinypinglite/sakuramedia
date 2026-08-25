import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/relative_time_label.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/controllers/system_diagnostics_controller.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/diagnostic_category_card.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_page_frame.dart';

class DesktopSystemDiagnosticsPage extends ConsumerStatefulWidget {
  const DesktopSystemDiagnosticsPage({super.key});

  @override
  ConsumerState<DesktopSystemDiagnosticsPage> createState() =>
      _DesktopSystemDiagnosticsPageState();
}

class _DesktopSystemDiagnosticsPageState
    extends ConsumerState<DesktopSystemDiagnosticsPage> {
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
        ],
      ),
    );
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
