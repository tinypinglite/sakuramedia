import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_header.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

const int collectionMemberPickerPageSize = 24;
const Duration _pickerSearchDebounce = Duration(milliseconds: 300);

/// 合集详情内“往合集里挑成员”的共享状态与页面骨架。
///
/// 各业务域只提供查询页、成员 id、行渲染、空态和增删持久化；分页、搜索防抖、
/// 只看未加入、乐观回滚和弹窗/抽屉布局由这里统一。
mixin CollectionMemberPickerStateMixin<W extends ConsumerStatefulWidget, T>
    on ConsumerState<W> {
  final ScrollController pickerScrollController = ScrollController();
  final TextEditingController pickerSearchController = TextEditingController();
  final List<T> pickerItems = <T>[];
  late final Set<int> pickerMemberIds;
  final Set<int> pickerUpdatingIds = <int>{};

  Timer? _pickerSearchTimer;
  bool pickerIsLoading = true;
  bool pickerIsLoadingMore = false;
  bool pickerOnlyUnadded = true;
  String pickerKeyword = '';
  int _pickerNextOffset = 0;
  int _pickerTotal = 0;
  String? pickerErrorMessage;
  String? _pickerLoadMoreErrorMessage;
  int _pickerRequestSeq = 0;

  String get pickerKeyPrefix;
  String get pickerSearchHint;
  String get pickerOnlyUnaddedLabel;
  String get pickerLoadErrorFallback;
  Set<int> get pickerInitialMemberIds;
  List<T> get pickerPlaceholders;

  Future<PaginatedResponseDto<T>> fetchPickerPage(int page);
  int pickerIdOf(T item);
  Widget buildPickerOption(BuildContext context, T item);
  Widget buildPickerEmptyState(BuildContext context);
  String pickerCountLabel(int selectedCount, int total);
  String pickerMembershipErrorFallback(bool isMember);
  String pickerMembershipSuccessToast(bool isMember);
  Future<void> persistPickerMembership(T item, bool isMember);

  Key pickerKey(String suffix) => Key('$pickerKeyPrefix-$suffix');

  Key pickerOptionKey(T item) =>
      Key('$pickerKeyPrefix-option-${pickerIdOf(item)}');

  Key pickerUpdatingKey(T item) =>
      Key('$pickerKeyPrefix-updating-${pickerIdOf(item)}');

  bool isPickerMember(T item) => pickerMemberIds.contains(pickerIdOf(item));

  bool isPickerUpdating(T item) => pickerUpdatingIds.contains(pickerIdOf(item));

  bool get isPickerUpdatingAny => pickerUpdatingIds.isNotEmpty;

  bool get _pickerHasMore => _pickerNextOffset < _pickerTotal;

  bool get _pickerIsDrawer => AppAdaptiveModalShellScope.maybeIsDrawer(context);

  @override
  void initState() {
    super.initState();
    pickerMemberIds = <int>{...pickerInitialMemberIds};
    reloadPickerItems();
  }

  @override
  void dispose() {
    _pickerSearchTimer?.cancel();
    pickerSearchController.dispose();
    pickerScrollController.dispose();
    super.dispose();
  }

  Future<void> reloadPickerItems() async {
    final seq = ++_pickerRequestSeq;
    setState(() {
      pickerIsLoading = true;
      pickerIsLoadingMore = false;
      pickerErrorMessage = null;
      _pickerLoadMoreErrorMessage = null;
    });
    try {
      final result = await fetchPickerPage(1);
      if (!mounted || seq != _pickerRequestSeq) {
        return;
      }
      setState(() {
        pickerItems
          ..clear()
          ..addAll(result.items);
        _pickerNextOffset = result.items.length;
        _pickerTotal = result.total;
        pickerIsLoading = false;
      });
    } catch (error) {
      if (!mounted || seq != _pickerRequestSeq) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        pickerErrorMessage = apiErrorMessage(
          error,
          fallback: pickerLoadErrorFallback,
          l10n: l10n,
        );
        pickerIsLoading = false;
      });
    }
  }

  Future<void> loadPickerMore() async {
    if (pickerIsLoading ||
        pickerIsLoadingMore ||
        !_pickerHasMore ||
        _pickerLoadMoreErrorMessage != null) {
      return;
    }
    final seq = _pickerRequestSeq;
    setState(() => pickerIsLoadingMore = true);
    try {
      // 本地可能已把“刚加入”的行移出列表，按已消费偏移取下一页并跳过页内已消费段，
      // 避免整页错位漏项；服务端继续用 exclude 过滤保证不重复返回已加入项。
      final page = (_pickerNextOffset ~/ collectionMemberPickerPageSize) + 1;
      final skip = _pickerNextOffset % collectionMemberPickerPageSize;
      final result = await fetchPickerPage(page);
      if (!mounted || seq != _pickerRequestSeq) {
        return;
      }
      setState(() {
        final loadedIds = pickerItems.map(pickerIdOf).toSet();
        final incoming = result.items
            .skip(skip)
            .where((item) => !loadedIds.contains(pickerIdOf(item)));
        final consumed = math.max(0, result.items.length - skip);
        pickerItems.addAll(incoming);
        _pickerNextOffset += consumed;
        _pickerTotal = consumed == 0 ? _pickerNextOffset : result.total;
        _pickerLoadMoreErrorMessage = null;
      });
    } catch (error) {
      if (mounted && seq == _pickerRequestSeq) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          final message = apiErrorMessage(
            error,
            fallback: pickerLoadErrorFallback,
            l10n: l10n,
          );
          if (pickerItems.isEmpty) {
            pickerErrorMessage = message;
          } else {
            _pickerLoadMoreErrorMessage = message;
          }
        });
      }
    } finally {
      if (mounted && seq == _pickerRequestSeq) {
        setState(() => pickerIsLoadingMore = false);
      }
    }
  }

  void retryPickerLoadMore() {
    setState(() => _pickerLoadMoreErrorMessage = null);
    unawaited(loadPickerMore());
  }

  void setPickerOnlyUnadded(bool value) {
    if (value == pickerOnlyUnadded) {
      return;
    }
    setState(() => pickerOnlyUnadded = value);
    reloadPickerItems();
  }

  Widget buildPickerOnlyUnaddedChip(BuildContext context) {
    return AppPickerIosChip(
      key: pickerKey('only-unadded-chip'),
      label: pickerOnlyUnaddedLabel,
      selected: pickerOnlyUnadded,
      onPressed: () => setPickerOnlyUnadded(!pickerOnlyUnadded),
    );
  }

  List<Widget> buildPickerFilterChips(BuildContext context) {
    return <Widget>[buildPickerOnlyUnaddedChip(context)];
  }

  Widget buildPickerRow({
    required T item,
    required Widget leading,
    required String title,
    required String subtitle,
  }) {
    return AppPickerIosRow(
      optionKey: pickerOptionKey(item),
      leading: leading,
      selected: isPickerMember(item),
      showCheckmark: true,
      enabled: !isPickerUpdatingAny,
      busy: isPickerUpdating(item),
      busyKey: pickerUpdatingKey(item),
      onTap: () => togglePickerItem(item),
      title: title,
      subtitle: subtitle,
    );
  }

  Future<void> togglePickerItem(T item) async {
    if (pickerUpdatingIds.isNotEmpty) {
      return;
    }
    final id = pickerIdOf(item);
    final isMember = pickerMemberIds.contains(id);
    setState(() {
      pickerUpdatingIds.add(id);
      if (isMember) {
        pickerMemberIds.remove(id);
      } else {
        pickerMemberIds.add(id);
      }
    });
    try {
      await persistPickerMembership(item, isMember);
      if (!mounted) {
        return;
      }
      setState(() {
        // 仅未加入视图里“加入即出池”：本地移出的这一条同时从服务端过滤集消失，
        // 已消费游标和总数都要回退，否则下一页会从错位处开始、漏掉边界项。
        if (!isMember && pickerOnlyUnadded) {
          pickerItems.removeWhere((candidate) => pickerIdOf(candidate) == id);
          _pickerTotal = math.max(0, _pickerTotal - 1);
          _pickerNextOffset = math.max(0, _pickerNextOffset - 1);
        }
      });
      showToast(
        pickerMembershipSuccessToast(isMember),
        tone: AppToastTone.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (isMember) {
          pickerMemberIds.add(id);
        } else {
          pickerMemberIds.remove(id);
        }
      });
      showToast(
        apiErrorMessage(
          error,
          fallback: pickerMembershipErrorFallback(isMember),
          l10n: AppLocalizations.of(context),
        ),
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => pickerUpdatingIds.remove(id));
      }
    }
  }

  Widget buildPickerScaffold(BuildContext context) {
    final spacing = context.appSpacing;
    final body = _buildPickerBody(context);
    return Column(
      mainAxisSize: _pickerIsDrawer ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_pickerIsDrawer) SizedBox(height: spacing.lg),
        AppPickerHeader(
          searchController: pickerSearchController,
          searchFieldKey: pickerKey('search-field'),
          searchHintText: pickerSearchHint,
          clearSearchKey: pickerKey('search-clear'),
          onSearchChanged: _onPickerSearchChanged,
          chips: buildPickerFilterChips(context),
        ),
        SizedBox(height: spacing.lg),
        // 抽屉高度固定，列表占满剩余空间；弹窗按内容收缩。
        _pickerIsDrawer ? Expanded(child: body) : body,
      ],
    );
  }

  void _onPickerSearchChanged(String raw) {
    final next = raw.trim();
    _pickerSearchTimer?.cancel();
    _pickerSearchTimer = Timer(_pickerSearchDebounce, () {
      if (!mounted || next == pickerKeyword) {
        return;
      }
      setState(() => pickerKeyword = next);
      reloadPickerItems();
    });
  }

  Widget _buildPickerBody(BuildContext context) {
    if (pickerIsLoading && pickerItems.isEmpty) {
      return _buildPickerLoading(context, key: pickerKey('loading'));
    }
    if (pickerErrorMessage != null) {
      return AppPickerIosState(
        key: pickerKey('error'),
        message: pickerErrorMessage!,
        onRetry: reloadPickerItems,
      );
    }
    if (pickerItems.isEmpty) {
      if (_pickerHasMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            loadPickerMore();
          }
        });
        return _buildPickerLoading(context);
      }
      return buildPickerEmptyState(context);
    }

    final countLabel = pickerCountLabel(pickerMemberIds.length, _pickerTotal);
    final list = AppPagedLoadMoreScope(
      canLoadMore: () =>
          !pickerIsLoading &&
          !pickerIsLoadingMore &&
          _pickerHasMore &&
          pickerErrorMessage == null &&
          _pickerLoadMoreErrorMessage == null,
      onLoadMore: loadPickerMore,
      child: SingleChildScrollView(
        key: pickerKey('list'),
        controller: pickerScrollController,
        padding: EdgeInsets.only(bottom: context.appSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPickerIosSection(
              dividerIndent: 84,
              header: Text(
                countLabel,
                key: pickerKey('count'),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ),
              ),
              children: [
                for (final item in pickerItems)
                  buildPickerOption(context, item),
              ],
            ),
            if (_pickerHasMore || _pickerLoadMoreErrorMessage != null)
              AppPagedLoadMoreFooter(
                isLoading: _pickerLoadMoreErrorMessage == null,
                errorMessage: _pickerLoadMoreErrorMessage,
                onRetry: retryPickerLoadMore,
              ),
          ],
        ),
      ),
    );
    if (_pickerIsDrawer) {
      return list;
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: list,
    );
  }

  Widget _buildPickerLoading(BuildContext context, {Key? key}) {
    return AppSkeletonizer(
      key: key,
      enabled: true,
      child: AppPickerIosSection(
        dividerIndent: 84,
        children: [
          for (final item in pickerPlaceholders)
            buildPickerOption(context, item),
        ],
      ),
    );
  }
}
