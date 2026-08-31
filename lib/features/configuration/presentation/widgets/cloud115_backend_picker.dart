import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 「媒体库存储类型」选择器：本地目录 / 115 网盘。
///
/// 平台自适应：mobile 走底部抽屉，桌面端走对话框。
/// 用户选中一项后 pop 返回对应 [MediaLibraryBackend]，取消返回 `null`。
/// 由「新建媒体库」入口调用，115 分支再链到 `showCloud115LibraryLoginFlow`。
Future<MediaLibraryBackend?> showMediaLibraryBackendPicker(
  BuildContext context,
) {
  Widget buildBody(BuildContext modalContext) {
    final spacing = modalContext.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '选择存储类型',
          style: resolveAppTextStyle(
            modalContext,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          '媒体库创建后不能切换存储类型。',
          style: resolveAppTextStyle(
            modalContext,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        AppSettingsGroup(
          children: [
            AppSettingCell(
              key: const Key('media-library-backend-local'),
              icon: Icons.folder_open_outlined,
              title: '本地存储',
              subtitle: '使用后端服务器可访问的本地目录',
              trailing: const AppSettingCellChevron(),
              onTap:
                  () =>
                      Navigator.of(modalContext).pop(MediaLibraryBackend.local),
            ),
            AppSettingCell(
              key: const Key('media-library-backend-cloud115'),
              icon: Icons.cloud_outlined,
              title: '115 网盘',
              subtitle: '扫码登录并使用 115 网盘存储媒体',
              trailing: const AppSettingCellChevron(),
              onTap:
                  () => Navigator.of(
                    modalContext,
                  ).pop(MediaLibraryBackend.cloud115),
            ),
          ],
        ),
      ],
    );
  }

  return showAppAdaptiveModal<MediaLibraryBackend>(
    context: context,
    modalKey: const Key('media-library-backend-picker-drawer'),
    mobileMaxHeightFactor: 0.48,
    builder: buildBody,
  );
}
