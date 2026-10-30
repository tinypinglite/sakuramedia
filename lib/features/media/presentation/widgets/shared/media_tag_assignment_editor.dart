import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_tag_assignment_events_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_tags_api_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_tags_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

Future<MediaTagAssignmentDto?> showMediaTagAssignmentEditor(
  BuildContext context, {
  required int mediaId,
  required bool mobile,
}) {
  final editor = _MediaTagAssignmentEditor(mediaId: mediaId, mobile: mobile);
  if (mobile) {
    return showAppBottomDrawer<MediaTagAssignmentDto>(
      context: context,
      drawerKey: const Key('media-tag-assignment-drawer'),
      heightFactor: 0.86,
      builder: (_) => editor,
    );
  }
  return showDialog<MediaTagAssignmentDto>(
    context: context,
    builder: (_) => AppDesktopDialog(
      dialogKey: const Key('media-tag-assignment-dialog'),
      constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
      child: editor,
    ),
  );
}

class _MediaTagAssignmentEditor extends ConsumerStatefulWidget {
  const _MediaTagAssignmentEditor({
    required this.mediaId,
    required this.mobile,
  });

  final int mediaId;
  final bool mobile;

  @override
  ConsumerState<_MediaTagAssignmentEditor> createState() =>
      _MediaTagAssignmentEditorState();
}

class _MediaTagAssignmentEditorState
    extends ConsumerState<_MediaTagAssignmentEditor> {
  MediaTagAssignmentDto? _assignment;
  String? _loadError;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final assignment = await ref
          .read(mediaTagsApiProvider)
          .getAssignment(widget.mediaId);
      if (!mounted) return;
      setState(() {
        _assignment = assignment;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = apiErrorMessage(
          error,
          fallback: AppLocalizations.of(context).mediaTagsAssignmentLoadFailed,
          l10n: AppLocalizations.of(context),
        );
      });
    }
  }

  void _toggleTag(int tagId) {
    final assignment = _assignment;
    if (assignment == null) return;
    final next = assignment.tags.map((tag) => tag.id).toList(growable: true);
    if (!next.remove(tagId)) {
      next.add(tagId);
    }
    final tagsById = <int, MediaTagDto>{
      for (final tag
          in ref.read(mediaTagsProvider).value ?? const <MediaTagDto>[])
        tag.id: tag,
    };
    final selectedTags = <MediaTagRefDto>[
      for (final id in next)
        if (tagsById[id] != null) tagsById[id]!.ref,
    ];
    setState(() {
      _assignment = MediaTagAssignmentDto(
        mediaId: assignment.mediaId,
        tags: selectedTags,
        isManuallyManaged: assignment.isManuallyManaged,
      );
    });
  }

  Future<void> _save() async {
    final assignment = _assignment;
    if (assignment == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final saved = await ref
          .read(mediaTagsApiProvider)
          .setAssignment(
            mediaId: widget.mediaId,
            tagIds: assignment.tags.map((tag) => tag.id).toList(),
          );
      if (!mounted) return;
      _finish(saved);
    } catch (error) {
      if (!mounted) return;
      showToast(
        apiErrorMessage(
          error,
          fallback: AppLocalizations.of(context).mediaTagsAssignmentSaveFailed,
          l10n: AppLocalizations.of(context),
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetToAuto() async {
    if (_isSubmitting) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.mediaTagsAssignmentResetTitle,
      message: l10n.mediaTagsAssignmentResetMessage,
      confirmLabel: l10n.mediaTagsAssignmentResetAuto,
      dialogKey: const Key('media-tag-assignment-reset-dialog'),
      confirmKey: const Key('media-tag-assignment-reset-confirm'),
      cancelKey: const Key('media-tag-assignment-reset-cancel'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _isSubmitting = true);
    try {
      final reset = await ref
          .read(mediaTagsApiProvider)
          .resetAssignmentToAuto(widget.mediaId);
      if (!mounted) return;
      _finish(reset);
    } catch (error) {
      if (!mounted) return;
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.mediaTagsAssignmentResetFailed,
          l10n: l10n,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  void _finish(MediaTagAssignmentDto assignment) {
    ref.invalidate(mediaTagsProvider);
    ref
        .read(mediaTagAssignmentEventsProvider.notifier)
        .reportChange(const MediaTagAssignmentChange());
    Navigator.of(context).pop(assignment);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final tagsAsync = ref.watch(mediaTagsProvider);
    final assignment = _assignment;
    final tags = tagsAsync.value ?? const <MediaTagDto>[];

    return Column(
      key: const Key('media-tag-assignment-editor'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.mediaTagsAssignmentTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          l10n.mediaTagsAssignmentDescription,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.md),
        if (_isLoading)
          const Expanded(
            child: Center(child: CircularProgressIndicator.adaptive()),
          )
        else if (_loadError != null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.error,
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  AppButton(
                    key: const Key('media-tag-assignment-retry'),
                    label: l10n.commonRetry,
                    onPressed: _load,
                  ),
                ],
              ),
            ),
          )
        else if (assignment != null) ...[
          Row(
            children: [
              AppBadge(
                label: assignment.isManuallyManaged
                    ? l10n.mediaTagsAssignmentManualBadge
                    : l10n.mediaTagsAssignmentAutoBadge,
                tone: assignment.isManuallyManaged
                    ? AppBadgeTone.primary
                    : AppBadgeTone.neutral,
              ),
              const Spacer(),
              if (assignment.isManuallyManaged)
                AppTextButton(
                  key: const Key('media-tag-assignment-reset-auto'),
                  label: l10n.mediaTagsAssignmentResetAuto,
                  size: AppTextButtonSize.xSmall,
                  onPressed: _isSubmitting ? null : _resetToAuto,
                ),
            ],
          ),
          SizedBox(height: spacing.md),
          Expanded(
            child: tagsAsync.isLoading && tagsAsync.value == null
                ? const Center(child: CircularProgressIndicator.adaptive())
                : tagsAsync.hasError && tagsAsync.value == null
                ? Center(
                    child: AppButton(
                      key: const Key('media-tag-assignment-tags-retry'),
                      label: l10n.commonRetry,
                      onPressed: () =>
                          ref.read(mediaTagsProvider.notifier).reload(),
                    ),
                  )
                : tags.isEmpty
                ? Center(
                    child: Text(
                      tagsAsync.value?.isEmpty == true
                          ? l10n.mediaTagsAssignmentEmpty
                          : l10n.mediaTagsEmpty,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.muted,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: spacing.sm,
                      runSpacing: spacing.sm,
                      children: [
                        for (final tag in tags)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppTextButton(
                                key: Key('media-tag-assignment-tag-${tag.id}'),
                                label: tag.name,
                                size: AppTextButtonSize.xSmall,
                                isSelected: assignment.tags.any(
                                  (selected) => selected.id == tag.id,
                                ),
                                onPressed: () => _toggleTag(tag.id),
                              ),
                              if (!tag.enabled)
                                Text(
                                  l10n.mediaTagsDisabledBadge,
                                  style: resolveAppTextStyle(
                                    context,
                                    size: AppTextSize.s10,
                                    tone: AppTextTone.muted,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
          if (assignment.tags.any((selected) {
            final matching = (tagsAsync.value ?? const <MediaTagDto>[]).where(
              (tag) => tag.id == selected.id,
            );
            return matching.isNotEmpty && !matching.first.enabled;
          })) ...[
            SizedBox(height: spacing.sm),
            Text(
              l10n.mediaTagsAssignmentDisabledHint,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s10,
                tone: AppTextTone.muted,
              ),
            ),
          ],
          SizedBox(height: spacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.commonCancel,
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('media-tag-assignment-save'),
                  label: l10n.mediaTagsAssignmentSave,
                  variant: AppButtonVariant.primary,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
