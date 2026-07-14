import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/config_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/config_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/section_loader_mixin.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

class DesktopDownloadPreferenceSection extends StatefulWidget {
  const DesktopDownloadPreferenceSection({super.key, required this.active});

  final bool active;

  @override
  State<DesktopDownloadPreferenceSection> createState() =>
      _DesktopDownloadPreferenceSectionState();
}

class _DesktopDownloadPreferenceSectionState
    extends State<DesktopDownloadPreferenceSection>
    with
        SectionLoaderMixin<ConfigResourceDto,
            DesktopDownloadPreferenceSection> {
  List<DownloadClientKind> _preferredClientKinds = const <DownloadClientKind>[
    DownloadClientKind.qbittorrent,
    DownloadClientKind.cloud115,
  ];
  bool _isSaving = false;

  @override
  bool get isSectionActive => widget.active;

  @override
  Future<ConfigResourceDto> fetchSectionData() =>
      context.read<ConfigApi>().get();

  @override
  void applySectionData(ConfigResourceDto data) {
    _preferredClientKinds = data.downloads.preferredClientKinds;
  }

  @override
  String get sectionLoadErrorFallback => '下载偏好加载失败，请稍后重试。';

  @override
  void initState() {
    super.initState();
    tryLoadIfActive();
  }

  @override
  void didUpdateWidget(covariant DesktopDownloadPreferenceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    tryLoadIfActive();
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final result = await context.read<ConfigApi>().patch(<String, dynamic>{
        'downloads': <String, dynamic>{
          'preferred_client_kinds': _preferredClientKinds
              .map((kind) => kind.wireValue)
              .toList(growable: false),
        },
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _preferredClientKinds = result.values.downloads.preferredClientKinds;
        _isSaving = false;
      });
      showToast(_saveMessage(result.pendingRestart));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      showToast(apiErrorMessage(error, fallback: '保存下载偏好失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildSectionStates(
      errorTitle: '下载偏好加载失败',
      skeletonLineCount: 3,
      buildLoaded: _buildLoaded,
    );
  }

  Widget _buildLoaded(BuildContext context) {
    final spacing = context.appSpacing;
    final selectedKind = _preferredClientKinds.first;
    return AppContentCard(
      key: const Key('configuration-download-preference-card'),
      title: '默认下载顺序',
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s16,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerBottomSpacing: spacing.md,
      headerTrailing: const AppBadge(
        label: '调度重启',
        tone: AppBadgeTone.warning,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '未显式选择下载器时，系统按此顺序自动选择。手动搜索和提交立即生效；自动下载任务需重启 APS 调度进程。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.lg),
          AppSelectField<DownloadClientKind>(
            key: const Key(
              'configuration-download-preference-client-field',
            ),
            label: '首选下载器',
            value: selectedKind,
            items: [
              for (final kind in DownloadClientKind.values)
                DropdownMenuItem<DownloadClientKind>(
                  value: kind,
                  child: Text(kind.label),
                ),
            ],
            onChanged: _isSaving
                ? null
                : (value) {
                    if (value == null || value == selectedKind) {
                      return;
                    }
                    setState(() {
                      _preferredClientKinds = <DownloadClientKind>[
                        value,
                        ...DownloadClientKind.values.where(
                          (kind) => kind != value,
                        ),
                      ];
                    });
                  },
          ),
          SizedBox(height: spacing.sm),
          Text(
            '${_preferredClientKinds.last.label} 会作为候补下载器。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              key: const Key('configuration-download-preference-save-button'),
              label: '保存偏好',
              variant: AppButtonVariant.primary,
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}

String _saveMessage(List<PendingRestartFieldDto> pendingRestart) {
  return pendingRestart.any((item) => item.restart == 'scheduler')
      ? '已保存，需重启 APS 调度进程才生效'
      : '已保存';
}
