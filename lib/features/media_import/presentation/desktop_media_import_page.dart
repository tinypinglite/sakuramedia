import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/activity/data/activity_api.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';
import 'package:sakuramedia/features/media_import/presentation/directory_picker_dialog.dart';
import 'package:sakuramedia/features/media_import/presentation/import_job_card.dart';
import 'package:sakuramedia/features/media_import/presentation/import_jobs_view_controller.dart';
import 'package:sakuramedia/features/media_import/presentation/media_import_controller.dart';
import 'package:sakuramedia/features/videos/data/video_imports_api.dart';
import 'package:sakuramedia/features/videos/presentation/video_import_controller.dart';
import 'package:sakuramedia/features/videos/presentation/video_import_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_content_card.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/app_shell/app_page_frame.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';

class DesktopMediaImportPage extends StatefulWidget {
  const DesktopMediaImportPage({super.key});

  @override
  State<DesktopMediaImportPage> createState() => _DesktopMediaImportPageState();
}

class _DesktopMediaImportPageState extends State<DesktopMediaImportPage>
    with SingleTickerProviderStateMixin {
  late final MediaImportController _javController;
  late final VideoImportController _pornController;
  late final TabController _tabController;
  late final Listenable _mergedListenable;

  final ScrollController _scrollController = ScrollController();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final Set<int> _expandedJav = <int>{};
  final Set<int> _expandedPorn = <int>{};

  @override
  void initState() {
    super.initState();
    _javController = MediaImportController(
      mediaImportApi: context.read<MediaImportApi>(),
      activityApi: context.read<ActivityApi>(),
    );
    _pornController = VideoImportController(
      videoImportsApi: context.read<VideoImportsApi>(),
      activityApi: context.read<ActivityApi>(),
    );
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _mergedListenable = Listenable.merge(
      <Listenable>[_javController, _pornController, _tabController],
    );
    _scrollController.addListener(_handleScroll);
    unawaited(_javController.initialize());
    unawaited(_pornController.initialize());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _javController.dispose();
    _pornController.dispose();
    super.dispose();
  }

  bool get _isPornTab => _tabController.index == 1;
  ImportJobsViewController get _activeController =>
      _isPornTab ? _pornController : _javController;

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    // 切标签时回到顶部，避免新标签内容沿用上一个标签的滚动位置。
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {});
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      unawaited(_activeController.loadMore());
    }
  }

  Future<void> _openJavCreateDialog() async {
    final request = await showDirectoryPickerDialog(context);
    if (request == null || !mounted) {
      return;
    }
    final error = await _javController.triggerImport(
      libraryId: request.libraryId,
      sourcePath: request.sourcePath,
      transferMode: request.transferMode,
    );
    if (!mounted) {
      return;
    }
    showToast(error ?? '导入任务已提交，可在下方查看进度');
  }

  Future<void> _openPornCreateDialog() async {
    final request = await showVideoImportDialog(context);
    if (request == null || !mounted) {
      return;
    }
    final error = await _pornController.triggerImport(
      libraryId: request.libraryId,
      sourcePath: request.sourcePath,
      transferMode: request.transferMode,
      collectionId: request.collectionId,
    );
    if (!mounted) {
      return;
    }
    showToast(error ?? '导入任务已提交，可在下方查看进度');
  }

  void _toggleExpanded(ImportJobsViewController controller, int jobId) {
    final expanded = controller == _pornController ? _expandedPorn : _expandedJav;
    setState(() {
      if (expanded.contains(jobId)) {
        expanded.remove(jobId);
      } else {
        expanded.add(jobId);
        unawaited(controller.ensureDetail(jobId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mergedListenable,
      builder: (context, _) {
        return AppPageFrame(
          title: '',
          scrollController: _scrollController,
          child: Column(
            key: const Key('media-import-page'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTabBar(
                controller: _tabController,
                tabs: const [
                  Tab(key: Key('media-import-tab-jav'), text: 'JAV 影片'),
                  Tab(key: Key('media-import-tab-pornbox'), text: 'PornBox 影片'),
                ],
              ),
              SizedBox(height: context.appSpacing.lg),
              if (_isPornTab)
                _buildTab(
                  context,
                  controller: _pornController,
                  expanded: _expandedPorn,
                  description:
                      '从后端白名单目录中选择 PornBox 视频导入到媒体库，必须归入一个合集。导入在后台运行，可在此查看实时进度与失败文件处理。',
                  onCreate: () => unawaited(_openPornCreateDialog()),
                )
              else
                _buildTab(
                  context,
                  controller: _javController,
                  expanded: _expandedJav,
                  description:
                      '从后端白名单目录中选择 JAV 媒体导入到媒体库。导入在后台运行，可在此查看实时进度与失败文件处理。',
                  onCreate: () => unawaited(_openJavCreateDialog()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required ImportJobsViewController controller,
    required Set<int> expanded,
    required String description,
    required VoidCallback onCreate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          description: description,
          isLoading: controller.isInitialLoading,
          onCreate: onCreate,
          onRefresh: () => unawaited(controller.refresh()),
        ),
        SizedBox(height: context.appSpacing.lg),
        if (!controller.isInitialLoading &&
            controller.initialError == null &&
            controller.jobs.isNotEmpty) ...[
          const _HistorySectionTitle(),
          SizedBox(height: context.appSpacing.md),
        ],
        _buildBody(context, controller, expanded),
        if (controller.jobs.isNotEmpty &&
            (controller.isLoadingMore || controller.loadMoreError != null)) ...[
          SizedBox(height: context.appSpacing.lg),
          AppPagedLoadMoreFooter(
            isLoading: controller.isLoadingMore,
            errorMessage: controller.loadMoreError,
            onRetry: () => unawaited(controller.loadMore()),
          ),
        ],
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    ImportJobsViewController controller,
    Set<int> expanded,
  ) {
    if (controller.isInitialLoading) {
      return AppContentCard(
        title: '正在加载',
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.appLayoutTokens.emptySectionVerticalPadding,
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: context.appComponentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }

    if (controller.initialError != null) {
      return AppContentCard(
        title: '加载失败',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppEmptyState(message: controller.initialError!),
            SizedBox(height: context.appSpacing.lg),
            Center(
              child: AppButton(
                key: const Key('media-import-initial-retry-button'),
                label: '重试',
                variant: AppButtonVariant.primary,
                onPressed: () => unawaited(controller.loadFirstPage()),
              ),
            ),
          ],
        ),
      );
    }

    if (controller.jobs.isEmpty) {
      return const AppEmptyState(message: '还没有导入作业。点击「新建导入」从后端目录选择媒体导入。');
    }

    return Column(
      children: controller.jobs
          .map(
            (job) => Padding(
              padding: EdgeInsets.only(bottom: context.appSpacing.md),
              child: ImportJobCard(
                job: job,
                taskRun: controller.taskRunFor(job.taskRunId),
                expanded: expanded.contains(job.id),
                detail: controller.detailFor(job.id),
                isDetailLoading: controller.isDetailLoading(job.id),
                detailError: controller.detailError(job.id),
                dateFormat: _dateFormat,
                onToggle: () => _toggleExpanded(controller, job.id),
                onRetryAll: () => _retryAll(controller, job.id),
                onRetryFile: (path) =>
                    _retryFiles(controller, job.id, <String>[path]),
                onDeleteFile: (path) => _deleteFile(controller, job.id, path),
                onRenameFile: (path, name) =>
                    _renameFile(controller, job.id, path, name),
                onReloadDetail: () =>
                    unawaited(controller.ensureDetail(job.id, force: true)),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _retryAll(ImportJobsViewController controller, int jobId) async {
    final error = await controller.retryFailedFiles(jobId);
    if (!mounted) {
      return;
    }
    showToast(error ?? '已提交重导任务');
  }

  Future<void> _retryFiles(
    ImportJobsViewController controller,
    int jobId,
    List<String> files,
  ) async {
    final error = await controller.retryFailedFiles(jobId, files: files);
    if (!mounted) {
      return;
    }
    showToast(error ?? '已提交重导任务');
  }

  Future<void> _deleteFile(
    ImportJobsViewController controller,
    int jobId,
    String path,
  ) async {
    final confirmed = await _confirmDelete(path);
    if (!mounted || confirmed != true) {
      return;
    }
    final error = await controller.deleteFailedFile(jobId, path: path);
    if (!mounted) {
      return;
    }
    showToast(error ?? '源文件已删除');
  }

  Future<void> _renameFile(
    ImportJobsViewController controller,
    int jobId,
    String path,
    String currentName,
  ) async {
    final newName = await _promptRename(currentName);
    if (!mounted || newName == null || newName.trim().isEmpty) {
      return;
    }
    final error = await controller.renameFailedFile(
      jobId,
      path: path,
      newName: newName.trim(),
    );
    if (!mounted) {
      return;
    }
    showToast(error ?? '已重命名');
  }

  Future<bool?> _confirmDelete(String path) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDesktopDialog(
        dialogKey: const Key('media-import-delete-confirm-dialog'),
        width: dialogContext.appLayoutTokens.dialogWidthSm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '删除源文件',
              style: resolveAppTextStyle(dialogContext, size: AppTextSize.s18),
            ),
            SizedBox(height: dialogContext.appSpacing.lg),
            Text('确认删除该失败源文件？该操作不可恢复。\n\n$path'),
            SizedBox(height: dialogContext.appSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                SizedBox(width: dialogContext.appSpacing.md),
                Expanded(
                  child: AppButton(
                    label: '删除',
                    variant: AppButtonVariant.danger,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptRename(String currentName) {
    final textController = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AppDesktopDialog(
        dialogKey: const Key('media-import-rename-dialog'),
        width: dialogContext.appLayoutTokens.dialogWidthSm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '重命名源文件',
              style: resolveAppTextStyle(dialogContext, size: AppTextSize.s18),
            ),
            SizedBox(height: dialogContext.appSpacing.lg),
            AppTextField(
              fieldKey: const Key('media-import-rename-field'),
              controller: textController,
              label: '新文件名',
              hintText: '例如 ABP-123.mp4',
            ),
            SizedBox(height: dialogContext.appSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                SizedBox(width: dialogContext.appSpacing.md),
                Expanded(
                  child: AppButton(
                    label: '确认',
                    variant: AppButtonVariant.primary,
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(textController.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(textController.dispose);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.description,
    required this.isLoading,
    required this.onCreate,
    required this.onRefresh,
  });

  final String description;
  final bool isLoading;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      title: '媒体导入',
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
              description,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
          ),
          SizedBox(width: context.appSpacing.lg),
          AppButton(
            key: const Key('media-import-refresh-button'),
            label: '刷新',
            onPressed: onRefresh,
          ),
          SizedBox(width: context.appSpacing.sm),
          AppButton(
            key: const Key('media-import-create-button'),
            label: '新建导入',
            variant: AppButtonVariant.primary,
            icon: const Icon(Icons.drive_folder_upload_outlined),
            onPressed: isLoading ? null : onCreate,
          ),
        ],
      ),
    );
  }
}

class _HistorySectionTitle extends StatelessWidget {
  const _HistorySectionTitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.appSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '导入任务历史',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          Text(
            '按创建时间倒序展示历史导入任务的状态与处理结果。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ),
    );
  }
}
