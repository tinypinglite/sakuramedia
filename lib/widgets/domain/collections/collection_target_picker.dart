import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_header.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 从一个合集列表里选一个目标合集。返回选中的合集；取消返回 `null`。
///
/// 只负责「选中并返回」，实际成员写入由调用方执行（批量加入合集场景）。
/// 切片、时刻、视频三处的「加入合集」选择器共用此组件，各域只提供数据源、
/// 行文案和「新建合集」入口；数据源经 [watchCollections] 监听各自 overview
/// provider，与列表页共享缓存。
Future<T?> showCollectionTargetPicker<T extends Object>({
  required BuildContext context,
  required AsyncValue<List<T>> Function(WidgetRef ref) watchCollections,
  required int Function(T value) idOf,
  required String Function(T value) nameOf,
  required String Function(T value) countTextOf,
  required String optionKeyPrefix,
  required Future<T?> Function(BuildContext context, bool isDrawer) onCreate,
  int? excludedCollectionId,
  AppAdaptiveModalVariant variant = AppAdaptiveModalVariant.auto,
  Key? drawerKey,
  String? title,
  String? createButtonLabel,
}) {
  return showAppAdaptiveModal<T>(
    context: context,
    variant: variant,
    drawerKey: drawerKey,
    desktopWidth: 420,
    mobileMaxHeightFactor: 0.7,
    showDesktopCloseButton: false,
    builder: (_) => _CollectionTargetPicker<T>(
      watchCollections: watchCollections,
      idOf: idOf,
      nameOf: nameOf,
      countTextOf: countTextOf,
      optionKeyPrefix: optionKeyPrefix,
      onCreate: onCreate,
      excludedCollectionId: excludedCollectionId,
      title: title,
      createButtonLabel: createButtonLabel,
    ),
  );
}

class _CollectionTargetPicker<T extends Object> extends ConsumerStatefulWidget {
  const _CollectionTargetPicker({
    required this.watchCollections,
    required this.idOf,
    required this.nameOf,
    required this.countTextOf,
    required this.optionKeyPrefix,
    required this.onCreate,
    required this.excludedCollectionId,
    required this.title,
    required this.createButtonLabel,
  });

  final AsyncValue<List<T>> Function(WidgetRef ref) watchCollections;
  final int Function(T value) idOf;
  final String Function(T value) nameOf;
  final String Function(T value) countTextOf;

  /// 行测试锚点前缀，最终 Key 为 `<前缀><合集 id>`。
  final String optionKeyPrefix;

  /// 「新建合集并加入」入口，返回新建的合集；[isDrawer] 为当前弹层壳形态。
  final Future<T?> Function(BuildContext context, bool isDrawer) onCreate;

  /// 不在列表中显示的合集 id（从合集详情页发起「加入其它合集」时排除自身）。
  final int? excludedCollectionId;

  final String? title;
  final String? createButtonLabel;

  @override
  ConsumerState<_CollectionTargetPicker<T>> createState() =>
      _CollectionTargetPickerState<T>();
}

class _CollectionTargetPickerState<T extends Object>
    extends ConsumerState<_CollectionTargetPicker<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  bool get _isBottomDrawer => AppAdaptiveModalShellScope.maybeIsDrawer(context);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createAndPick() async {
    final created = await widget.onCreate(context, _isBottomDrawer);
    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final collectionsAsync = widget.watchCollections(ref);
    return Column(
      mainAxisSize: _isBottomDrawer ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPickerHeader(
          title: widget.title ?? l10n.widgetCollectionPickerTitle,
          searchController: _searchController,
          searchFieldKey: const Key('collection-target-picker-search-field'),
          searchHintText: l10n.widgetCollectionPickerSearchHint,
          onSearchChanged: (value) =>
              setState(() => _keyword = value.trim().toLowerCase()),
          clearSearchKey: const Key('collection-target-picker-search-clear'),
          onClose: () => Navigator.of(context).pop(),
          closeKey: const Key('collection-target-picker-close-button'),
        ),
        SizedBox(height: spacing.lg),
        AppPickerListFrame(
          isDrawer: _isBottomDrawer,
          child: _buildBody(context, collectionsAsync),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<T>> collectionsAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    if (collectionsAsync.isLoading && !collectionsAsync.hasValue) {
      return const AppPickerIosState(loading: true);
    }
    if (collectionsAsync.hasError && !collectionsAsync.hasValue) {
      return _buildStateWithCreate(
        context,
        AppPickerIosState(
          message: apiErrorMessage(
            collectionsAsync.error!,
            fallback: l10n.widgetCollectionPickerLoadFailed,
            l10n: l10n,
          ),
        ),
      );
    }
    final allCollections = collectionsAsync.value ?? <T>[];
    final excluded = widget.excludedCollectionId;
    var collections = excluded == null
        ? allCollections
        : allCollections
              .where((collection) => widget.idOf(collection) != excluded)
              .toList(growable: false);
    if (_keyword.isNotEmpty) {
      collections = collections
          .where(
            (collection) =>
                widget.nameOf(collection).toLowerCase().contains(_keyword),
          )
          .toList(growable: false);
    }
    if (collections.isEmpty) {
      return _buildStateWithCreate(
        context,
        AppPickerIosState(
          message: allCollections.isEmpty
              ? l10n.widgetCollectionPickerEmpty
              : l10n.widgetCollectionPickerNoMatch,
        ),
      );
    }
    return SingleChildScrollView(
      child: AppPickerIosSection(
        children: [
          for (final collection in collections)
            AppPickerIosRow(
              optionKey: Key(
                '${widget.optionKeyPrefix}${widget.idOf(collection)}',
              ),
              title: widget.nameOf(collection),
              trailingText: widget.countTextOf(collection),
              trailingIcon: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.appTextPalette.muted,
              ),
              onTap: () => Navigator.of(context).pop(collection),
            ),
          _buildCreateRow(context, l10n),
        ],
      ),
    );
  }

  Widget _buildCreateRow(BuildContext context, AppLocalizations l10n) {
    final accent = Theme.of(context).colorScheme.primary;
    return AppPickerIosRow(
      leading: Icon(Icons.add_circle_outline_rounded, color: accent),
      title:
          widget.createButtonLabel ?? l10n.widgetCollectionPickerCreateAndAdd,
      titleColor: accent,
      onTap: _createAndPick,
      optionKey: const Key('collection-target-picker-create-button'),
    );
  }

  Widget _buildStateWithCreate(BuildContext context, Widget state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          state,
          AppPickerIosSection(
            children: [_buildCreateRow(context, AppLocalizations.of(context))],
          ),
        ],
      ),
    );
  }
}
