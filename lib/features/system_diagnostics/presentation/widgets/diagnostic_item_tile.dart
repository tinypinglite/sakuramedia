import 'package:flutter/material.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/diagnostic_fix_button.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/diagnostic_status_badge.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 分组卡片里的一行诊断项。
///
/// - 顶行：状态徽章 + 名称/summary + 展开箭头
/// - 展开区（AnimatedSize）：可能原因 / 怎么改 / 影响 三段 + 「去修复」按钮 + 可选的
///   「查看诊断详情」入口（用于下载器复用现有的详情 dialog）
class DiagnosticItemTile extends StatefulWidget {
  const DiagnosticItemTile({
    super.key,
    required this.item,
    this.detailButtonLabel,
    this.onOpenDetail,
    this.initiallyExpanded = false,
  });

  final DiagnosticItemState item;
  final String? detailButtonLabel;
  final VoidCallback? onOpenDetail;

  /// 首次渲染是否已经展开。异常项默认展开，让用户不用二次点击。
  final bool initiallyExpanded;

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
    if (widget.onOpenDetail != null) return true;
    return false;
  }

  bool _shouldAutoExpand(DiagnosticItemState item) {
    return item.status == DiagnosticItemStatus.unhealthy ||
        item.status == DiagnosticItemStatus.warning;
  }

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded || _shouldAutoExpand(widget.item);
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
    final item = widget.item;
    final badgeLabel = _statusBadgeLabel(item.status);

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
            tooltip: _expanded ? '收起详情' : '展开详情',
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
            child:
                _expanded && _canExpand
                    ? _buildDetail(context)
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(BuildContext context) {
    final spacing = context.appSpacing;
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

    addBlock('可能原因', item.cause);
    addBlock('怎么改', item.fixHint);

    final hasAction = item.fixTarget != null || widget.onOpenDetail != null;
    if (hasAction) {
      blocks.add(
        Padding(
          padding: EdgeInsets.only(top: spacing.md),
          child: Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: <Widget>[
              if (item.fixTarget != null)
                DiagnosticFixButton(target: item.fixTarget!),
              if (widget.onOpenDetail != null)
                AppTextButton(
                  label: widget.detailButtonLabel ?? '查看诊断详情',
                  size: AppTextButtonSize.small,
                  onPressed: widget.onOpenDetail,
                ),
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

  String _statusBadgeLabel(DiagnosticItemStatus status) {
    switch (status) {
      case DiagnosticItemStatus.notTested:
        return '未检测';
      case DiagnosticItemStatus.probing:
        return '检测中';
      case DiagnosticItemStatus.healthy:
        return '正常';
      case DiagnosticItemStatus.warning:
        return '告警';
      case DiagnosticItemStatus.unhealthy:
        return '异常';
      case DiagnosticItemStatus.blocked:
        final by = widget.item.blockedByLabel;
        return by == null || by.isEmpty ? '未就绪' : '待 $by';
    }
  }

  String _decorateSummaryWithElapsed(DiagnosticItemState item) {
    final summary = item.summary ?? '';
    if (item.elapsedMs == null) return summary;
    if (summary.isEmpty) return '${item.elapsedMs}ms';
    return '$summary · ${item.elapsedMs}ms';
  }
}
