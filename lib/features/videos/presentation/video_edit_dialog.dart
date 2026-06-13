import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selection_controller.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selector_panel.dart';
import 'package:sakuramedia/features/videos/data/persons_api.dart';
import 'package:sakuramedia/features/videos/data/video_item_detail_dto.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/person_selection_controller.dart';
import 'package:sakuramedia/features/videos/presentation/person_selector_panel.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

/// 打开视频创建/编辑对话框。[existing] 为空表示创建，非空表示编辑（回填并整体替换关联）。
/// 返回最新的 [VideoItemDetailDto]（创建/更新结果），取消则返回 `null`。
Future<VideoItemDetailDto?> showVideoEditDialog(
  BuildContext context, {
  VideoItemDetailDto? existing,
}) {
  return showDialog<VideoItemDetailDto>(
    context: context,
    builder: (dialogContext) => VideoEditDialog(existing: existing),
  );
}

class VideoEditDialog extends StatefulWidget {
  const VideoEditDialog({super.key, this.existing});

  final VideoItemDetailDto? existing;

  @override
  State<VideoEditDialog> createState() => _VideoEditDialogState();
}

class _VideoEditDialogState extends State<VideoEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TagSelectionController _tagSelection;
  late final PersonSelectionController _personSelection;
  DateTime? _releaseDate;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _summaryController = TextEditingController(text: existing?.summary ?? '');
    _releaseDate = existing?.releaseDate;
    _tagSelection = TagSelectionController(
      tagsApi: context.read<TagsApi>(),
      popularLimit: 30,
      initialSelectedTagIds:
          existing?.tags.map((tag) => tag.tagId).toList() ?? const <int>[],
    );
    _personSelection = PersonSelectionController(
      personsApi: context.read<PersonsApi>(),
      initialSelectedPersons: existing?.persons ?? const [],
    );
    unawaited(_tagSelection.load());
    unawaited(_personSelection.load());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _tagSelection.dispose();
    _personSelection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDesktopDialog(
      width: 560,
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final spacing = context.appSpacing;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? '编辑视频' : '新建视频',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    fieldKey: const Key('video-edit-title-field'),
                    controller: _titleController,
                    hintText: '视频标题',
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? '请输入标题' : null,
                  ),
                  SizedBox(height: spacing.sm),
                  AppTextField(
                    fieldKey: const Key('video-edit-summary-field'),
                    controller: _summaryController,
                    hintText: '简介（可选）',
                    maxLines: 3,
                    minLines: 2,
                  ),
                  SizedBox(height: spacing.sm),
                  _buildReleaseDateRow(context),
                  SizedBox(height: spacing.md),
                  AnimatedBuilder(
                    animation: _tagSelection,
                    builder: (context, _) => TagSelectorPanel(
                      selection: _tagSelection,
                      onToggleTag: _tagSelection.toggle,
                      onRemoveTag: _tagSelection.remove,
                      onClear: _tagSelection.clear,
                      onQueryChanged: _tagSelection.setQuery,
                      onToggleExpanded: _tagSelection.toggleExpanded,
                      onMatchModeChanged: (_) {},
                      showMatchModeToggle: false,
                      onRetry: () => unawaited(_tagSelection.retry()),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  AnimatedBuilder(
                    animation: _personSelection,
                    builder: (context, _) => PersonSelectorPanel(
                      selection: _personSelection,
                      onTogglePerson: _personSelection.toggle,
                      onRemovePerson: _personSelection.remove,
                      onClear: _personSelection.clear,
                      onQueryChanged: _personSelection.setQuery,
                      onRetry: () => unawaited(_personSelection.retry()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '取消',
                  onPressed:
                      _isSubmitting ? null : () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('video-edit-submit-button'),
                  label: _isEditing ? '保存' : '创建',
                  variant: AppButtonVariant.primary,
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseDateRow(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      children: [
        Text(
          '发布时间',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(width: spacing.md),
        AppTextButton(
          label: _releaseDate == null
              ? '选择日期'
              : _formatDate(_releaseDate!),
          size: AppTextButtonSize.small,
          backgroundStyle: AppTextButtonBackgroundStyle.muted,
          onPressed: _pickReleaseDate,
        ),
        if (_releaseDate != null)
          AppTextButton(
            label: '清除',
            size: AppTextButtonSize.xSmall,
            onPressed: () => setState(() => _releaseDate = null),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickReleaseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate ?? now,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _releaseDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    final videosApi = context.read<VideosApi>();
    try {
      final VideoItemDetailDto result;
      if (_isEditing) {
        result = await videosApi.updateVideo(
          videoId: widget.existing!.id,
          payload: VideoItemUpdatePayload(
            title: _titleController.text.trim(),
            summary: _summaryController.text,
            releaseDate: _releaseDate,
            tagIds: _tagSelection.selectedTagIds,
            personIds: _personSelection.selectedPersonIds,
          ),
        );
      } else {
        result = await videosApi.createVideo(
          title: _titleController.text,
          summary: _summaryController.text,
          releaseDate: _releaseDate,
          tagIds: _tagSelection.selectedTagIds,
          personIds: _personSelection.selectedPersonIds,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: _isEditing ? '保存失败' : '创建失败'));
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
