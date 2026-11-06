import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';

/// 时刻筛选所有 section 的纵向 Column：内容类型 + 排序。
///
/// 桌面玻璃筛选浮层和移动 [showMobileMomentFilterDrawer]
/// 都用它，避免双份维护。分节复用 `AppFilterOptionSection`——两边 chip
/// 的观感必须一致。
///
/// [keyPrefix] 让同一组分节在桌面 / 移动两个入口下产生不同的测试锚点。
class MomentFilterSectionGroup extends StatelessWidget {
  const MomentFilterSectionGroup({
    super.key,
    required this.kindFilter,
    required this.sortOrder,
    required this.onKindChanged,
    required this.onSortChanged,
    this.keyPrefix = 'moments',
  });

  final MomentKindFilter kindFilter;
  final MomentSortOrder sortOrder;
  final ValueChanged<MomentKindFilter> onKindChanged;
  final ValueChanged<MomentSortOrder> onSortChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterOptionSection<MomentKindFilter>(
          title: l10n.momentFilterKindTitle,
          options: MomentKindFilter.values,
          selectedValue: kindFilter,
          optionKeyBuilder: (value) => Key('$keyPrefix-kind-${value.apiValue}'),
          labelBuilder: (value) => value.label(l10n),
          onSelected: onKindChanged,
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterOptionSection<MomentSortOrder>(
          title: l10n.momentFilterSortTitle,
          options: MomentSortOrder.values,
          selectedValue: sortOrder,
          optionKeyBuilder: (value) => Key(
            '$keyPrefix-sort-'
            '${value == MomentSortOrder.latest ? 'latest' : 'earliest'}',
          ),
          labelBuilder: (value) => value.label(l10n),
          onSelected: onSortChanged,
        ),
      ],
    );
  }
}

/// 弹出移动端时刻筛选底部抽屉。内容与桌面玻璃筛选浮层**完全
/// 一致**（同一个 [MomentFilterSectionGroup]），**即时生效**。
///
/// 类型与排序都是必选其一、没有「恢复默认」语义，故不带 footer——对齐榜单。
Future<void> showMobileMomentFilterDrawer(
  BuildContext context, {
  required MomentKindFilter kindFilter,
  required MomentSortOrder sortOrder,
  required ValueChanged<MomentKindFilter> onKindChanged,
  required ValueChanged<MomentSortOrder> onSortChanged,
  String keyPrefix = 'mobile-moments',
}) {
  final current = MomentsFilter(kindFilter: kindFilter, sortOrder: sortOrder);
  var previous = current;
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-moments-filter-drawer'),
    maxHeightFactor: 0.6,
    builder: (sheetContext) => AppMobileFilterDrawer<MomentsFilter>(
      current: current,
      initial: MomentsFilter.initial,
      isDefault: (value) => value == MomentsFilter.initial,
      showResetFooter: false,
      scrollViewKey: const Key('mobile-moments-filter-scroll-view'),
      onChanged: (next) {
        if (next.kindFilter != previous.kindFilter) {
          onKindChanged(next.kindFilter);
        }
        if (next.sortOrder != previous.sortOrder) {
          onSortChanged(next.sortOrder);
        }
        previous = next;
      },
      contentBuilder: (context, local, onApply) => MomentFilterSectionGroup(
        kindFilter: local.kindFilter,
        sortOrder: local.sortOrder,
        onKindChanged: (next) => onApply(local.copyWith(kindFilter: next)),
        onSortChanged: (next) => onApply(local.copyWith(sortOrder: next)),
        keyPrefix: keyPrefix,
      ),
    ),
  );
}
