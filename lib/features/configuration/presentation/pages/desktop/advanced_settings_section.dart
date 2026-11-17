import 'package:sakuramedia/widgets/base/actions/app_switch.dart';
import 'package:sakuramedia/widgets/base/forms/app_password_field.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/config_api_provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/validation/url_validators.dart';
import 'package:sakuramedia/features/configuration/data/api/config_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/config_dto.dart';
import 'package:sakuramedia/features/shared/presentation/restart_messages.dart';
import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

class DesktopAdvancedSettingsSection extends ConsumerStatefulWidget {
  const DesktopAdvancedSettingsSection({
    super.key,
    required this.active,
    this.onDirtyChanged,
  });

  final bool active;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  ConsumerState<DesktopAdvancedSettingsSection> createState() =>
      _DesktopAdvancedSettingsSectionState();
}

class _DesktopAdvancedSettingsSectionState
    extends ConsumerState<DesktopAdvancedSettingsSection> {
  final GlobalKey<FormState> _mediaFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _schedulerFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _otherFormKey = GlobalKey<FormState>();

  late final TextEditingController _allowedMinVideoFileSizeController;
  late final TextEditingController _workerDefaultConcurrencyController;
  late final Map<String, TextEditingController> _cronControllers;

  final Set<_AdvancedCardKind> _dirtyCards = <_AdvancedCardKind>{};
  final Set<_AdvancedCardKind> _savingCards = <_AdvancedCardKind>{};

  final _optionalFormKey = GlobalKey<FormState>();
  final _qdrantUrl = TextEditingController();
  final _qdrantKey = TextEditingController();
  final _inferenceUrl = TextEditingController();
  final _inferenceKey = TextEditingController();
  bool _hasOptionalServices = false;
  bool _qdrantEnabled = false;
  bool _imageSearchEnabled = false;

  bool _initialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _loggingLevel = _defaultLoggingLevel;
  String _savedLoggingLevel = _defaultLoggingLevel;

  ConfigApi get _api => ref.read(configApiProvider);

  @override
  void initState() {
    super.initState();
    _allowedMinVideoFileSizeController = TextEditingController();
    _workerDefaultConcurrencyController = TextEditingController();
    _cronControllers = <String, TextEditingController>{
      for (final key in AdvancedSchedulerConfigDto.cronKeys)
        key: TextEditingController(),
    };
    if (widget.active) {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant DesktopAdvancedSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_initialized && !_isLoading) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _qdrantUrl.dispose();
    _qdrantKey.dispose();
    _inferenceUrl.dispose();
    _inferenceKey.dispose();
    _allowedMinVideoFileSizeController.dispose();
    _workerDefaultConcurrencyController.dispose();
    for (final controller in _cronControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !widget.active) {
      return const SizedBox.shrink();
    }

    final content = _buildContent(context);
    return widget.active
        ? AppPageRefreshScope(onRefresh: _refresh, child: content)
        : content;
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_isLoading && _errorMessage != null) {
      return AppSectionError(
        title: l10n.errorAdvancedSettingsLoadFailed,
        message: _errorMessage!,
        onRetry: _load,
      );
    }

    final spacing = context.appSpacing;
    // loading 用当前（默认）字段值渲染真实设置卡，由 [AppSkeletonizer] 灰化；
    // 首次加载数据未到，按完整形态展示可选服务卡，避免数据到达后多出一张卡。
    // 仅首屏骨架：下拉刷新保留已展示的设置，不重铺骨架。
    return AppSkeletonizer(
      enabled: _isLoading && !_initialized,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMediaCard(context),
          SizedBox(height: spacing.xl),
          if (_hasOptionalServices || _isLoading) ...[
            _buildOptionalServicesCard(context),
            SizedBox(height: spacing.xl),
          ],
          _buildSchedulerCard(context),
          SizedBox(height: spacing.xl),
          _buildOtherCard(context),
        ],
      ),
    );
  }

  Widget _buildOptionalServicesCard(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final saving = _savingCards.contains(_AdvancedCardKind.optionalServices);
    return _AdvancedCard(
      cardKey: const Key('configuration-optional-services-card'),
      title: l10n.configOptionalServicesTitle,
      formKey: _optionalFormKey,
      dirty: _dirtyCards.contains(_AdvancedCardKind.optionalServices),
      saving: saving,
      saveButtonKey: const Key('configuration-optional-services-save'),
      onSave: _saveOptionalServices,
      children: [
        _CardTip(
          icon: Icons.info_outline_rounded,
          message: l10n.configOptionalServicesTip,
        ),
        SizedBox(height: spacing.md),
        _optionalSwitch(
          key: const Key('configuration-qdrant-enabled'),
          title: l10n.configQdrantEnabledTitle,
          subtitle: l10n.configQdrantEnabledSubtitle,
          value: _qdrantEnabled,
          onChanged: saving ? null : _changeQdrantEnabled,
        ),
        if (_qdrantEnabled)
          _buildFieldGrid(
            context,
            children: [
              AppTextField(
                controller: _qdrantUrl,
                label: l10n.configQdrantUrlLabel,
                hintText: 'http://qdrant:6333',
                helperText: l10n.configComposeDefaultHelper,
                fieldKey: const Key('configuration-qdrant-url'),
                enabled: !saving,
                validator: _httpUrlError,
                onChanged: (_) =>
                    _markDirty(_AdvancedCardKind.optionalServices),
              ),
              AppPasswordField(
                controller: _qdrantKey,
                label: l10n.configQdrantApiKeyLabel,
                enabled: !saving,
                onChanged: (_) =>
                    _markDirty(_AdvancedCardKind.optionalServices),
              ),
            ],
          ),
        SizedBox(height: spacing.md),
        _optionalSwitch(
          key: const Key('configuration-image-search-enabled'),
          title: l10n.configImageSearchEnabledTitle,
          subtitle: _qdrantEnabled
              ? l10n.configImageSearchEnabledSubtitle
              : l10n.configImageSearchRequiresQdrant,
          value: _imageSearchEnabled,
          onChanged: saving || !_qdrantEnabled
              ? null
              : (value) {
                  setState(() => _imageSearchEnabled = value);
                  _markDirty(_AdvancedCardKind.optionalServices);
                },
        ),
        if (_imageSearchEnabled)
          _buildFieldGrid(
            context,
            children: [
              AppTextField(
                controller: _inferenceUrl,
                label: l10n.configEmbeddingUrlLabel,
                hintText: 'http://siglip2-embed:8080',
                helperText: l10n.configComposeDefaultHelper,
                fieldKey: const Key('configuration-inference-url'),
                enabled: !saving,
                validator: _httpUrlError,
                onChanged: (_) =>
                    _markDirty(_AdvancedCardKind.optionalServices),
              ),
              AppPasswordField(
                controller: _inferenceKey,
                label: l10n.configEmbeddingApiKeyLabel,
                enabled: !saving,
                onChanged: (_) =>
                    _markDirty(_AdvancedCardKind.optionalServices),
              ),
            ],
          ),
      ],
    );
  }

  Widget _optionalSwitch({
    required Key key,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return AppSettingCell(
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.md),
      title: title,
      subtitle: subtitle,
      onTap: onChanged == null ? null : () => onChanged(!value),
      trailing: AppSwitch(key: key, value: value, onChanged: onChanged),
    );
  }

  Future<void> _changeQdrantEnabled(bool value) async {
    final l10n = AppLocalizations.of(context);
    if (!value && _imageSearchEnabled) {
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.configDisableVectorTitle,
        message: l10n.configDisableVectorMessage,
        confirmLabel: l10n.configDisableVectorConfirm,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _qdrantEnabled = value;
      if (!value) _imageSearchEnabled = false;
    });
    _markDirty(_AdvancedCardKind.optionalServices);
  }

  String? _httpUrlError(String? value) {
    return isValidHttpUrl(value ?? '')
        ? null
        : AppLocalizations.of(context).configInvalidHttpUrl;
  }

  Future<void> _saveOptionalServices() async {
    if (!(_optionalFormKey.currentState?.validate() ?? false)) return;
    await _savePartial(_AdvancedCardKind.optionalServices, {
      'qdrant': {
        'enabled': _qdrantEnabled,
        'url': _qdrantUrl.text.trim(),
        'api_key': _qdrantKey.text.trim(),
      },
      'image_search': {
        'enabled': _imageSearchEnabled,
        'inference_base_url': _inferenceUrl.text.trim(),
        'inference_api_key': _inferenceKey.text.trim(),
      },
    }, (values) => _applyOptionalServices(values.optionalServices));
  }

  void _applyOptionalServices(OptionalServicesConfigDto? config) {
    _hasOptionalServices = config != null;
    if (config == null) return;
    _qdrantEnabled = config.qdrantEnabled;
    _imageSearchEnabled = config.imageSearchEnabled;
    _qdrantUrl.text = config.qdrantUrl;
    _qdrantKey.text = config.qdrantApiKey;
    _inferenceUrl.text = config.inferenceUrl;
    _inferenceKey.text = config.inferenceApiKey;
  }

  Widget _buildMediaCard(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return _AdvancedCard(
      cardKey: const Key('configuration-advanced-media-card'),
      title: l10n.configMediaImportTitle,
      formKey: _mediaFormKey,
      dirty: _dirtyCards.contains(_AdvancedCardKind.media),
      saving: _savingCards.contains(_AdvancedCardKind.media),
      saveButtonKey: const Key('configuration-advanced-media-save-button'),
      onSave: _handleSaveMedia,
      children: [
        _CardTip(
          icon: Icons.info_outline_rounded,
          message: l10n.configMediaImportTip,
        ),
        SizedBox(height: spacing.lg),
        _buildFieldGrid(
          context,
          children: [
            AppTextField(
              fieldKey: const Key(
                'configuration-advanced-min-video-size-field',
              ),
              controller: _allowedMinVideoFileSizeController,
              label: l10n.configMinVideoSizeLabel,
              hintText: l10n.configMinVideoSizeHint,
              helperText: l10n.configMinVideoSizeHelper,
              keyboardType: TextInputType.number,
              suffix: const _UnitSuffix(label: 'MB'),
              tightSuffix: true,
              validator: (value) =>
                  _positiveIntError(value, label: l10n.configMinVideoSizeShort),
              onChanged: (_) => _markDirty(_AdvancedCardKind.media),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSchedulerCard(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final cronGroups = _buildCronGroups(l10n);
    return _AdvancedCard(
      cardKey: const Key('configuration-advanced-scheduler-card'),
      title: l10n.configSchedulerTitle,
      formKey: _schedulerFormKey,
      dirty: _dirtyCards.contains(_AdvancedCardKind.scheduler),
      saving: _savingCards.contains(_AdvancedCardKind.scheduler),
      saveButtonKey: const Key('configuration-advanced-scheduler-save-button'),
      onSave: _handleSaveScheduler,
      children: [
        _CardTip(
          icon: Icons.schedule_outlined,
          message: l10n.configSchedulerTip,
        ),
        SizedBox(height: spacing.lg),
        _SubsectionTitle(title: l10n.configWorkerSectionTitle),
        SizedBox(height: spacing.md),
        _buildFieldGrid(
          context,
          children: [
            AppTextField(
              fieldKey: const Key(
                'configuration-advanced-worker-default-concurrency-field',
              ),
              controller: _workerDefaultConcurrencyController,
              label: l10n.configWorkerConcurrencyLabel,
              hintText: '4',
              helperText: l10n.configWorkerConcurrencyHelper,
              keyboardType: TextInputType.number,
              suffix: _UnitSuffix(label: l10n.configWorkerConcurrencyUnit),
              tightSuffix: true,
              validator: _workerConcurrencyError,
              onChanged: (_) => _markDirty(_AdvancedCardKind.scheduler),
            ),
          ],
        ),
        SizedBox(height: spacing.lg),
        for (final group in cronGroups) ...[
          _SubsectionTitle(title: group.title),
          SizedBox(height: spacing.md),
          _buildFieldGrid(
            context,
            children: [
              for (final key in group.keys)
                AppTextField(
                  fieldKey: Key('configuration-advanced-cron-$key-field'),
                  controller: _cronControllers[key],
                  label: _cronCopy(l10n, key),
                  hintText: '0 2 * * *',
                  helperText: _cronFieldHelper(l10n, key),
                  validator: _cronError,
                  onChanged: (_) => _markDirty(_AdvancedCardKind.scheduler),
                ),
            ],
          ),
          if (group != cronGroups.last) SizedBox(height: spacing.lg),
        ],
      ],
    );
  }

  Widget _buildOtherCard(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return _AdvancedCard(
      cardKey: const Key('configuration-advanced-other-card'),
      title: l10n.configLoggingTitle,
      formKey: _otherFormKey,
      dirty: _dirtyCards.contains(_AdvancedCardKind.other),
      saving: _savingCards.contains(_AdvancedCardKind.other),
      saveButtonKey: const Key('configuration-advanced-other-save-button'),
      onSave: _handleSaveOther,
      children: [
        _CardTip(icon: Icons.tune_outlined, message: l10n.configLoggingTip),
        SizedBox(height: spacing.lg),
        _buildFieldGrid(
          context,
          children: [
            AppSelectField<String>(
              key: const Key('configuration-advanced-logging-level-field'),
              label: l10n.configLoggingLevelLabel,
              value: _loggingLevel,
              items: [
                for (final level in _loggingLevels)
                  DropdownMenuItem<String>(value: level, child: Text(level)),
              ],
              onChanged: _savingCards.contains(_AdvancedCardKind.other)
                  ? null
                  : (value) {
                      if (value == null || value == _loggingLevel) {
                        return;
                      }
                      setState(() {
                        _loggingLevel = value;
                      });
                      _markDirty(_AdvancedCardKind.other);
                    },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFieldGrid(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing;
        final layout = context.appLayoutTokens;
        final minTwoColumnWidth = layout.filterFieldWidthXl * 2 + spacing.md;
        final useTwoColumns = constraints.maxWidth >= minTwoColumnWidth;
        final fieldWidth = useTwoColumns
            ? (constraints.maxWidth - spacing.md) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: spacing.md,
          runSpacing: spacing.md,
          children: [
            for (final child in children)
              SizedBox(width: fieldWidth, child: child),
          ],
        );
      },
    );
  }

  Future<void> _load() async {
    if (_isLoading) {
      return;
    }
    // 打开/刷新高级设置时顺带重探服务器能力：可选服务开关保存并重启容器后，
    // 无需等概览刷新即可让侧栏与页面入口恢复。
    _scheduleCapabilitiesRefresh();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resource = await _api.get();
      if (!mounted) {
        return;
      }
      setState(() {
        _applyResource(resource);
        _initialized = true;
        _isLoading = false;
      });
      _notifyDirtyChanged();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _initialized = true;
        _isLoading = false;
        _errorMessage = apiErrorMessage(
          error,
          fallback: l10n.errorAdvancedSettingsLoadFailed,
          l10n: l10n,
        );
      });
    }
  }

  /// `_load` 可能由 `didUpdateWidget` 在 build 阶段触发，而 Riverpod 的
  /// `invalidate` 会同步对 ProviderScope 调用 `setState`，因此延后到帧结束。
  void _scheduleCapabilitiesRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(serverCapabilitiesProvider);
    });
  }

  Future<void> _refresh() async {
    if (_isLoading || _savingCards.isNotEmpty) {
      return;
    }
    if (_dirtyCards.isNotEmpty) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.configUnsavedChangesTitle,
        message: l10n.configUnsavedChangesMessage,
        confirmLabel: l10n.commonRefresh,
        dialogKey: const Key('configuration-advanced-refresh-confirm-dialog'),
        confirmKey: const Key('configuration-advanced-refresh-confirm-button'),
        cancelKey: const Key('configuration-advanced-refresh-cancel-button'),
      );
      if (!confirmed || !mounted) {
        return;
      }
    }
    await _load();
  }

  Future<void> _handleSaveMedia() async {
    if (!(_mediaFormKey.currentState?.validate() ?? false)) {
      return;
    }
    await _savePartial(_AdvancedCardKind.media, <String, dynamic>{
      'media': _buildMediaPayload(),
    }, (values) => _applyMedia(values.media));
  }

  Future<void> _handleSaveScheduler() async {
    if (!(_schedulerFormKey.currentState?.validate() ?? false)) {
      return;
    }
    await _savePartial(_AdvancedCardKind.scheduler, <String, dynamic>{
      'scheduler': _buildSchedulerPayload(),
    }, (values) => _applyScheduler(values.scheduler));
  }

  Future<void> _handleSaveOther() async {
    if (!(_otherFormKey.currentState?.validate() ?? false)) return;
    if (_loggingLevel != _savedLoggingLevel) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.configLoggingConfirmTitle,
        message: l10n.configLoggingConfirmMessage,
        confirmLabel: l10n.configContinueSave,
        dialogKey: const Key('configuration-advanced-logging-confirm-dialog'),
        confirmKey: const Key('configuration-advanced-logging-confirm-button'),
        cancelKey: const Key('configuration-advanced-logging-cancel-button'),
      );
      if (!confirmed || !mounted) {
        return;
      }
    }
    await _savePartial(
      _AdvancedCardKind.other,
      <String, dynamic>{'logging': _buildLoggingPayload()},
      (values) {
        _applyLogging(values.logging);
      },
    );
  }

  Future<void> _savePartial(
    _AdvancedCardKind card,
    Map<String, dynamic> partial,
    void Function(ConfigResourceDto values) applyValues,
  ) async {
    if (_savingCards.contains(card)) {
      return;
    }
    setState(() {
      _savingCards.add(card);
    });

    try {
      final result = await _api.patch(partial);
      if (!mounted) {
        return;
      }
      setState(() {
        applyValues(result.values);
        _savingCards.remove(card);
        _dirtyCards.remove(card);
      });
      _notifyDirtyChanged();
      showToast(
        buildAdvancedConfigSaveSuccessMessage(
          result.restartRequired,
          AppLocalizations.of(context),
        ),
        tone: AppToastTone.warning,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _savingCards.remove(card);
      });
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.errorAdvancedSettingsSaveFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  Map<String, dynamic> _buildMediaPayload() {
    return <String, dynamic>{
      'allowed_min_video_file_size':
          _parseInt(_allowedMinVideoFileSizeController.text) *
          _bytesPerMegabyte,
    };
  }

  Map<String, dynamic> _buildSchedulerPayload() {
    return <String, dynamic>{
      'worker_default_concurrency': _parseInt(
        _workerDefaultConcurrencyController.text,
      ),
      for (final key in AdvancedSchedulerConfigDto.cronKeys)
        '${key}_cron': _cronControllers[key]!.text.trim(),
    };
  }

  Map<String, dynamic> _buildLoggingPayload() {
    return <String, dynamic>{'level': _loggingLevel};
  }

  void _applyResource(ConfigResourceDto resource) {
    _applyOptionalServices(resource.optionalServices);
    _applyMedia(resource.media);
    _applyScheduler(resource.scheduler);
    _applyLogging(resource.logging);
    _dirtyCards.clear();
  }

  void _applyMedia(AdvancedMediaConfigDto media) {
    _allowedMinVideoFileSizeController.text =
        (media.allowedMinVideoFileSize ~/ _bytesPerMegabyte).toString();
  }

  void _applyScheduler(AdvancedSchedulerConfigDto scheduler) {
    _workerDefaultConcurrencyController.text = scheduler
        .workerDefaultConcurrency
        .toString();
    for (final key in AdvancedSchedulerConfigDto.cronKeys) {
      _cronControllers[key]!.text = scheduler.crons[key]!;
    }
  }

  void _applyLogging(AdvancedLoggingConfigDto logging) {
    _loggingLevel = _loggingLevels.contains(logging.level)
        ? logging.level
        : _defaultLoggingLevel;
    _savedLoggingLevel = _loggingLevel;
  }

  void _markDirty(_AdvancedCardKind card) {
    setState(() {
      _dirtyCards.add(card);
    });
    _notifyDirtyChanged();
  }

  void _notifyDirtyChanged() {
    widget.onDirtyChanged?.call(_dirtyCards.isNotEmpty);
  }

  String? _cronError(String? value) {
    final parts = (value?.trim() ?? '')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length != _cronPartCount) {
      return AppLocalizations.of(context).configCronRequired;
    }
    return null;
  }

  String? _positiveIntError(String? value, {required String label}) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return AppLocalizations.of(context).configPositiveIntRequired(label);
    }
    return null;
  }

  String? _workerConcurrencyError(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null ||
        parsed < _workerConcurrencyMin ||
        parsed > _workerConcurrencyMax) {
      return AppLocalizations.of(context).configWorkerConcurrencyRange(
        _workerConcurrencyMin,
        _workerConcurrencyMax,
      );
    }
    return null;
  }

  int _parseInt(String value) {
    return int.parse(value.trim());
  }
}

enum _AdvancedCardKind { media, scheduler, other, optionalServices }

/// 根据 `PATCH /config` 响应里的 `restart_required` 列表拼保存成功后的 toast 文案。
///
/// 抽为顶层函数便于单元测试（widget 测里 oktoast 在 test env 下不可靠）。
String buildAdvancedConfigSaveSuccessMessage(
  List<String> restartRequired,
  AppLocalizations l10n,
) {
  final saved = l10n.commonSaved;
  if (restartRequired.isEmpty) {
    return saved;
  }
  return buildRestartRequiredMessage(saved, l10n);
}

class _AdvancedCard extends StatelessWidget {
  const _AdvancedCard({
    required this.cardKey,
    required this.title,
    required this.formKey,
    required this.dirty,
    required this.saving,
    required this.saveButtonKey,
    required this.onSave,
    required this.children,
  });

  final Key cardKey;
  final String title;
  final GlobalKey<FormState> formKey;
  final bool dirty;
  final bool saving;
  final Key saveButtonKey;
  final VoidCallback onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return AppContentCard(
      key: cardKey,
      title: title,
      padding: EdgeInsets.all(spacing.lg),
      headerBottomSpacing: spacing.md,
      headerTrailing: _CardBadges(
        badges: [
          AppBadge(
            label: l10n.configRestartRequiredBadge,
            tone: AppBadgeTone.warning,
          ),
          if (dirty)
            AppBadge(
              label: l10n.configUnsavedBadge,
              tone: AppBadgeTone.warning,
            ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...children,
            SizedBox(height: spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: context.appLayoutTokens.filterFieldWidthMd,
                  child: AppButton(
                    key: saveButtonKey,
                    label: l10n.commonSave,
                    variant: AppButtonVariant.primary,
                    isLoading: saving,
                    onPressed: onSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBadges extends StatelessWidget {
  const _CardBadges({required this.badges});

  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.xs,
      alignment: WrapAlignment.end,
      children: badges,
    );
  }
}

class _CardTip extends StatelessWidget {
  const _CardTip({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.appColors.noticeSurface,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: context.appComponentTokens.iconSizeSm,
            color: context.appTextPalette.muted,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              message,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubsectionTitle extends StatelessWidget {
  const _SubsectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
    );
  }
}

class _UnitSuffix extends StatelessWidget {
  const _UnitSuffix({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      widthFactor: 1,
      heightFactor: 1,
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(right: context.appSpacing.md),
        child: Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
      ),
    );
  }
}

class _CronGroup {
  const _CronGroup({required this.title, required this.keys});

  final String title;
  final List<String> keys;
}

const int _bytesPerMegabyte = 1024 * 1024;
const int _cronPartCount = 5;
const int _workerConcurrencyMin = 1;
const int _workerConcurrencyMax = 32;
const String _defaultLoggingLevel = 'INFO';
const List<String> _loggingLevels = <String>[
  'DEBUG',
  'INFO',
  'WARNING',
  'ERROR',
  'CRITICAL',
];

List<_CronGroup> _buildCronGroups(AppLocalizations l10n) => <_CronGroup>[
  _CronGroup(
    title: l10n.configCronGroupDownloadImport,
    keys: <String>[
      'download_task_sync',
      'download_task_auto_import',
      'subscribed_movie_auto_download',
    ],
  ),
  _CronGroup(
    title: l10n.configCronGroupScrapeBackfill,
    keys: <String>[
      'actor_subscription_sync',
      'media_file_hash_backfill',
      'gfriends_filetree_refresh',
    ],
  ),
  _CronGroup(
    title: l10n.configOptionalServicesTitle,
    keys: <String>['image_search_index', 'movie_similarity_recompute'],
  ),
  _CronGroup(
    title: l10n.configCronGroupRecommendation,
    keys: <String>[
      'moment_recommendation_generate',
      'daily_recommendation_generate',
    ],
  ),
  _CronGroup(
    title: l10n.configCronGroupMaintenance,
    keys: <String>[
      'media_thumbnail',
      'movie_stats_sync',
      'media_file_scan',
      'activity_cleanup',
    ],
  ),
];

String _cronCopy(AppLocalizations l10n, String key) => switch (key) {
  'actor_subscription_sync' => l10n.taskNameActorSubscriptionSync,
  'subscribed_movie_auto_download' => l10n.taskNameSubscribedMovieAutoDownload,
  'download_task_sync' => l10n.taskNameDownloadTaskSync,
  'download_task_auto_import' => l10n.taskNameDownloadTaskAutoImport,
  'movie_stats_sync' => l10n.taskNameMovieStatsSync,
  'media_file_hash_backfill' => l10n.taskNameMediaFileHashBackfill,
  'media_file_scan' => l10n.taskNameMediaFileScan,
  'media_thumbnail' => l10n.taskNameMediaThumbnailGeneration,
  'image_search_index' => l10n.taskNameImageSearchIndex,
  'movie_similarity_recompute' => l10n.taskNameMovieSimilarityRecompute,
  'moment_recommendation_generate' => l10n.taskNameMomentRecommendationGenerate,
  'daily_recommendation_generate' => l10n.taskNameDailyRecommendationGenerate,
  'activity_cleanup' => l10n.taskNameActivityRecordCleanup,
  'gfriends_filetree_refresh' => l10n.taskNameGfriendsFiletreeRefresh,
  _ => key,
};

String _cronFieldHelper(AppLocalizations l10n, String key) => switch (key) {
  'actor_subscription_sync' => l10n.taskHelpActorSubscriptionSync,
  'subscribed_movie_auto_download' => l10n.taskHelpSubscribedMovieAutoDownload,
  'download_task_sync' => l10n.taskHelpDownloadTaskSync,
  'download_task_auto_import' => l10n.taskHelpDownloadTaskAutoImport,
  'movie_stats_sync' => l10n.taskHelpMovieStatsSync,
  'media_file_hash_backfill' => l10n.taskHelpMediaFileHashBackfill,
  'media_file_scan' => l10n.taskHelpMediaFileScan,
  'media_thumbnail' => l10n.taskHelpMediaThumbnailGeneration,
  'image_search_index' => l10n.taskHelpImageSearchIndex,
  'movie_similarity_recompute' => l10n.taskHelpMovieSimilarityRecompute,
  'moment_recommendation_generate' => l10n.taskHelpMomentRecommendationGenerate,
  'daily_recommendation_generate' => l10n.taskHelpDailyRecommendationGenerate,
  'activity_cleanup' => l10n.taskHelpActivityRecordCleanup,
  'gfriends_filetree_refresh' => l10n.taskHelpGfriendsFiletreeRefresh,
  _ => '',
};
