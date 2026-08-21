import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media_import/presentation/directory_picker_dialog.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/media_import_api_provider.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/subtitle_import_api_provider.dart';
import 'package:sakuramedia/features/media_import/presentation/subtitle_import_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/imports/video_import_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

/// 媒体导入入口。提交后任务进度和结果统一在活动中心通过 `/system/task-runs`
/// 轮询展示；本页只负责创建导入任务。
class DesktopMediaImportPage extends ConsumerStatefulWidget {
  const DesktopMediaImportPage({super.key});

  @override
  ConsumerState<DesktopMediaImportPage> createState() =>
      _DesktopMediaImportPageState();
}

enum _ImportTab { javMovie, pornBoxMovie, javSubtitle }

class _DesktopMediaImportPageState extends ConsumerState<DesktopMediaImportPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _ImportTab.values.length, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  _ImportTab get _activeTab => _ImportTab.values[_tabController.index];

  Future<void> _createImport() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      switch (_activeTab) {
        case _ImportTab.javMovie:
          final request = await showDirectoryPickerDialog(context);
          if (request == null || !mounted) return;
          final accepted = await ref.read(mediaImportApiProvider).createImport(
            mediaKind: 'jav',
            libraryId: request.libraryId,
            source: request.source,
            transferMode: request.transferMode,
          );
          if (mounted) {
            showToast('导入任务 #${accepted.taskRunId} 已提交，请在活动中心查看进度');
          }
        case _ImportTab.pornBoxMovie:
          final request = await showVideoImportDialog(context);
          if (request == null || !mounted) return;
          final accepted = await ref.read(mediaImportApiProvider).createImport(
            mediaKind: 'video',
            libraryId: request.libraryId,
            source: request.source,
            transferMode: request.transferMode,
            collectionId: request.collectionId,
          );
          if (mounted) {
            showToast('视频导入任务 #${accepted.taskRunId} 已提交，请在活动中心查看进度');
          }
        case _ImportTab.javSubtitle:
          final sourcePath = await showSubtitleImportDialog(context);
          if (sourcePath == null || !mounted) return;
          final accepted = await ref
              .read(subtitleImportApiProvider)
              .createSubtitleImport(sourcePath: sourcePath);
          if (mounted) {
            showToast('字幕导入任务 #${accepted.taskRunId} 已提交，请在活动中心查看进度');
          }
      }
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '提交导入任务失败，请稍后重试。'));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String get _title => switch (_activeTab) {
    _ImportTab.javMovie => 'JAV 影片导入',
    _ImportTab.pornBoxMovie => 'PornBox 影片导入',
    _ImportTab.javSubtitle => 'JAV 字幕导入',
  };

  String get _description => switch (_activeTab) {
    _ImportTab.javMovie => '从后端本地目录或 115 网盘目录选择 JAV 媒体导入到媒体库。',
    _ImportTab.pornBoxMovie => '从后端目录选择 PornBox 视频并归入一个合集。',
    _ImportTab.javSubtitle => '递归扫描 .srt 文件并按番号匹配已入库的 JAV 影片，源文件会保留。',
  };

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const Key('media-import-page'),
      slivers: [
        SliverToBoxAdapter(
          child: AppTabBar(
            controller: _tabController,
            tabs: const [
              Tab(key: Key('media-import-tab-jav'), text: 'JAV 影片'),
              Tab(key: Key('media-import-tab-pornbox'), text: 'PornBox 影片'),
              Tab(key: Key('media-import-tab-jav-subtitle'), text: 'JAV 字幕'),
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
        SliverToBoxAdapter(
          child: AppContentCard(
            title: _title,
            titleStyle: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '$_description 导入进度和结果请前往活动中心查看。',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ),
                SizedBox(width: context.appSpacing.lg),
                AppButton(
                  key: const Key('media-import-create-button'),
                  label: _activeTab == _ImportTab.javSubtitle ? '新建字幕导入' : '新建导入',
                  variant: AppButtonVariant.primary,
                  icon: const Icon(Icons.drive_folder_upload_outlined),
                  onPressed: _isSubmitting ? null : () => unawaited(_createImport()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
