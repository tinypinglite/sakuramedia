import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_preference_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_preference_state.dart';
import 'package:sakuramedia/features/shared/presentation/restart_messages.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

class DesktopDownloadPreferenceSection extends ConsumerStatefulWidget {
  const DesktopDownloadPreferenceSection({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<DesktopDownloadPreferenceSection> createState() =>
      _DesktopDownloadPreferenceSectionState();
}

class _DesktopDownloadPreferenceSectionState
    extends ConsumerState<DesktopDownloadPreferenceSection> {
  Future<void> _save() async {
    try {
      final restartRequired =
          await ref.read(downloadPreferenceProvider.notifier).save();
      if (!mounted) {
        return;
      }
      showToast(_saveMessage(restartRequired));
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '保存下载偏好失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final async = ref.watch(downloadPreferenceProvider);
    return async.when(
      loading: () => const AppSectionSkeleton(lineCount: 3),
      error:
          (error, _) => AppSectionError(
            title: '下载偏好加载失败',
            message: apiErrorMessage(error, fallback: '下载偏好加载失败，请稍后重试。'),
            onRetry: () async => ref.invalidate(downloadPreferenceProvider),
          ),
      data: (state) => _buildLoaded(context, state),
    );
  }

  Widget _buildLoaded(BuildContext context, DownloadPreferenceState state) {
    final spacing = context.appSpacing;
    final selectedKind = state.draftKinds.first;
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
        label: '重启容器生效',
        tone: AppBadgeTone.warning,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '未显式选择下载器时，系统按此顺序自动选择。保存后需重启容器使配置生效。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.sm),
          Text(
            '注意：PT 种子只能通过 qBittorrent 下载，不会走 115 离线下载。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.lg),
          AppSelectField<DownloadClientKind>(
            key: const Key('configuration-download-preference-client-field'),
            label: '首选下载器',
            value: selectedKind,
            items: [
              for (final kind in DownloadClientKind.values)
                DropdownMenuItem<DownloadClientKind>(
                  value: kind,
                  child: Text(kind.label),
                ),
            ],
            onChanged:
                state.isSaving
                    ? null
                    : (value) {
                      if (value == null || value == selectedKind) {
                        return;
                      }
                      ref
                          .read(downloadPreferenceProvider.notifier)
                          .updateDraft(<DownloadClientKind>[
                            value,
                            ...DownloadClientKind.values.where(
                              (kind) => kind != value,
                            ),
                          ]);
                    },
          ),
          SizedBox(height: spacing.sm),
          Text(
            '${state.draftKinds.last.label} 会作为候补下载器。',
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
              isLoading: state.isSaving,
              onPressed: state.isSaving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

String _saveMessage(List<String> restartRequired) {
  return restartRequired.isEmpty
      ? '已保存'
      : buildRestartRequiredMessage('已保存');
}
