import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 桌面端以图搜图「选择女优」弹窗。
Future<void> showActorSelectorDialog(
  BuildContext context, {
  required List<ActorListItemDto> actors,
  required List<ActorListItemDto> initialSelectedActors,
  required ValueChanged<List<ActorListItemDto>> onSelectionChanged,
}) {
  return showDialog<void>(
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
    final spacing = context.appSpacing;
    final actorList = Scrollbar(
      controller: _scrollController,
      thumbVisibility: !widget.isBottomDrawer,
      child: ListView.builder(
        key: const Key('image-search-actor-list'),
        controller: _scrollController,
        itemCount: widget.actors.length,
        itemBuilder: (context, index) {
          final actor = widget.actors[index];
          final selected = _selectedActorIds.contains(actor.id);
          return Material(
            color: context.appColors.surfaceCard,
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              key: Key('image-search-actor-option-${actor.id}'),
              hoverColor: context.appColors.surfaceMuted.withValues(
                alpha: 0.45,
              ),
              highlightColor: context.appColors.surfaceMuted.withValues(
                alpha: 0.6,
              ),
              splashFactory: NoSplash.splashFactory,
              onTap: () => _toggleActor(actor),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.sm,
                  vertical: spacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        actor.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    Checkbox(
                      key: Key('image-search-actor-checkbox-${actor.id}'),
                      value: selected,
                      onChanged: (_) => _toggleActor(actor),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    final body = widget.actors.isEmpty
        ? Center(
            child: Text(
              '暂无已订阅女优',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                tone: AppTextTone.muted,
              ),
            ),
          )
        : actorList;

    return Column(
      mainAxisSize: widget.isBottomDrawer ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '选择已订阅女优',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s16,
                  weight: AppTextWeight.medium,
                ),
              ),
            ),
            AppIconButton(
              key: const Key('image-search-actor-close-button'),
              tooltip: '关闭',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        if (widget.isBottomDrawer)
          Expanded(child: body)
        else
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: SizedBox(
                height: widget.actors.isEmpty ? 160 : null,
                child: body,
              ),
            ),
          ),
        Divider(color: context.appColors.divider, height: spacing.lg),
        AppTextButton(
          key: const Key('image-search-actor-clear-button'),
          label: '清空已选',
          icon: const Icon(Icons.clear_all_rounded),
          onPressed: _selectedActorIds.isEmpty ? null : _clearSelection,
        ),
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
