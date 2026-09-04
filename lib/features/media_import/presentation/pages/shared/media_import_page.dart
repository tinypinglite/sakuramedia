import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media_import/presentation/directory_picker_dialog.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/media_import_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/imports/video_import_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

/// 媒体导入入口。提交后任务进度和结果统一在任务中心通过 `/system/task-runs`
/// 轮询展示；本页只负责创建导入任务。
class MediaImportPage extends ConsumerStatefulWidget {
  const MediaImportPage({super.key});

  @override
  ConsumerState<MediaImportPage> createState() => _MediaImportPageState();
}

enum _ImportTab { javMovie, video }

class _MediaImportPageState extends ConsumerState<MediaImportPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isCreating = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _ImportTab.values.length,
      vsync: this,
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  _ImportTab get _activeTab => _ImportTab.values[_tabController.index];

  Future<void> _createImport() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    try {
      switch (_activeTab) {
        case _ImportTab.javMovie:
          final request = await showDirectoryPickerDialog(context);
          if (request == null || !mounted) return;
          setState(() => _isSubmitting = true);
          final accepted = await ref
              .read(mediaImportApiProvider)
              .createImport(
                mediaKind: 'jav',
                libraryId: request.libraryId,
                source: request.source,
                sourceDisposition: request.sourceDisposition,
              );
          if (mounted) {
            showToast('导入任务 #${accepted.taskRunId} 已提交，请在任务中心查看进度');
          }
        case _ImportTab.video:
          final request = await showVideoImportDialog(context);
          if (request == null || !mounted) return;
          setState(() => _isSubmitting = true);
          final accepted = await ref
              .read(mediaImportApiProvider)
              .createImport(
                mediaKind: 'video',
                libraryId: request.libraryId,
                source: request.source,
                sourceDisposition: request.sourceDisposition,
                collectionId: request.collectionId,
              );
          if (mounted) {
            showToast('视频导入任务 #${accepted.taskRunId} 已提交，请在任务中心查看进度');
          }
      }
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '提交导入任务失败，请稍后重试。'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _isSubmitting = false;
        });
      }
    }
  }

  String get _title => switch (_activeTab) {
    _ImportTab.javMovie => 'JAV 影片导入',
    _ImportTab.video => '视频导入',
  };

  String get _description => switch (_activeTab) {
    _ImportTab.javMovie => '浏览存储中的目录，批量导入 JAV 影片。',
    _ImportTab.video => '选择存储中的目录或视频文件，可同时加入合集。',
  };

  Widget _buildCreateButton() => AppButton(
    key: const Key('media-import-create-button'),
    label: '新建导入',
    variant: AppButtonVariant.primary,
    isLoading: _isSubmitting,
    icon: const Icon(Icons.drive_folder_upload_outlined),
    onPressed: _isCreating ? null : () => unawaited(_createImport()),
  );

  @override
  Widget build(BuildContext context) {
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final description = Text(
      '$_description 导入进度和结果请前往任务中心查看。',
      style: resolveAppTextStyle(
        context,
        size: isMobile ? AppTextSize.s14 : AppTextSize.s12,
        tone: AppTextTone.secondary,
      ),
    );
    final content = CustomScrollView(
      key: const Key('media-import-page'),
      slivers: [
        SliverToBoxAdapter(
          child: AppTabBar(
            controller: _tabController,
            tabs: const [
              Tab(key: Key('media-import-tab-jav'), text: 'JAV 影片'),
              Tab(key: Key('media-import-tab-video'), text: '视频'),
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
        SliverToBoxAdapter(
          child: AppContentCard(
            title: _title,
            titleStyle: resolveAppTextStyle(
              context,
              size: isMobile ? AppTextSize.s16 : AppTextSize.s14,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
            child: isMobile
                ? description
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: description),
                      SizedBox(width: context.appSpacing.lg),
                      _buildCreateButton(),
                    ],
                  ),
          ),
        ),
        if (isMobile)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: context.appSpacing.md),
              child: AppButton(
                key: const Key('media-import-task-center-button'),
                label: '查看导入任务',
                icon: const Icon(Icons.task_alt_outlined),
                trailingIcon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => context.push(mobileActivityPath),
              ),
            ),
          ),
      ],
    );
    if (!isMobile) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: content),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(top: context.appSpacing.lg),
            child: _buildCreateButton(),
          ),
        ),
      ],
    );
  }
}
