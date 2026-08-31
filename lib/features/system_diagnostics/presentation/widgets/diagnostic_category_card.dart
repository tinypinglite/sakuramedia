import 'package:flutter/material.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_category_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_state.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_item_status.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/diagnostic_item_tile.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/diagnostic_status_badge.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 一张分组卡片。标题右侧带一个汇总徽章；内容是一串 [DiagnosticItemTile]。
///
/// 没有用 `AppSettingsGroup`：它虽然也做"卡片 + 行间分隔线"，但不支持标题旁的
/// 汇总徽章（只有纯文字 `header`），套进 `AppContentCard` 又会叠出两层卡片背景/
/// 边框/阴影——这里的手写 `Divider` 循环是刻意保留的最简单写法。
class DiagnosticCategoryCard extends StatelessWidget {
  const DiagnosticCategoryCard({
    super.key,
    required this.category,
    this.itemDetailBuilder,
  });

  final DiagnosticCategoryState category;

  /// 用于给下载器 tile 挂上「查看诊断详情」按钮 —— 复用现有的
  /// `DownloadClientTestResultDialog` / `DownloadClientStorageTestResultDialog`。
  /// 其它 kind 返回 null 即可。
  final DiagnosticItemDetailAction? Function(DiagnosticItemState item)?
  itemDetailBuilder;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppContentCard(
      title: category.label,
      headerBottomSpacing: spacing.md,
      headerTrailing: _buildAggregateBadge(),
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
    final action = itemDetailBuilder?.call(item);
    return DiagnosticItemTile(
      key: Key('diagnostic-item-${item.itemKey}'),
      item: item,
      detailButtonLabel: action?.label,
      onOpenDetail: action?.onOpen,
    );
  }

  Widget _buildAggregateBadge() {
    final aggregate = category.aggregate;
    return DiagnosticStatusBadge(
      label: _aggregateLabel(aggregate, category),
      status: aggregate,
      dense: true,
    );
  }

  String _aggregateLabel(
    DiagnosticItemStatus status,
    DiagnosticCategoryState category,
  ) {
    switch (status) {
      case DiagnosticItemStatus.healthy:
        return '全部正常';
      case DiagnosticItemStatus.warning:
        return '存在告警';
      case DiagnosticItemStatus.unhealthy:
        final count =
            category.items
                .where((i) => i.status == DiagnosticItemStatus.unhealthy)
                .length;
        return '$count 项异常';
      case DiagnosticItemStatus.probing:
        return '检测中';
      case DiagnosticItemStatus.blocked:
        return '等待前置';
      case DiagnosticItemStatus.notTested:
        return '未检测';
    }
  }
}

/// 让 tile 上多一个「查看诊断详情」入口的描述值对象。
class DiagnosticItemDetailAction {
  const DiagnosticItemDetailAction({required this.label, required this.onOpen});

  final String label;
  final VoidCallback onOpen;
}
