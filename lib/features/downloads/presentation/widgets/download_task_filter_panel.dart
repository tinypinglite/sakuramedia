import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/downloads/presentation/download_task_filter_state.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';

/// 下载任务筛选内容：番号搜索（回车提交）+ 状态/客户端玻璃分段。
///
/// 桌面筛选浮层与移动筛选抽屉共用这一份内容，避免两端文案和选项漂移。
/// 搜索输入沿用项目其它筛选栏习惯——**不做打字 debounce**，仅回车提交。
class DownloadTaskFilterSections extends HookWidget {
  const DownloadTaskFilterSections({
    super.key,
    required this.filter,
    required this.clientOptions,
    required this.onChanged,
    this.keyPrefix = 'download-filter',
    this.showTitle = false,
    this.searchLabel,
    this.searchToSectionSpacing,
  });

  final DownloadTaskFilterState filter;
  final List<DownloadClientOption> clientOptions;
  final ValueChanged<DownloadTaskFilterState> onChanged;

  /// 筛选控件 Key 前缀；桌面与移动各用一套，便于测试分别定位。
  final String keyPrefix;

  /// 移动抽屉在内容顶部显示标题；桌面浮层不显示。
  final bool showTitle;

  final String? searchLabel;
  final double? searchToSectionSpacing;

  @override
  Widget build(BuildContext context) {
    final searchController = useTextEditingController(text: filter.search);
    // 若外部通过其它入口（如「清除筛选」）改了 filter.search，同步进输入框；
    // 用户正在输入时（controller.text 与最近同步值不一致）避免打断。
    final attachedSearch = useRef<String>(filter.search);
    useEffect(() {
      final external = filter.search;
      if (external != attachedSearch.value &&
          external != searchController.text) {
        searchController.text = external;
      }
      attachedSearch.value = external;
      return null;
    }, [filter.search]);

    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final clientNames = <int, String>{
      for (final option in clientOptions) option.id: option.name,
    };
    final clientIds = <int?>{
      null,
      ...clientNames.keys,
      if (filter.clientId != null) filter.clientId,
    }.toList(growable: false);

    void submitSearch(String value) {
      final next = filter.copyWith(search: value.trim());
      attachedSearch.value = next.search;
      onChanged(next);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          Text(
            l10n.downloadFilterTitle,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.lg),
        ],
        AppTextField(
          fieldKey: Key('$keyPrefix-search'),
          controller: searchController,
          label: searchLabel,
          hintText: l10n.downloadSearchByMovieNumber,
          textInputAction: TextInputAction.search,
          onFieldSubmitted: submitSearch,
          enabled: true,
        ),
        SizedBox(height: searchToSectionSpacing ?? spacing.lg),
        AppFilterChoiceSection<DownloadTaskStateFilter>(
          title: l10n.downloadStateFilterLabel,
          controlKey: Key('$keyPrefix-state'),
          items: <AppSegmentedItem<DownloadTaskStateFilter>>[
            for (final value in DownloadTaskStateFilter.values)
              AppSegmentedItem(value: value, label: value.label(l10n)),
          ],
          selected: filter.stateFilter,
          onChanged: (value) => onChanged(filter.copyWith(stateFilter: value)),
        ),
        if (clientOptions.length >= 2) ...[
          SizedBox(height: spacing.lg),
          AppFilterChoiceSection<int?>(
            title: l10n.downloadClientFilterLabel,
            controlKey: Key('$keyPrefix-client'),
            items: <AppSegmentedItem<int?>>[
              for (final id in clientIds)
                AppSegmentedItem(
                  value: id,
                  label: id == null
                      ? l10n.downloadFilterAllClients
                      : clientNames[id] ?? l10n.downloadFilterClientSpecified,
                ),
            ],
            selected: filter.clientId,
            onChanged: (value) => onChanged(filter.copyWith(clientId: value)),
          ),
        ],
      ],
    );
  }
}

/// 移动端下载任务筛选底部抽屉：本地态 + 即时外发 + 重置 footer 由通用壳负责。
Future<void> showDownloadTaskFilterDrawer(
  BuildContext context, {
  required DownloadTaskFilterState current,
  required List<DownloadClientOption> clientOptions,
  required ValueChanged<DownloadTaskFilterState> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-download-filter-drawer'),
    maxHeightFactor: 0.6,
    builder: (_) => AppMobileFilterDrawer<DownloadTaskFilterState>(
      current: current,
      initial: DownloadTaskFilterState.initial,
      isDefault: (value) => value.isDefault,
      onChanged: onChanged,
      scrollViewKey: const Key('mobile-download-filter-scroll-view'),
      contentBuilder: (context, local, onApply) => DownloadTaskFilterSections(
        filter: local,
        clientOptions: clientOptions,
        onChanged: onApply,
        keyPrefix: 'mobile-download-filter',
        showTitle: true,
        searchLabel: AppLocalizations.of(context).downloadMovieNumberLabel,
        searchToSectionSpacing: context.appSpacing.md,
      ),
    ),
  );
}

String downloadTaskFilterSummary(
  DownloadTaskFilterState filter,
  List<DownloadClientOption> clientOptions,
  AppLocalizations l10n,
) {
  final values = <String>[filter.stateFilter.label(l10n)];
  if (filter.normalizedSearch.isNotEmpty) {
    values.add(filter.normalizedSearch);
  }
  final clientId = filter.clientId;
  if (clientId != null) {
    final client = clientOptions.where((item) => item.id == clientId);
    values.add(
      client.isEmpty ? l10n.downloadFilterClientSpecified : client.first.name,
    );
  }
  return values.join(' · ');
}
