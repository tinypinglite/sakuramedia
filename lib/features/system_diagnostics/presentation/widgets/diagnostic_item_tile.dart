import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/diagnostic_fix_button.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/diagnostic_status_badge.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';

/// 分组卡片里的一行诊断项。
///
/// - 顶行：状态徽章 + 名称/summary + 展开箭头
/// - 展开区（AnimatedSize）：可能原因 / 怎么改 / 影响 三段 + 「去修复」按钮
class DiagnosticItemTile extends StatefulWidget {
  const DiagnosticItemTile({super.key, required this.item});

  final DiagnosticItemState item;

  @override
  State<DiagnosticItemTile> createState() => _DiagnosticItemTileState();
}

class _DiagnosticItemTileState extends State<DiagnosticItemTile> {
  late bool _expanded;

  bool get _canExpand {
    final item = widget.item;
    if (item.cause != null && item.cause!.isNotEmpty) return true;
    if (item.fixHint != null && item.fixHint!.isNotEmpty) return true;
    if (item.fixTarget != null) return true;
    return false;
  }

  bool _shouldAutoExpand(DiagnosticItemState item) {
    return item.status == DiagnosticItemStatus.unhealthy ||
        item.status == DiagnosticItemStatus.warning;
  }

  @override
  void initState() {
    super.initState();
    _expanded = _shouldAutoExpand(widget.item);
  }

  @override
  void didUpdateWidget(DiagnosticItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // status 从 not-tested/probing → unhealthy/warning 时自动展开，方便用户直接看
    // 到失败原因；反向或已经手动折叠的话不干扰。
    if (widget.item.status != oldWidget.item.status &&
        _shouldAutoExpand(widget.item) &&
        !_shouldAutoExpand(oldWidget.item)) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    final badgeLabel = _statusBadgeLabel(l10n, item);

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DiagnosticStatusBadge(label: badgeLabel, status: item.status),
        SizedBox(width: spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.displayName,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.primary,
                ),
              ),
              if (item.summary != null && item.summary!.isNotEmpty) ...[
                SizedBox(height: spacing.xs / 2),
                Text(
                  _decorateSummaryWithElapsed(item),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_canExpand)
          AppIconButton(
            size: AppIconButtonSize.mini,
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            tooltip: _expanded
                ? l10n.diagnosticCollapseDetails
                : l10n.diagnosticExpandDetails,
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row,
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded && _canExpand
                ? _buildDetail(context)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    final blocks = <Widget>[];

    void addBlock(String label, String? content) {
      if (content == null || content.isEmpty) return;
      blocks.add(
        Padding(
          padding: EdgeInsets.only(top: spacing.sm),
          child: RichText(
            text: TextSpan(
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: '$label：',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                TextSpan(text: content),
              ],
            ),
          ),
        ),
      );
    }

    addBlock(l10n.diagnosticDetailCause, item.cause);
    addBlock(l10n.diagnosticDetailFix, item.fixHint);

    if (item.fixTarget != null) {
      blocks.add(
        Padding(
          padding: EdgeInsets.only(top: spacing.md),
          child: Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: <Widget>[
              if (item.fixTarget != null)
                DiagnosticFixButton(target: item.fixTarget!),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: spacing.xxxl, right: spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks,
      ),
    );
  }

  String _statusBadgeLabel(AppLocalizations l10n, DiagnosticItemState item) {
    switch (item.status) {
      case DiagnosticItemStatus.disabled:
        return l10n.systemMaintenanceDisabled;
      case DiagnosticItemStatus.notTested:
        return l10n.systemDiagnosticsStatusNotChecked;
      case DiagnosticItemStatus.probing:
        return l10n.diagnosticStatusProbing;
      case DiagnosticItemStatus.healthy:
        return l10n.diagnosticStatusHealthy;
      case DiagnosticItemStatus.warning:
        return l10n.diagnosticStatusWarning;
      case DiagnosticItemStatus.unhealthy:
        return l10n.diagnosticStatusUnhealthy;
      case DiagnosticItemStatus.blocked:
        final by = item.blockedByLabel;
        return by == null || by.isEmpty
            ? l10n.diagnosticStatusNotReady
            : l10n.diagnosticStatusBlockedBy(by);
    }
  }

  String _decorateSummaryWithElapsed(DiagnosticItemState item) {
    final summary = item.summary ?? '';
    if (item.elapsedMs == null) return summary;
    if (summary.isEmpty) return '${item.elapsedMs}ms';
    return '$summary · ${item.elapsedMs}ms';
  }
}
