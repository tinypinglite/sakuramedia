import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_header.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';

/// 桌面端以图搜图「选择女优」弹窗。
Future<void> showActorSelectorDialog(
  BuildContext context, {
  required List<ActorListItemDto> actors,
  required List<ActorListItemDto> initialSelectedActors,
  required ValueChanged<List<ActorListItemDto>> onSelectionChanged,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (dialogContext) => AppDesktopDialog(
      dialogKey: const Key('image-search-actor-picker-dialog'),
      width: context.appComponentTokens.playlistDialogWidth,
      showCloseButton: false,
      child: ImageSearchActorSelectorBody(
        actors: actors,
        initialSelectedActors: initialSelectedActors,
        onClose: () => Navigator.of(dialogContext).pop(),
        onSelectionChanged: onSelectionChanged,
      ),
    ),
  );
}

class ImageSearchActorSelectorBody extends StatefulWidget {
  const ImageSearchActorSelectorBody({
    super.key,
    required this.actors,
    required this.initialSelectedActors,
    required this.onClose,
    required this.onSelectionChanged,
    this.isBottomDrawer = false,
  });

  final List<ActorListItemDto> actors;
  final List<ActorListItemDto> initialSelectedActors;
  final VoidCallback onClose;
  final ValueChanged<List<ActorListItemDto>> onSelectionChanged;
  final bool isBottomDrawer;

  @override
  State<ImageSearchActorSelectorBody> createState() =>
      _ImageSearchActorSelectorBodyState();
}

class _ImageSearchActorSelectorBodyState
    extends State<ImageSearchActorSelectorBody> {
  final ScrollController _scrollController = ScrollController();
  late final Set<int> _selectedActorIds;

  @override
  void initState() {
    super.initState();
    _selectedActorIds = widget.initialSelectedActors
        .map((ActorListItemDto actor) => actor.id)
        .toSet();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final body = widget.actors.isEmpty
        ? AppPickerIosState(message: l10n.imageSearchNoSubscribedActors)
        : SingleChildScrollView(
            key: const Key('image-search-actor-list'),
            controller: _scrollController,
            child: AppPickerIosSection(
              dividerIndent: 68,
              header: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.commonSelectedCount(_selectedActorIds.length),
                      key: const Key('image-search-actor-selected-count'),
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.muted,
                      ),
                    ),
                  ),
                  AppPickerIosActionButton(
                    key: const Key('image-search-actor-clear-button'),
                    label: l10n.imageSearchClearSelection,
                    onPressed: _selectedActorIds.isEmpty
                        ? null
                        : _clearSelection,
                  ),
                ],
              ),
              children: [
                for (final actor in widget.actors)
                  AppPickerIosRow(
                    selected: _selectedActorIds.contains(actor.id),
                    showCheckmark: true,
                    onTap: () => _toggleActor(actor),
                    title: actor.displayName,
                    leading: ActorAvatar(
                      imageUrl: actor.profileImage?.origin,
                      size: context.appComponentTokens.iconSize2xl,
                      placeholderKey: Key(
                        'image-search-actor-avatar-placeholder-${actor.id}',
                      ),
                    ),
                    optionKey: Key('image-search-actor-option-${actor.id}'),
                  ),
              ],
            ),
          );

    return Column(
      mainAxisSize: widget.isBottomDrawer ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPickerHeader(
          title: l10n.imageSearchSelectSubscribedActors,
          onClose: widget.onClose,
          closeKey: const Key('image-search-actor-close-button'),
          doneKey: const Key('image-search-actor-done-button'),
        ),
        SizedBox(height: spacing.lg),
        AppPickerListFrame(isDrawer: widget.isBottomDrawer, child: body),
      ],
    );
  }

  void _toggleActor(ActorListItemDto actor) {
    setState(() {
      if (_selectedActorIds.contains(actor.id)) {
        _selectedActorIds.remove(actor.id);
      } else {
        _selectedActorIds.add(actor.id);
      }
    });
    _notifySelectionChanged();
  }

  void _clearSelection() {
    setState(_selectedActorIds.clear);
    _notifySelectionChanged();
  }

  void _notifySelectionChanged() {
    widget.onSelectionChanged(
      widget.actors
          .where(
            (ActorListItemDto actor) => _selectedActorIds.contains(actor.id),
          )
          .toList(growable: false),
    );
  }
}
