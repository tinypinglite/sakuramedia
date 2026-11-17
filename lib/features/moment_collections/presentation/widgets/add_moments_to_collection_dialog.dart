import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_placeholders.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_member_picker.dart';

/// 时刻选择器的内容类型：后端 `kind` 支持 jav / video / all。
enum _MomentKindOption {
  all(apiValue: 'all'),
  jav(apiValue: 'jav'),
  video(apiValue: 'video');

  const _MomentKindOption({required this.apiValue});

  final String apiValue;

  /// `JAV` 是内容类型代号，中英文一致，不进语言包。
  String label(AppLocalizations l10n) => switch (this) {
    _MomentKindOption.all => l10n.momentKindAll,
    _MomentKindOption.jav => 'JAV',
    _MomentKindOption.video => l10n.momentKindVideo,
  };
}

/// 在合集详情里弹出「添加时刻」选择器：默认只看未加入，勾选即时加入 / 移出。
///
/// 关闭方式不固定（桌面 X / 移动端下拉或遮罩），不依赖返回值；调用方关闭后刷新
/// 合集详情即可。桌面端用居中弹窗，移动端用底部抽屉（`auto` 读 `AppPlatformScope`）。
Future<void> showAddMomentsToCollectionDialog(
  BuildContext context, {
  required int collectionId,
  required Set<int> memberPointIds,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    dialogKey: const Key('add-moments-to-collection-dialog'),
    drawerKey: const Key('add-moments-to-collection-bottom-sheet'),
    desktopWidth: context.appComponentTokens.playlistDialogWidth,
    mobileHeightFactor: 0.8,
    showDesktopCloseButton: true,
    builder: (_) => AddMomentsToCollectionDialog(
      collectionId: collectionId,
      memberPointIds: memberPointIds,
    ),
  );
}

class AddMomentsToCollectionDialog extends ConsumerStatefulWidget {
  const AddMomentsToCollectionDialog({
    super.key,
    required this.collectionId,
    required this.memberPointIds,
  });

  final int collectionId;
  final Set<int> memberPointIds;

  @override
  ConsumerState<AddMomentsToCollectionDialog> createState() =>
      _AddMomentsToCollectionDialogState();
}

class _AddMomentsToCollectionDialogState
    extends ConsumerState<AddMomentsToCollectionDialog>
    with
        CollectionMemberPickerStateMixin<
          AddMomentsToCollectionDialog,
          MediaPointListItemDto
        > {
  _MomentKindOption _kind = _MomentKindOption.all;

  @override
  String get pickerKeyPrefix => 'add-moments';

  @override
  @override
  String get pickerSearchHint =>
      AppLocalizations.of(context).momentPickerSearchHint;

  @override
  String get pickerOnlyUnaddedLabel =>
      AppLocalizations.of(context).momentPickerOnlyUnadded;

  @override
  String get pickerLoadErrorFallback =>
      AppLocalizations.of(context).momentErrorPointsLoadFailed;

  @override
  Set<int> get pickerInitialMemberIds => widget.memberPointIds;

  @override
  List<MediaPointListItemDto> get pickerPlaceholders =>
      mediaPointListItemPlaceholders();

  @override
  List<Widget> buildPickerFilterChips(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <Widget>[
      buildPickerOnlyUnaddedChip(context),
      Container(
        width: 1,
        height: context.appComponentTokens.buttonHeightXs,
        color: context.appColors.divider,
      ),
      for (final kind in _MomentKindOption.values)
        AppPickerIosChip(
          key: pickerKey('kind-${kind.apiValue}'),
          label: kind.label(l10n),
          selected: _kind == kind,
          onPressed: () => _selectKind(kind),
        ),
    ];
  }

  void _selectKind(_MomentKindOption kind) {
    if (kind == _kind) {
      return;
    }
    setState(() => _kind = kind);
    reloadPickerItems();
  }

  @override
  Future<PaginatedResponseDto<MediaPointListItemDto>> fetchPickerPage(
    int page,
  ) {
    return ref
        .read(mediaApiProvider)
        .getGlobalMediaPoints(
          page: page,
          pageSize: collectionMemberPickerPageSize,
          kind: _kind.apiValue,
          keyword: pickerKeyword.isEmpty ? null : pickerKeyword,
          excludeCollectionId: pickerOnlyUnadded ? widget.collectionId : null,
        );
  }

  @override
  int pickerIdOf(MediaPointListItemDto item) => item.pointId;

  @override
  Widget buildPickerOption(BuildContext context, MediaPointListItemDto point) {
    final l10n = AppLocalizations.of(context);
    final videoItemId = point.videoItemId;
    final title = point.movieNumber?.isNotEmpty == true
        ? point.movieNumber!
        : (videoItemId != null && videoItemId > 0
              ? l10n.momentVideoLabel(videoItemId)
              : l10n.momentLabel(point.pointId));
    return buildPickerRow(
      item: point,
      leading: AppPickerIosCover(url: point.image?.origin),
      title: title,
      subtitle: formatMediaTimecode(point.offsetSeconds),
    );
  }

  @override
  Widget buildPickerEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (pickerKeyword.isNotEmpty) {
      return AppPickerIosState(
        key: pickerKey('empty-search'),
        title: l10n.momentEmptyNoMatchTitle,
        message: l10n.momentEmptyNoMatchMessage,
      );
    }
    if (_kind != _MomentKindOption.all) {
      return AppPickerIosState(
        key: pickerKey('empty-kind'),
        title: l10n.momentEmptyKindTitle,
        message: l10n.momentEmptyKindMessage,
      );
    }
    if (pickerOnlyUnadded) {
      return AppPickerIosState(
        key: pickerKey('empty-all-added'),
        title: l10n.momentEmptyAllAddedTitle,
        message: l10n.momentEmptyAllAddedMessage,
        actionLabel: l10n.momentViewAll,
        onRetry: () => setPickerOnlyUnadded(false),
        retryKey: pickerKey('show-all-button'),
      );
    }
    return AppPickerIosState(
      key: pickerKey('empty-library'),
      title: l10n.momentEmptyNoMomentsTitle,
      message: l10n.momentEmptyNoMomentsMessage,
    );
  }

  @override
  String pickerCountLabel(int selectedCount, int total) {
    final l10n = AppLocalizations.of(context);
    return pickerOnlyUnadded
        ? l10n.momentPickerCountAvailable(selectedCount, total)
        : l10n.momentPickerCountTotal(selectedCount, total);
  }

  @override
  String pickerMembershipErrorFallback(bool isMember) {
    final l10n = AppLocalizations.of(context);
    return isMember
        ? l10n.momentErrorRemoveFromCollectionBriefFailed
        : l10n.momentErrorAddToCollectionFailed;
  }

  @override
  String pickerMembershipSuccessToast(bool isMember) {
    final l10n = AppLocalizations.of(context);
    return isMember ? l10n.momentMovedOutToast : l10n.momentAddedToast;
  }

  @override
  Future<void> persistPickerMembership(
    MediaPointListItemDto item,
    bool isMember,
  ) async {
    final api = ref.read(momentCollectionsApiProvider);
    if (isMember) {
      await api.removePoint(
        collectionId: widget.collectionId,
        pointId: item.pointId,
      );
    } else {
      await api.addPoint(
        collectionId: widget.collectionId,
        pointId: item.pointId,
      );
    }
  }

  @override
  Widget build(BuildContext context) => buildPickerScaffold(context);
}
