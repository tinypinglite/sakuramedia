import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_category_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/diagnostic_item_tile.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/diagnostic_status_badge.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 一张分组卡片。标题右侧带一个汇总徽章；内容是一串 [DiagnosticItemTile]。
///
/// 没有用 `AppSettingsGroup`：它虽然也做"卡片 + 行间分隔线"，但不支持标题旁的
/// 汇总徽章（只有纯文字 `header`），套进 `AppContentCard` 又会叠出两层卡片背景/
/// 边框/阴影——这里的手写 `Divider` 循环是刻意保留的最简单写法。
class DiagnosticCategoryCard extends StatelessWidget {
  const DiagnosticCategoryCard({super.key, required this.category});

  final DiagnosticCategoryState category;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return AppContentCard(
      title: category.label,
      headerBottomSpacing: spacing.md,
      headerTrailing: _buildAggregateBadge(l10n),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < category.items.length; i++) ...[
            _buildTile(category.items[i]),
            if (i != category.items.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: context.appColors.borderSubtle,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTile(DiagnosticItemState item) {
    return DiagnosticItemTile(
      key: Key('diagnostic-item-${item.itemKey}'),
      item: item,
    );
  }

  Widget _buildAggregateBadge(AppLocalizations l10n) {
    final aggregate = category.aggregate;
    return DiagnosticStatusBadge(
      label: _aggregateLabel(aggregate, category, l10n),
      status: aggregate,
      dense: true,
    );
  }

  String _aggregateLabel(
    DiagnosticItemStatus status,
    DiagnosticCategoryState category,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case DiagnosticItemStatus.healthy:
        return l10n.diagnosticCategoryAllHealthy;
      case DiagnosticItemStatus.warning:
        return l10n.diagnosticCategoryHasWarnings;
      case DiagnosticItemStatus.unhealthy:
        final count = category.items
            .where((i) => i.status == DiagnosticItemStatus.unhealthy)
            .length;
        return l10n.systemDiagnosticsStatusIssues(count);
      case DiagnosticItemStatus.probing:
        return l10n.diagnosticStatusProbing;
      case DiagnosticItemStatus.blocked:
        return l10n.diagnosticCategoryWaitingDependency;
      case DiagnosticItemStatus.disabled:
        return l10n.systemMaintenanceDisabled;
      case DiagnosticItemStatus.notTested:
        return l10n.systemDiagnosticsStatusNotChecked;
    }
  }
}
