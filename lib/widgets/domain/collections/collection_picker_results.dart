import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_header.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 合集选择器的 key 前缀和空态文案。
typedef CollectionPickerChrome = ({String keyPrefix, String emptyMessage});

/// 合集选择器共享的搜索输入与关键字。
mixin CollectionPickerSearchState<T extends StatefulWidget> on State<T> {
  final searchController = TextEditingController();
  String searchKeyword = '';

  void updateSearch(String value) => searchKeyword = value.trim().toLowerCase();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

/// 合集选择器共享的搜索框、列表壳和 loading / error / empty 状态。
///
/// 行内容和空态附加行由调用方通过 [rowsBuilder] 提供，返回类型仍由弹层负责。
class CollectionPickerResults<T extends Object> extends StatefulWidget {
  const CollectionPickerResults({
    super.key,
    required this.collections,
    required this.chrome,
    required this.nameOf,
    required this.rowsBuilder,
    this.where,
  });

  final AsyncValue<List<T>> collections;
  final CollectionPickerChrome chrome;
  final String Function(T value) nameOf;
  final bool Function(T value)? where;

  /// 生成过滤后的列表行；空/错误状态由本组件统一包裹。
  final List<Widget> Function(BuildContext context, List<T> visible)
  rowsBuilder;

  @override
  State<CollectionPickerResults<T>> createState() =>
      _CollectionPickerResultsState<T>();
}

class _CollectionPickerResultsState<T extends Object>
    extends State<CollectionPickerResults<T>>
    with CollectionPickerSearchState<CollectionPickerResults<T>> {
  List<T> _visible(List<T> all) {
    final keyword = searchKeyword;
    return all
        .where(
          (value) =>
              (widget.where?.call(value) ?? true) &&
              (keyword.isEmpty ||
                  widget.nameOf(value).toLowerCase().contains(keyword)),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final isDrawer = AppAdaptiveModalShellScope.maybeIsDrawer(context);
    final body = widget.collections.when(
      skipLoadingOnReload: true,
      skipError: true,
      loading: () => const AppPickerIosState(loading: true),
      error: (error, _) => _body(
        context,
        <T>[],
        AppPickerIosState(
          message: apiErrorMessage(
            error,
            fallback: l10n.widgetCollectionPickerLoadFailed,
            l10n: l10n,
          ),
        ),
      ),
      data: (all) {
        final visible = _visible(all);
        return _body(
          context,
          visible,
          visible.isEmpty
              ? AppPickerIosState(
                  message: all.isEmpty
                      ? widget.chrome.emptyMessage
                      : l10n.widgetCollectionPickerNoMatch,
                )
              : null,
        );
      },
    );
    return Column(
      mainAxisSize: isDrawer ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDrawer) SizedBox(height: spacing.lg),
        AppPickerHeader(
          searchController: searchController,
          searchFieldKey: Key('${widget.chrome.keyPrefix}-search-field'),
          searchHintText: l10n.widgetCollectionPickerSearchHint,
          onSearchChanged: (value) => setState(() => updateSearch(value)),
          clearSearchKey: Key('${widget.chrome.keyPrefix}-search-clear'),
        ),
        SizedBox(height: spacing.lg),
        AppPickerListFrame(isDrawer: isDrawer, child: body),
      ],
    );
  }

  Widget _body(BuildContext context, List<T> visible, Widget? state) {
    final rows = widget.rowsBuilder(context, visible);
    if (rows.isEmpty) {
      return state ?? const SizedBox.shrink();
    }
    final section = AppPickerIosSection(children: rows);
    return SingleChildScrollView(
      key: Key('${widget.chrome.keyPrefix}-list'),
      child: state == null
          ? section
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [state, section],
            ),
    );
  }
}
