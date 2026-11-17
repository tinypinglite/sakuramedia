import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_tags_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

class MediaTagRuleTester extends ConsumerStatefulWidget {
  const MediaTagRuleTester({super.key});

  @override
  ConsumerState<MediaTagRuleTester> createState() => _MediaTagRuleTesterState();
}

class _MediaTagRuleTesterState extends ConsumerState<MediaTagRuleTester> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _fileNameController;
  late final TextEditingController _releaseTitleController;
  late final TextEditingController _releaseDescriptionController;
  List<MediaTagPreviewMatchDto>? _matches;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fileNameController = TextEditingController();
    _releaseTitleController = TextEditingController();
    _releaseDescriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _releaseTitleController.dispose();
    _releaseDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final matches = await ref
          .read(mediaTagsApiProvider)
          .preview(
            fileName: _fileNameController.text,
            releaseTitle: _releaseTitleController.text,
            releaseDescription: _releaseDescriptionController.text,
          );
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = apiErrorMessage(
          error,
          fallback: l10n.mediaTagsPreviewFailed,
          l10n: l10n,
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return AppContentCard(
      key: const Key('media-tag-rule-tester'),
      title: l10n.mediaTagsRuleTestTitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.mediaTagsRuleTestDescription,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: spacing.md),
            AppTextField(
              fieldKey: const Key('media-tag-preview-file-name'),
              controller: _fileNameController,
              label: l10n.mediaTagsPreviewFileNameLabel,
              hintText: l10n.mediaTagsPreviewFileNameHint,
              textInputAction: TextInputAction.next,
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.mediaTagsPreviewFileNameLabel
                  : null,
            ),
            SizedBox(height: spacing.md),
            AppTextField(
              fieldKey: const Key('media-tag-preview-release-title'),
              controller: _releaseTitleController,
              label: l10n.mediaTagsPreviewReleaseTitleLabel,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: spacing.md),
            AppTextField(
              fieldKey: const Key('media-tag-preview-release-description'),
              controller: _releaseDescriptionController,
              label: l10n.mediaTagsPreviewReleaseDescriptionLabel,
              keyboardType: TextInputType.multiline,
              minLines: 2,
              maxLines: 5,
            ),
            SizedBox(height: spacing.md),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton(
                key: const Key('media-tag-preview-submit'),
                label: l10n.mediaTagsPreviewAction,
                size: AppButtonSize.small,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _preview,
              ),
            ),
            if (_errorMessage != null) ...[
              SizedBox(height: spacing.md),
              Text(
                _errorMessage!,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.error,
                ),
              ),
            ],
            if (_matches != null) ...[
              SizedBox(height: spacing.md),
              if (_matches!.isEmpty)
                Text(
                  l10n.mediaTagsPreviewNoMatch,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.muted,
                  ),
                )
              else
                Wrap(
                  spacing: spacing.sm,
                  runSpacing: spacing.sm,
                  children: [
                    for (final match in _matches!)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppBadge(
                            label: match.name,
                            tone: AppBadgeTone.success,
                            size: AppBadgeSize.compact,
                          ),
                          SizedBox(height: spacing.xs),
                          Text(
                            l10n.mediaTagsPreviewMatchedTerm(match.matchedTerm),
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
            ],
          ],
        ),
      ),
    );
  }
}
