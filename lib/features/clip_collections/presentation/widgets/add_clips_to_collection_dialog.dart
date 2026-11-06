import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/clip_placeholders.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_member_picker.dart';

/// 在合集详情里弹出「添加切片」选择器：默认只看未加入，勾选即时加入 / 移出。
///
/// 关闭方式不固定（X / 点遮罩 / 抽屉「完成」），不依赖返回值；调用方关闭后刷新
/// 合集详情即可。桌面端用居中弹窗，移动端用底部抽屉（`auto` 读 `AppPlatformScope`）。
Future<void> showAddClipsToCollectionDialog(
  BuildContext context, {
  required int collectionId,
  required Set<int> memberClipIds,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    dialogKey: const Key('add-clips-to-collection-dialog'),
    drawerKey: const Key('add-clips-to-collection-bottom-sheet'),
    desktopWidth: context.appComponentTokens.playlistDialogWidth,
    mobileHeightFactor: 0.8,
    showDesktopCloseButton: false,
    builder: (_) => AddClipsToCollectionDialog(
      collectionId: collectionId,
      memberClipIds: memberClipIds,
    ),
  );
}

class AddClipsToCollectionDialog extends ConsumerStatefulWidget {
  const AddClipsToCollectionDialog({
    super.key,
    required this.collectionId,
    required this.memberClipIds,
  });

  final int collectionId;
  final Set<int> memberClipIds;

  @override
  ConsumerState<AddClipsToCollectionDialog> createState() =>
      _AddClipsToCollectionDialogState();
}

class _AddClipsToCollectionDialogState
    extends ConsumerState<AddClipsToCollectionDialog>
    with
        CollectionMemberPickerStateMixin<
          AddClipsToCollectionDialog,
          MediaClipDto
        > {
  @override
  String get pickerKeyPrefix => 'add-clips';

  @override
  String get pickerTitle => AppLocalizations.of(context).clipCollectionAddClips;

  @override
  String get pickerSearchHint =>
      AppLocalizations.of(context).clipCollectionSearchClipsHint;

  @override
  String get pickerOnlyUnaddedLabel =>
      AppLocalizations.of(context).clipCollectionOnlyUnadded;

  @override
  String get pickerLoadErrorFallback =>
      AppLocalizations.of(context).clipCollectionClipsLoadFailed;

  @override
  Set<int> get pickerInitialMemberIds => widget.memberClipIds;

  @override
  List<MediaClipDto> get pickerPlaceholders => clipPlaceholders();

  @override
  Future<PaginatedResponseDto<MediaClipDto>> fetchPickerPage(int page) {
    return ref
        .read(clipsApiProvider)
        .getMyClips(
          page: page,
          pageSize: collectionMemberPickerPageSize,
          keyword: pickerKeyword.isEmpty ? null : pickerKeyword,
          excludeCollectionId: pickerOnlyUnadded ? widget.collectionId : null,
        );
  }

  @override
  int pickerIdOf(MediaClipDto item) => item.clipId;

  @override
  Widget buildPickerOption(BuildContext context, MediaClipDto clip) {
    final l10n = AppLocalizations.of(context);
    final title = clip.title.trim();
    final metaParts = <String>[
      if (clip.movieNumber != null && clip.movieNumber!.isNotEmpty)
        clip.movieNumber!
      else
        l10n.clipCollectionNoMovieNumber,
      formatMediaTimecode(clip.durationSeconds),
    ];
    return buildPickerRow(
      item: clip,
      leading: AppPickerIosCover(url: clip.coverImage?.origin),
      title: title.isEmpty ? l10n.clipCollectionUntitledClip : title,
      subtitle: metaParts.join(' · '),
    );
  }

  @override
  Widget buildPickerEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (pickerKeyword.isNotEmpty) {
      return AppPickerIosState(
        key: pickerKey('empty-search'),
        title: l10n.clipCollectionNoMatchingClips,
        message: l10n.clipCollectionTryAnotherKeyword,
      );
    }
    if (pickerOnlyUnadded) {
      return AppPickerIosState(
        key: pickerKey('empty-all-added'),
        title: l10n.clipCollectionAllAdded,
        message: l10n.clipCollectionAllAddedHint,
        actionLabel: l10n.clipCollectionViewAll,
        onRetry: () => setPickerOnlyUnadded(false),
        retryKey: pickerKey('show-all-button'),
      );
    }
    return AppPickerIosState(
      key: pickerKey('empty-library'),
      title: l10n.clipCollectionNoClipsTitle,
      message: l10n.clipCollectionNoClipsHint,
    );
  }

  @override
  String pickerCountLabel(int selectedCount, int total) {
    final l10n = AppLocalizations.of(context);
    return pickerOnlyUnadded
        ? l10n.clipCollectionAddedAvailableCount(selectedCount, total)
        : l10n.clipCollectionAddedTotalCount(selectedCount, total);
  }

  @override
  String pickerMembershipErrorFallback(bool isMember) {
    final l10n = AppLocalizations.of(context);
    return isMember
        ? l10n.clipCollectionRemoveFailed
        : l10n.clipCollectionAddFailed;
  }

  @override
  String pickerMembershipSuccessToast(bool isMember) {
    final l10n = AppLocalizations.of(context);
    return isMember
        ? l10n.clipCollectionMovedOutToast
        : l10n.clipCollectionAddedToast;
  }

  @override
  Future<void> persistPickerMembership(MediaClipDto item, bool isMember) async {
    final api = ref.read(clipCollectionsApiProvider);
    if (isMember) {
      await api.removeClipFromCollection(
        collectionId: widget.collectionId,
        clipId: item.clipId,
      );
    } else {
      await api.addClipToCollection(
        collectionId: widget.collectionId,
        clipId: item.clipId,
      );
    }
  }

  @override
  Widget build(BuildContext context) => buildPickerScaffold(context);
}
