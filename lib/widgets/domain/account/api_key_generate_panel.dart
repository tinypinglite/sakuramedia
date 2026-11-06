import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/platform/clipboard_copy.dart';
import 'package:sakuramedia/features/account/data/account_dto.dart';
import 'package:sakuramedia/features/account/presentation/providers/api_keys_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// 生成 API 密钥：先备注名后生成，生成成功后切换为一次性明文展示与复制。
///
/// 桌面端在 `AppDesktopDialog` 内展示，移动端塞进底部抽屉；
/// [keyPrefix] 派生本流程的控件 Key（`<keyPrefix>-api-key-...`）。
class ApiKeyGeneratePanel extends ConsumerStatefulWidget {
  const ApiKeyGeneratePanel({super.key, required this.keyPrefix});

  final String keyPrefix;

  @override
  ConsumerState<ApiKeyGeneratePanel> createState() =>
      _ApiKeyGeneratePanelState();
}

class _ApiKeyGeneratePanelState extends ConsumerState<ApiKeyGeneratePanel> {
  final TextEditingController _nameController = TextEditingController();
  bool _isGenerating = false;
  String? _errorMessage;
  ApiKeyCreatedDto? _created;

  Key get _nameFieldKey => Key('${widget.keyPrefix}-api-key-name-field');

  Key get _generateSubmitKey =>
      Key('${widget.keyPrefix}-api-key-generate-submit');

  Key get _secretTextKey => Key('${widget.keyPrefix}-api-key-secret-text');

  Key get _copyButtonKey => Key('${widget.keyPrefix}-api-key-copy-button');

  Key get _doneButtonKey => Key('${widget.keyPrefix}-api-key-done-button');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_isGenerating) {
      return;
    }
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });
    try {
      final created = await ref
          .read(apiKeysProvider.notifier)
          .create(name: _nameController.text.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _created = created;
        _isGenerating = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isGenerating = false;
        _errorMessage = apiErrorMessage(
          error,
          fallback: l10n.errorApiKeyGenerateFailed,
          l10n: l10n,
        );
      });
    }
  }

  Future<void> _copyKey(String key) async {
    final copied = await copyTextToClipboard(key);
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    showToast(
      copied ? l10n.apiKeyCopied : l10n.apiKeyCopyFailed,
      tone: copied ? AppToastTone.success : AppToastTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    return created == null
        ? _buildForm(context)
        : _buildResult(context, created);
  }

  Widget _buildForm(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.apiKeyGenerateTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.md),
        AppTextField(
          fieldKey: _nameFieldKey,
          controller: _nameController,
          label: l10n.apiKeyNameLabel,
          hintText: l10n.apiKeyNameHint,
          enabled: !_isGenerating,
          onFieldSubmitted: (_) => _generate(),
        ),
        if (_errorMessage != null) ...[
          SizedBox(height: spacing.sm),
          Text(
            _errorMessage!,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.error,
            ),
          ),
        ],
        SizedBox(height: spacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.commonCancel,
                onPressed: _isGenerating
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: AppButton(
                key: _generateSubmitKey,
                label: l10n.apiKeyGenerateAction,
                variant: AppButtonVariant.primary,
                isLoading: _isGenerating,
                onPressed: _generate,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, ApiKeyCreatedDto created) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.apiKeyGeneratedTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.md),
        Container(
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: context.appColors.warningSurface,
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(
              color: context.appTextPalette.warning.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            l10n.apiKeyOnlyOnceNotice,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.warning,
            ),
          ),
        ),
        SizedBox(height: spacing.md),
        Container(
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: context.appColors.surfaceMuted,
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(color: context.appColors.borderSubtle),
          ),
          child: SelectableText(
            created.key,
            key: _secretTextKey,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.primary,
            ),
          ),
        ),
        SizedBox(height: spacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                key: _copyButtonKey,
                label: l10n.commonCopy,
                icon: const Icon(Icons.copy_rounded),
                onPressed: () => _copyKey(created.key),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: AppButton(
                key: _doneButtonKey,
                label: l10n.commonDone,
                variant: AppButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
