import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/moment_collection_placeholders.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collection_mutation_events_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_overview_provider.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/moment_collection_editor.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_list_content.dart';

/// 时刻合集列表共享内容：桌面网格页 / 移动子页两套壳共用同一份取数与卡片逻辑。
class MomentCollectionsContent extends ConsumerStatefulWidget {
  const MomentCollectionsContent({
    super.key,
    required this.isMobile,
    required this.onOpenDetail,
  });

  final bool isMobile;
  final ValueChanged<int> onOpenDetail;

  @override
  ConsumerState<MomentCollectionsContent> createState() =>
      _MomentCollectionsContentState();
}

class _MomentCollectionsContentState
    extends ConsumerState<MomentCollectionsContent> {
  Future<void> _refresh() {
    return ref.read(momentCollectionsOverviewProvider.notifier).refresh();
  }

  Future<void> _open(
    BuildContext context,
    MomentCollectionDto collection,
  ) async {
    widget.onOpenDetail(collection.id);
  }

  Future<void> _edit(
    BuildContext context, {
    MomentCollectionDto? collection,
  }) async {
    final l10n = AppLocalizations.of(context);
    final result = await showMomentCollectionEditor(
      context,
      collection: collection,
    );
    if (!mounted || result == null) {
      return;
    }
    final notifier = ref.read(momentCollectionsOverviewProvider.notifier);
    if (collection == null) {
      notifier.insertCollection(result);
      showToast(l10n.momentCollectionCreatedToast, tone: AppToastTone.success);
    } else {
      notifier.replaceCollection(result);
      showToast(l10n.commonSaved, tone: AppToastTone.success);
    }
  }

  Future<void> _delete(
    BuildContext context,
    MomentCollectionDto collection,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = collection.name.trim().isEmpty
        ? l10n.momentCollectionUnnamed
        : '“${collection.name.trim()}”';
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.momentCollectionDeleteTitle,
      message: l10n.momentCollectionDeleteMessage(name),
      danger: true,
      confirmLabel: l10n.commonDelete,
      confirmKey: const Key('moment-collection-delete-confirm-button'),
    );
    if (!mounted || !confirmed) {
      return;
    }
    try {
      await ref
          .read(momentCollectionsApiProvider)
          .deleteCollection(collectionId: collection.id);
      ref
          .read(momentCollectionsOverviewProvider.notifier)
          .removeCollection(collection.id);
      if (mounted) {
        showToast(
          l10n.momentCollectionDeletedToast,
          tone: AppToastTone.success,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.momentErrorDeleteFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(momentCollectionMutationEventsProvider, (_, next) {
      if (next.value != null) {
        unawaited(
          ref.read(momentCollectionsOverviewProvider.notifier).refresh(),
        );
      }
    });

    final l10n = AppLocalizations.of(context);
    return CollectionListContent<MomentCollectionDto>(
      mobile: widget.isMobile,
      keyPrefix: widget.isMobile
          ? 'mobile-moment-collections'
          : 'moment-collections',
      title: l10n.momentCollectionSectionTitle,
      searchHint: l10n.momentCollectionSearchHint,
      createLabel: l10n.momentCollectionCreateTitle,
      emptyDesktopMessage: l10n.momentCollectionEmptyDesktop,
      emptyMobileMessage: l10n.momentCollectionEmptyMobile,
      noMatchMessage: l10n.momentCollectionNoMatch,
      loadErrorMessage: l10n.momentErrorCollectionLoadFailed,
      collections: ref.watch(momentCollectionsOverviewProvider),
      onRefresh: _refresh,
      placeholders: (mobile) =>
          momentCollectionPlaceholders(count: mobile ? 6 : 8),
      nameOf: (collection) => collection.name,
      cardBuilder:
          (
            context,
            collection, {
            required onTap,
            required onEdit,
            required onDelete,
          }) => CollectionCard.moment(
            collection: collection,
            onTap: onTap,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
      onOpen: _open,
      onCreate: (context) => _edit(context),
      onEdit: (context, collection) => _edit(context, collection: collection),
      onDelete: _delete,
    );
  }
}
