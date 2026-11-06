import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sakuramedia/features/subscriptions/presentation/movie_subscription_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// 订阅管理列表的筛选面板内容：搜索。
///
/// 桌面玻璃筛选浮层与移动底部抽屉共用同一份，避免双份维护。
/// 底栏 / 重置按钮由调用方附加（`AppGlassFilterFooter`）。
///
/// 状态分段签**不在**这里——它是页面的一级维度、自带计数，收进筛选面板等于把最
/// 重要的入口藏起来。排序也不在这里，见 `MovieSubscriptionSortMenuButton`。
class MovieSubscriptionFilterSectionGroup extends HookWidget {
  const MovieSubscriptionFilterSectionGroup({
    super.key,
    required this.filterState,
    required this.onChanged,
  });

  final MovieSubscriptionFilterState filterState;
  final ValueChanged<MovieSubscriptionFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    final searchController = useTextEditingController();

    // 外部改动（面板底栏「重置」、切签后清空）要反映回输入框；用户自己敲进去的
    // 内容提交后与 filterState 一致，这个赋值不会触发、光标不受影响。
    useEffect(() {
      if (searchController.text != filterState.search) {
        searchController.text = filterState.search;
      }
      return null;
    }, <Object?>[filterState.search]);

    void submitSearch(String raw) {
      final next = filterState.copyWith(search: raw.trim());
      if (next == filterState) return;
      onChanged(next);
    }

    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          fieldKey: const Key('movie-subscriptions-filter-search-field'),
          controller: searchController,
          label: l10n.subscriptionFilterSearchLabel,
          hintText: l10n.subscriptionFilterSearchHint,
          textInputAction: TextInputAction.search,
          prefix: Icon(
            Icons.search_rounded,
            size: context.appComponentTokens.iconSizeXs,
            color: context.appTextPalette.muted,
          ),
          // 有内容才给清除按钮：空态挂一个禁用的 X 只是噪音。
          suffix: filterState.hasSearch
              ? AppIconButton(
                  key: const Key(
                    'movie-subscriptions-filter-search-clear-button',
                  ),
                  icon: const Icon(Icons.close_rounded),
                  size: AppIconButtonSize.mini,
                  tooltip: l10n.subscriptionFilterSearchClearTooltip,
                  onPressed: () => submitSearch(''),
                )
              : null,
          tightSuffix: true,
          onFieldSubmitted: submitSearch,
        ),
      ],
    );
  }
}
