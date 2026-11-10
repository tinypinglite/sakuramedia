import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/forms/app_glass_search_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 单条内容“加入合集”的状态与展示适配。
///
/// 各业务域只提供数据源、展示适配和成员增删动作；搜索、勾选、乐观回滚和弹层形态由共享层统一。
class CollectionMembershipConfig<T> {
  const CollectionMembershipConfig({
    required this.keyPrefix,
    required this.searchHint,
    required this.createLabel,
    required this.emptyMessage,
    required this.noMatchMessage,
    required this.loadErrorFallback,
    required this.addErrorFallback,
    required this.removeErrorFallback,
    required this.loadCollections,
    required this.loadSelectedIds,
    required this.add,
    required this.remove,
    required this.createCollection,
    required this.idOf,
    required this.nameOf,
    this.countOf,
    this.trailingTextOf,
    this.blockWhileUpdating = true,
    this.optionKeyBuilder,
    this.dialogKey,
    this.drawerKey,
  });

  final String keyPrefix;
  final String searchHint;
  final String createLabel;
  final String emptyMessage;
  final String noMatchMessage;
  final String loadErrorFallback;
  final String addErrorFallback;
  final String removeErrorFallback;
  final Future<List<T>> Function(WidgetRef ref) loadCollections;
  final Future<Set<int>> Function(WidgetRef ref) loadSelectedIds;
  final Future<void> Function(WidgetRef ref, int collectionId) add;
  final Future<void> Function(WidgetRef ref, int collectionId) remove;
  final Future<T?> Function(BuildContext context, WidgetRef ref)
  createCollection;
  final int Function(T collection) idOf;
  final String Function(T collection) nameOf;
  final int? Function(T collection)? countOf;

  /// 覆盖行尾文案；返回非 null 时优先于 [countOf] 的数字展示。
  final String? Function(T collection)? trailingTextOf;

  /// 有更新请求进行中时是否阻塞整个列表。默认串行；关闭后仅禁用正在更新的行。
  final bool blockWhileUpdating;
  final Key Function(int collectionId)? optionKeyBuilder;
  final Key? dialogKey;
  final Key? drawerKey;

  Key get searchFieldKey => Key('$keyPrefix-search-field');
  Key get searchClearKey => Key('$keyPrefix-search-clear');
  Key get searchToggleKey => Key('$keyPrefix-search-toggle');
  Key get loadingKey => Key('$keyPrefix-loading');
  Key get retryKey => Key('$keyPrefix-retry');
  Key get listKey => Key('$keyPrefix-list');
  Key get selectedCountKey => Key('$keyPrefix-selected-count');
  Key get createKey => Key('$keyPrefix-create-button');

  Key optionKey(int collectionId) {
    return optionKeyBuilder?.call(collectionId) ??
        Key('$keyPrefix-option-$collectionId');
  }

  Key updatingKey(int collectionId) {
    return Key('$keyPrefix-updating-$collectionId');
  }
}

Future<void> showCollectionMembershipDialog<T>({
  required BuildContext context,
  required CollectionMembershipConfig<T> config,
  AppAdaptiveModalVariant variant = AppAdaptiveModalVariant.auto,
}) async {
  await showAppAdaptiveModal<void>(
    context: context,
    variant: variant,
    dialogKey: config.dialogKey,
    drawerKey: config.drawerKey,
    desktopWidth: context.appComponentTokens.playlistDialogWidth,
    mobileMaxHeightFactor: 0.7,
    showDesktopCloseButton: true,
    builder: (_) => CollectionMembershipDialog<T>(config: config),
  );
}

class CollectionMembershipDialog<T> extends ConsumerStatefulWidget {
  const CollectionMembershipDialog({super.key, required this.config});

  final CollectionMembershipConfig<T> config;

  @override
  ConsumerState<CollectionMembershipDialog<T>> createState() =>
      _CollectionMembershipDialogState<T>();
}

class _CollectionMembershipDialogState<T>
    extends ConsumerState<CollectionMembershipDialog<T>> {
  List<T> _collections = <T>[];
  final Set<int> _selectedIds = <int>{};
  final Set<int> _updatingIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _keyword = '';
  bool _isSearchExpanded = false;
  bool _isLoading = true;
  String? _errorMessage;

  CollectionMembershipConfig<T> get _config => widget.config;

  bool get _isDrawer => AppAdaptiveModalShellScope.maybeIsDrawer(context);

  bool get _blocksInput =>
      _config.blockWhileUpdating && _updatingIds.isNotEmpty;

  List<T> get _visibleCollections {
    if (_keyword.isEmpty) {
      return _collections;
    }
    return _collections
        .where(
          (collection) =>
              _config.nameOf(collection).toLowerCase().contains(_keyword),
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final collectionsFuture = _config.loadCollections(ref);
      final selectedFuture = _config.loadSelectedIds(ref);
      final collections = await collectionsFuture;
      final selectedIds = await selectedFuture;
      if (!mounted) {
        return;
      }
      setState(() {
        _collections = collections;
        _selectedIds
          ..clear()
          ..addAll(selectedIds);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = apiErrorMessage(
          error,
          fallback: _config.loadErrorFallback,
          l10n: l10n,
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AbsorbPointer(
      absorbing: _blocksInput,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isDrawer) SizedBox(height: spacing.lg),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            child: _buildSearchRow(context),
          ),
          SizedBox(height: spacing.sm),
          AppPickerListFrame(
            isDrawer: _isDrawer,
            fillHeight: false,
            child: _buildList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final accent = Theme.of(context).colorScheme.primary;
    final expanded = _isSearchExpanded;
    return Row(
      children: [
        Expanded(
          child: expanded
              ? AppGlassSearchField(
                  controller: _searchController,
                  hintText: _config.searchHint,
                  fieldKey: _config.searchFieldKey,
                  clearKey: _config.searchClearKey,
                  focusNode: _searchFocusNode,
                  onChanged: (value) =>
                      setState(() => _keyword = value.trim().toLowerCase()),
                )
              : Text(
                  l10n.commonSelectedCount(_selectedIds.length),
                  key: _config.selectedCountKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.muted,
                  ),
                ),
        ),
        SizedBox(width: spacing.sm),
        AppIconButton(
          key: _config.searchToggleKey,
          tooltip: expanded ? l10n.commonCollapseSearch : _config.searchHint,
          semanticLabel: expanded
              ? l10n.commonCollapseSearch
              : _config.searchHint,
          size: AppIconButtonSize.regular,
          iconColor: expanded ? accent : context.appTextPalette.secondary,
          icon: const Icon(Icons.search_rounded),
          onPressed: _toggleSearch,
        ),
        SizedBox(width: spacing.xs),
        Flexible(
          child: AppPickerIosActionButton(
            key: _config.createKey,
            label: _config.createLabel,
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _isLoading || _blocksInput ? null : _createAndAdd,
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final List<Widget> children;
    if (_isLoading) {
      children = <Widget>[
        AppPickerIosState(key: _config.loadingKey, loading: true),
      ];
    } else if (_errorMessage != null) {
      children = <Widget>[
        AppPickerIosState(
          message: _errorMessage!,
          onRetry: () => _load(showLoading: true),
          retryKey: _config.retryKey,
        ),
      ];
    } else if (_collections.isEmpty) {
      children = <Widget>[AppPickerIosState(message: _config.emptyMessage)];
    } else {
      final visibleCollections = _visibleCollections;
      children = visibleCollections.isEmpty
          ? <Widget>[AppPickerIosState(message: _config.noMatchMessage)]
          : <Widget>[
              for (final collection in visibleCollections)
                AppPickerIosRow(
                  selected: _selectedIds.contains(_config.idOf(collection)),
                  showCheckmark: true,
                  enabled: _config.blockWhileUpdating
                      ? !_blocksInput
                      : !_updatingIds.contains(_config.idOf(collection)),
                  busy: _updatingIds.contains(_config.idOf(collection)),
                  busyKey: _config.updatingKey(_config.idOf(collection)),
                  onTap: () => _toggle(collection),
                  title: _config.nameOf(collection),
                  trailingText: _trailingText(collection),
                  optionKey: _config.optionKey(_config.idOf(collection)),
                ),
            ];
    }
    return CustomScrollView(
      key: _config.listKey,
      shrinkWrap: true,
      slivers: [
        SliverToBoxAdapter(child: AppPickerIosSection(children: children)),
      ],
    );
  }

  String? _trailingText(T collection) {
    final trailingText = _config.trailingTextOf?.call(collection);
    if (trailingText != null) {
      return trailingText;
    }
    final count = _config.countOf?.call(collection);
    return count != null && count > 0 ? formatAppCount(count) : null;
  }

  void _toggleSearch() {
    if (_isSearchExpanded) {
      _collapseSearch();
      return;
    }
    setState(() => _isSearchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _collapseSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearchExpanded = false;
      _keyword = '';
    });
  }

  Future<void> _toggle(T collection) async {
    _searchFocusNode.unfocus();
    final l10n = AppLocalizations.of(context);
    final collectionId = _config.idOf(collection);
    final wasSelected = _selectedIds.contains(collectionId);
    setState(() {
      _updatingIds.add(collectionId);
      if (wasSelected) {
        _selectedIds.remove(collectionId);
      } else {
        _selectedIds.add(collectionId);
      }
    });
    try {
      if (wasSelected) {
        await _config.remove(ref, collectionId);
      } else {
        await _config.add(ref, collectionId);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          if (wasSelected) {
            _selectedIds.add(collectionId);
          } else {
            _selectedIds.remove(collectionId);
          }
        });
      }
      showToast(
        apiErrorMessage(
          error,
          fallback: wasSelected
              ? _config.removeErrorFallback
              : _config.addErrorFallback,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _updatingIds.remove(collectionId));
      }
    }
  }

  Future<void> _createAndAdd() async {
    _searchFocusNode.unfocus();
    final created = await _config.createCollection(context, ref);
    if (!mounted || created == null) {
      return;
    }
    setState(() {
      _collections = <T>[created, ..._collections];
      _errorMessage = null;
    });
    await _toggle(created);
  }
}
