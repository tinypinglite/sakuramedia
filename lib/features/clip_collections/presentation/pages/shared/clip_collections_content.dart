import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/clip_collection_placeholders.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_api_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_overview_provider.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clip_mutation_events_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_list_content.dart';

/// 切片合集列表共享实现：桌面 / 移动只保留入口壳差异。
class ClipCollectionsContent extends ConsumerStatefulWidget {
  const ClipCollectionsContent({super.key, required this.mobile});

  final bool mobile;

  @override
  ConsumerState<ClipCollectionsContent> createState() =>
      _ClipCollectionsContentState();
}

class _ClipCollectionsContentState
    extends ConsumerState<ClipCollectionsContent> {
  bool _refreshScheduled = false;

  void _onMutation(ClipMutationChange _) {
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    scheduleMicrotask(() {
      _refreshScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(ref.read(clipCollectionsOverviewProvider.notifier).refresh());
    });
  }

  Future<void> _refresh() {
    return ref.read(clipCollectionsOverviewProvider.notifier).refresh();
  }

  Future<void> _open(BuildContext context, ClipCollectionDto collection) async {
    if (widget.mobile) {
      await MobileRoutes.clipCollectionDetail(
        collectionId: collection.id,
      ).push<void>(context);
      return;
    }
    DesktopRoutes.clipCollectionDetail(
      collectionId: collection.id,
    ).push(context);
  }

  Future<void> _create(BuildContext context) async {
    final created = await showCreateClipCollectionDialog(
      context,
      presentation: widget.mobile
          ? ClipCollectionEditPresentation.bottomDrawer
          : ClipCollectionEditPresentation.dialog,
    );
    if (!mounted || !context.mounted || created == null) {
      return;
    }
    ref
        .read(clipCollectionsOverviewProvider.notifier)
        .insertCollection(created);
    showToast(
      AppLocalizations.of(context).clipCollectionCreatedToast,
      tone: AppToastTone.success,
    );
  }

  Future<void> _edit(BuildContext context, ClipCollectionDto collection) async {
    final updated = await showEditClipCollectionDialog(
      context,
      collection: collection,
      presentation: widget.mobile
          ? ClipCollectionEditPresentation.bottomDrawer
          : ClipCollectionEditPresentation.dialog,
    );
    if (!mounted || !context.mounted || updated == null) {
      return;
    }
    ref
        .read(clipCollectionsOverviewProvider.notifier)
        .replaceCollection(updated);
    showToast(
      AppLocalizations.of(context).commonSaved,
      tone: AppToastTone.success,
    );
  }

  Future<void> _delete(
    BuildContext context,
    ClipCollectionDto collection,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = collection.name.trim().isEmpty
        ? l10n.clipCollectionUnnamed
        : '“${collection.name.trim()}”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.clipCollectionDeleteTitle,
      message: l10n.clipCollectionDeleteMessage(name),
      danger: true,
      dialogKey: widget.mobile
          ? const Key('mobile-clip-collection-delete-drawer')
          : null,
      confirmLabel: l10n.commonDelete,
      confirmKey: widget.mobile
          ? const Key('mobile-clip-collection-delete-confirm-button')
          : const Key('clip-collection-delete-confirm-button'),
    );
    if (!mounted || !confirmed) {
      return;
    }
    try {
      await ref
          .read(clipCollectionsApiProvider)
          .deleteCollection(collectionId: collection.id);
      ref
          .read(clipCollectionsOverviewProvider.notifier)
          .removeCollection(collection.id);
      if (mounted) {
        showToast(l10n.clipCollectionDeletedToast, tone: AppToastTone.success);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.clipCollectionDeleteFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ClipMutationChange>>(clipMutationEventsProvider, (
      previous,
      next,
    ) {
      final change = next.value;
      if (change != null) {
        _onMutation(change);
      }
    });

    final l10n = AppLocalizations.of(context);
    return CollectionListContent<ClipCollectionDto>(
      mobile: widget.mobile,
      keyPrefix: widget.mobile ? 'mobile-clip-collections' : 'clip-collections',
      title: l10n.clipCollectionPageTitle,
      searchHint: l10n.clipCollectionSearchHint,
      createLabel: l10n.clipCollectionCreate,
      emptyDesktopMessage: l10n.clipCollectionEmptyDesktop,
      emptyMobileMessage: l10n.clipCollectionEmptyMobile,
      noMatchMessage: l10n.clipCollectionNoMatch,
      loadErrorMessage: l10n.clipCollectionLoadFailed,
      collections: ref.watch(clipCollectionsOverviewProvider),
      onRefresh: _refresh,
      placeholders: (mobile) =>
          clipCollectionPlaceholders(count: mobile ? 6 : 8),
      nameOf: (collection) => collection.name,
      cardBuilder:
          (
            context,
            collection, {
            required onTap,
            required onEdit,
            required onDelete,
          }) => CollectionCard.clip(
            key: Key(
              '${widget.mobile ? 'mobile-' : ''}'
              'clip-collection-card-${collection.id}',
            ),
            collection: collection,
            onTap: onTap,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
      onOpen: _open,
      onCreate: _create,
      onEdit: _edit,
      onDelete: _delete,
    );
  }
}
