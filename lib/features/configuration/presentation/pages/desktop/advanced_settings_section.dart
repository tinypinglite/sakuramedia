import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/config_api_provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/validation/url_validators.dart';
import 'package:sakuramedia/features/configuration/data/api/config_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/config_dto.dart';
import 'package:sakuramedia/features/shared/presentation/restart_messages.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

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
  final GlobalKey<FormState> _metadataFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _schedulerFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _otherFormKey = GlobalKey<FormState>();

  late final TextEditingController _innerSubTagsController;
  late final TextEditingController _bluerayTagsController;
  late final TextEditingController _uncensoredTagsController;
  late final TextEditingController _uncensoredPrefixController;
  late final TextEditingController _allowedMinVideoFileSizeController;
  late final TextEditingController _javdbHostController;
  late final Map<String, TextEditingController> _cronControllers;

  final Set<_AdvancedCardKind> _dirtyCards = <_AdvancedCardKind>{};
  final Set<_AdvancedCardKind> _savingCards = <_AdvancedCardKind>{};

  bool _initialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _loggingLevel = _defaultLoggingLevel;
  String _savedLoggingLevel = _defaultLoggingLevel;

  ConfigApi get _api => ref.read(configApiProvider);

  @override
  void initState() {
    super.initState();
    _innerSubTagsController = TextEditingController();
    _bluerayTagsController = TextEditingController();
    _uncensoredTagsController = TextEditingController();
    _uncensoredPrefixController = TextEditingController();
    _allowedMinVideoFileSizeController = TextEditingController();
    _javdbHostController = TextEditingController();
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
    _innerSubTagsController.dispose();
    _bluerayTagsController.dispose();
    _uncensoredTagsController.dispose();
    _uncensoredPrefixController.dispose();
    _allowedMinVideoFileSizeController.dispose();
    _javdbHostController.dispose();
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
    if (_isLoading) {
      return const AppSectionSkeleton(lineCount: _advancedSkeletonLineCount);
    }
    if (_errorMessage != null) {
      return AppSectionError(
        title: '高级设置加载失败',
        message: _errorMessage!,
        onRetry: _load,
      );
    }

    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMediaCard(context),
        SizedBox(height: spacing.xl),
        _buildMetadataCard(context),
        SizedBox(height: spacing.xl),
        _buildSchedulerCard(context),
        SizedBox(height: spacing.xl),
        _buildOtherCard(context),
      ],
    );
  }

  Widget _buildMediaCard(BuildContext context) {
    final spacing = context.appSpacing;
    return AppContentCard(
      key: const Key('configuration-advanced-media-card'),
      title: '媒体识别',
      padding: EdgeInsets.all(spacing.lg),
      headerBottomSpacing: spacing.md,
      headerTrailing: _CardBadges(
        badges: [
          const AppBadge(label: '重启容器生效', tone: AppBadgeTone.warning),
          if (_dirtyCards.contains(_AdvancedCardKind.media))
            const AppBadge(label: '未保存', tone: AppBadgeTone.warning),
        ],
      ),
      child: Form(
        key: _mediaFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTip(
              icon: Icons.info_outline_rounded,
              message: '这组配置控制媒体识别、标签判断和导入文件大小。第一次部署通常保持默认，只有明确知道资源命名规则时再调整。',
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
                  label: '允许导入的视频最小体积',
                  hintText: '建议不低于 256',
                  helperText: 'UI 按 MB 编辑，保存时会转换为字节；不建议低于 256 MB。',
                  keyboardType: TextInputType.number,
                  suffix: const _UnitSuffix(label: 'MB'),
                  tightSuffix: true,
                  validator: (value) => _positiveIntError(value, label: '最小体积'),
                  onChanged: (_) => _markDirty(_AdvancedCardKind.media),
                ),
              ],
            ),
            SizedBox(height: spacing.lg),
            const _SubsectionTitle(title: '标签识别'),
            SizedBox(height: spacing.md),
            _buildListField(
              controller: _innerSubTagsController,
              fieldKey: const Key(
                'configuration-advanced-inner-sub-tags-field',
              ),
              label: '内嵌字幕标签',
              hintText: '每行一条，例如 字幕组',
              onChanged: () => _markDirty(_AdvancedCardKind.media),
            ),
            SizedBox(height: spacing.md),
            _buildListField(
              controller: _bluerayTagsController,
              fieldKey: const Key('configuration-advanced-blueray-tags-field'),
              label: '蓝光 / 高清标签',
              hintText: '每行一条，例如 4K',
              onChanged: () => _markDirty(_AdvancedCardKind.media),
            ),
            SizedBox(height: spacing.md),
            _buildListField(
              controller: _uncensoredTagsController,
              fieldKey: const Key(
                'configuration-advanced-uncensored-tags-field',
              ),
              label: '无码资源标签',
              hintText: '每行一条，例如 uncensored',
              onChanged: () => _markDirty(_AdvancedCardKind.media),
            ),
            SizedBox(height: spacing.md),
            _buildListField(
              controller: _uncensoredPrefixController,
              fieldKey: const Key(
                'configuration-advanced-uncensored-prefix-field',
              ),
              label: '无码资源番号前缀',
              hintText: '每行一条，例如 PT-',
              onChanged: () => _markDirty(_AdvancedCardKind.media),
            ),
            SizedBox(height: spacing.lg),
            _buildActions(
              context,
              buttonKey: const Key('configuration-advanced-media-save-button'),
              isSaving: _savingCards.contains(_AdvancedCardKind.media),
              onSave: _handleSaveMedia,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(BuildContext context) {
    final spacing = context.appSpacing;
    return AppContentCard(
      key: const Key('configuration-advanced-metadata-card'),
      title: '元数据抓取',
      padding: EdgeInsets.all(spacing.lg),
      headerBottomSpacing: spacing.md,
      headerTrailing: _CardBadges(
        badges: [
          const AppBadge(label: '重启容器生效', tone: AppBadgeTone.warning),
          if (_dirtyCards.contains(_AdvancedCardKind.metadata))
            const AppBadge(label: '未保存', tone: AppBadgeTone.warning),
        ],
      ),
      child: Form(
        key: _metadataFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTip(
              icon: Icons.travel_explore_outlined,
              message:
                  '外部站点请求（JavDB / GFriends）统一跟随容器环境变量 HTTP_PROXY / HTTPS_PROXY / NO_PROXY 分流，不再在应用内配置代理；排行榜来源与账号由插件自行管理。',
            ),
            SizedBox(height: spacing.lg),
            AppTextField(
              fieldKey: const Key('configuration-advanced-javdb-host-field'),
              controller: _javdbHostController,
              label: 'JavDB API 域名',
              hintText: 'jdforrepam.com',
              helperText: '裸域名或 IP，不带 http/https 协议头。',
              keyboardType: TextInputType.url,
              validator: _javdbHostError,
              onChanged: (_) => _markDirty(_AdvancedCardKind.metadata),
            ),
            SizedBox(height: spacing.lg),
            _buildActions(
              context,
              buttonKey: const Key(
                'configuration-advanced-metadata-save-button',
              ),
              isSaving: _savingCards.contains(_AdvancedCardKind.metadata),
              onSave: _handleSaveMetadata,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulerCard(BuildContext context) {
    final spacing = context.appSpacing;
    return AppContentCard(
      key: const Key('configuration-advanced-scheduler-card'),
      title: '定时任务频率',
      padding: EdgeInsets.all(spacing.lg),
      headerBottomSpacing: spacing.md,
      headerTrailing: _CardBadges(
        badges: [
          const AppBadge(label: '重启容器生效', tone: AppBadgeTone.warning),
          if (_dirtyCards.contains(_AdvancedCardKind.scheduler))
            const AppBadge(label: '未保存', tone: AppBadgeTone.warning),
        ],
      ),
      child: Form(
        key: _schedulerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTip(
              icon: Icons.schedule_outlined,
              message: 'Cron 语法：分 时 日 月 周（*/N 每隔 N，逗号列表，连字符区间）。修改后需要重启容器才生效。',
            ),
            SizedBox(height: spacing.lg),
            for (final group in _cronGroups) ...[
              _SubsectionTitle(title: group.title),
              SizedBox(height: spacing.md),
              _buildFieldGrid(
                context,
                children: [
                  for (final key in group.keys)
                    AppTextField(
                      fieldKey: Key('configuration-advanced-cron-$key-field'),
                      controller: _cronControllers[key],
                      label: _cronCopy[key] ?? key,
                      hintText: '0 2 * * *',
                      helperText: _cronFieldHelper[key],
                      validator: _cronError,
                      onChanged: (_) => _markDirty(_AdvancedCardKind.scheduler),
                    ),
                ],
              ),
              if (group != _cronGroups.last) SizedBox(height: spacing.lg),
            ],
            SizedBox(height: spacing.lg),
            _buildActions(
              context,
              buttonKey: const Key(
                'configuration-advanced-scheduler-save-button',
              ),
              isSaving: _savingCards.contains(_AdvancedCardKind.scheduler),
              onSave: _handleSaveScheduler,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherCard(BuildContext context) {
    final spacing = context.appSpacing;
    return AppContentCard(
      key: const Key('configuration-advanced-other-card'),
      title: '日志',
      padding: EdgeInsets.all(spacing.lg),
      headerBottomSpacing: spacing.md,
      headerTrailing: _CardBadges(
        badges: [
          const AppBadge(label: '重启容器生效', tone: AppBadgeTone.warning),
          if (_dirtyCards.contains(_AdvancedCardKind.other))
            const AppBadge(label: '未保存', tone: AppBadgeTone.warning),
        ],
      ),
      child: Form(
        key: _otherFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTip(
              icon: Icons.tune_outlined,
              message: '日志等级平时保持 INFO，排查问题时再临时改成 DEBUG。',
            ),
            SizedBox(height: spacing.lg),
            _buildFieldGrid(
              context,
              children: [
                AppSelectField<String>(
                  key: const Key('configuration-advanced-logging-level-field'),
                  label: '日志等级',
                  value: _loggingLevel,
                  items: [
                    for (final level in _loggingLevels)
                      DropdownMenuItem<String>(
                        value: level,
                        child: Text(level),
                      ),
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
            SizedBox(height: spacing.lg),
            _buildActions(
              context,
              buttonKey: const Key('configuration-advanced-other-save-button'),
              isSaving: _savingCards.contains(_AdvancedCardKind.other),
              onSave: _handleSaveOther,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListField({
    required TextEditingController controller,
    required Key fieldKey,
    required String label,
    required String hintText,
    required VoidCallback onChanged,
  }) {
    return AppTextField(
      fieldKey: fieldKey,
      controller: controller,
      label: label,
      hintText: hintText,
      helperText: _buildListPreview(controller.text),
      minLines: _multilineMinLines,
      maxLines: _multilineMaxLines,
      onChanged: (_) => onChanged(),
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

  Widget _buildActions(
    BuildContext context, {
    required Key buttonKey,
    required bool isSaving,
    required VoidCallback onSave,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: context.appLayoutTokens.filterFieldWidthMd,
          child: AppButton(
            key: buttonKey,
            label: '保存',
            variant: AppButtonVariant.primary,
            isLoading: isSaving,
            onPressed: onSave,
          ),
        ),
      ],
    );
  }

  Future<void> _load() async {
    if (_isLoading) {
      return;
    }
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
      setState(() {
        _initialized = true;
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '高级设置加载失败');
      });
    }
  }

  Future<void> _handleSaveMedia() async {
    if (!(_mediaFormKey.currentState?.validate() ?? false)) {
      return;
    }
    await _savePartial(_AdvancedCardKind.media, <String, dynamic>{
      'media': _buildMediaPayload(),
    }, (values) => _applyMedia(values.media));
  }

  Future<void> _handleSaveMetadata() async {
    if (!(_metadataFormKey.currentState?.validate() ?? false)) {
      return;
    }
    await _savePartial(_AdvancedCardKind.metadata, <String, dynamic>{
      'metadata': _buildMetadataPayload(),
    }, (values) => _applyMetadata(values.metadata));
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
      final confirmed = await showAppConfirmDialog(
        context,
        title: '确认修改日志等级',
        message: '修改日志等级将重启容器，页面会临时无响应并需刷新，是否继续？',
        confirmLabel: '继续保存',
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
      showToast(buildAdvancedConfigSaveSuccessMessage(result.restartRequired));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingCards.remove(card);
      });
      showToast(apiErrorMessage(error, fallback: '保存高级设置失败'));
    }
  }

  Map<String, dynamic> _buildMediaPayload() {
    return <String, dynamic>{
      'inner_sub_tags': _splitMultilineValues(_innerSubTagsController.text),
      'blueray_tags': _splitMultilineValues(_bluerayTagsController.text),
      'uncensored_tags': _splitMultilineValues(_uncensoredTagsController.text),
      'uncensored_prefix': _splitMultilineValues(
        _uncensoredPrefixController.text,
      ),
      'allowed_min_video_file_size':
          _parseInt(_allowedMinVideoFileSizeController.text) *
          _bytesPerMegabyte,
    };
  }

  Map<String, dynamic> _buildMetadataPayload() {
    return <String, dynamic>{'javdb_host': _javdbHostController.text.trim()};
  }

  Map<String, dynamic> _buildSchedulerPayload() {
    return <String, dynamic>{
      for (final key in AdvancedSchedulerConfigDto.cronKeys)
        '${key}_cron': _cronControllers[key]!.text.trim(),
    };
  }

  Map<String, dynamic> _buildLoggingPayload() {
    return <String, dynamic>{'level': _loggingLevel};
  }

  void _applyResource(ConfigResourceDto resource) {
    _applyMedia(resource.media);
    _applyMetadata(resource.metadata);
    _applyScheduler(resource.scheduler);
    _applyLogging(resource.logging);
    _dirtyCards.clear();
  }

  void _applyMedia(AdvancedMediaConfigDto media) {
    _innerSubTagsController.text = media.innerSubTags.join('\n');
    _bluerayTagsController.text = media.bluerayTags.join('\n');
    _uncensoredTagsController.text = media.uncensoredTags.join('\n');
    _uncensoredPrefixController.text = media.uncensoredPrefix.join('\n');
    _allowedMinVideoFileSizeController.text =
        (media.allowedMinVideoFileSize ~/ _bytesPerMegabyte).toString();
  }

  void _applyMetadata(AdvancedMetadataConfigDto metadata) {
    _javdbHostController.text = metadata.javdbHost;
  }

  void _applyScheduler(AdvancedSchedulerConfigDto scheduler) {
    for (final key in AdvancedSchedulerConfigDto.cronKeys) {
      _cronControllers[key]!.text = scheduler.crons[key] ?? '';
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

  String? _javdbHostError(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || !isValidHostname(trimmed)) {
      return '请输入不带协议头的域名或 IP';
    }
    return null;
  }

  String? _cronError(String? value) {
    final parts = (value?.trim() ?? '')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length != _cronPartCount) {
      return '请输入 5 位标准 cron';
    }
    return null;
  }

  String? _positiveIntError(String? value, {required String label}) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return '请输入大于 0 的$label';
    }
    return null;
  }

  int _parseInt(String value) {
    return int.parse(value.trim());
  }

  String _buildListPreview(String text) {
    final values = _splitMultilineValues(text);
    if (values.isEmpty) {
      return '尚未识别条目';
    }
    final visibleValues = values.take(_previewItemCount).join(', ');
    final suffix = values.length > _previewItemCount ? ', ...' : '';
    return '已识别 ${values.length} 条：$visibleValues$suffix';
  }

  List<String> _splitMultilineValues(String text) {
    return _rawLines(
      text,
    ).map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
  }

  List<String> _rawLines(String text) {
    return text.split(RegExp(r'\r?\n'));
  }
}

enum _AdvancedCardKind { media, metadata, scheduler, other }

/// 根据 `PATCH /config` 响应里的 `restart_required` 列表拼保存成功后的 toast 文案。
///
/// 抽为顶层函数便于单元测试（widget 测里 oktoast 在 test env 下不可靠）。
String buildAdvancedConfigSaveSuccessMessage(List<String> restartRequired) {
  if (restartRequired.isEmpty) {
    return '已保存';
  }
  return buildRestartRequiredMessage('已保存');
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
const int _advancedSkeletonLineCount = 8;
const int _multilineMinLines = 3;
const int _multilineMaxLines = 6;
const int _cronPartCount = 5;
const int _previewItemCount = 6;
const String _defaultLoggingLevel = 'INFO';
const List<String> _loggingLevels = <String>[
  'DEBUG',
  'INFO',
  'WARNING',
  'ERROR',
  'CRITICAL',
];

const List<_CronGroup> _cronGroups = <_CronGroup>[
  _CronGroup(
    title: '下载 / 导入',
    keys: <String>[
      'download_task_sync',
      'download_task_auto_import',
      'download_small_file_cleanup',
      'subscribed_movie_auto_download',
    ],
  ),
  _CronGroup(
    title: '抓取 / 回填',
    keys: <String>['hot_review_sync', 'actor_subscription_sync'],
  ),
  _CronGroup(
    title: '图搜 / 相似度',
    keys: <String>[
      'image_search_index',
      'image_search_optimize',
      'movie_similarity_recompute',
    ],
  ),
  _CronGroup(
    title: '推荐',
    keys: <String>[
      'moment_recommendation_generate',
      'daily_recommendation_generate',
    ],
  ),
  _CronGroup(
    title: '巡检 / 清理',
    keys: <String>[
      'media_file_scan',
      'media_thumbnail',
      'movie_heat',
      'movie_interaction_sync',
      'activity_cleanup',
    ],
  ),
];

const Map<String, String> _cronCopy = <String, String>{
  'actor_subscription_sync': '订阅女优影片同步',
  'subscribed_movie_auto_download': '已订阅缺失影片自动下载',
  'download_task_sync': '下载任务状态同步',
  'download_task_auto_import': '已完成下载自动导入',
  'download_small_file_cleanup': '下载小文件清理',
  'movie_heat': '影片热度重算',
  'movie_interaction_sync': '影片互动数同步',
  'hot_review_sync': 'JavDB 热评同步',
  'media_file_scan': '媒体文件巡检',
  'media_thumbnail': '缩略图生成',
  'image_search_index': '图片搜索索引生成',
  'image_search_optimize': '图片搜索索引优化',
  'movie_similarity_recompute': '影片相似度离线重算',
  'moment_recommendation_generate': '推荐时刻生成',
  'daily_recommendation_generate': '每日推荐快照生成',
  'activity_cleanup': '任务中心数据清理',
};

const Map<String, String> _cronFieldHelper = <String, String>{
  'actor_subscription_sync': '同步订阅女优的影片数据。',
  'subscribed_movie_auto_download': '自动下载已订阅但缺失的影片。',
  'download_task_sync': '同步下载任务状态。',
  'download_task_auto_import': '导入已完成的下载任务。',
  'download_small_file_cleanup': '清理下载任务中的无效小文件。',
  'movie_heat': '重算影片热度。',
  'movie_interaction_sync': '同步影片互动数，候选仍受分层刷新规则影响。',
  'hot_review_sync': '同步 JavDB 热评。',
  'media_file_scan': '巡检媒体文件。',
  'media_thumbnail': '生成媒体缩略图。',
  'image_search_index': '生成图片搜索索引。',
  'image_search_optimize': '优化图片搜索索引。',
  'movie_similarity_recompute': '离线重算影片相似度。',
  'moment_recommendation_generate': '生成推荐时刻。',
  'daily_recommendation_generate': '生成每日推荐快照。',
  'activity_cleanup': '清理任务中心的通知与任务运行数据。',
};
