import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media_import/presentation/directory_picker_dialog.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/media_import_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/imports.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
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
            showToast(
              l10n.mediaImportTaskSubmitted(accepted.taskRunId),
              tone: AppToastTone.success,
            );
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
            showToast(
              l10n.mediaImportVideoTaskSubmitted(accepted.taskRunId),
              tone: AppToastTone.success,
            );
          }
      }
    } catch (error) {
      if (mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.mediaImportSubmitFailed,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
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

  String _title(AppLocalizations l10n) => switch (_activeTab) {
    _ImportTab.javMovie => l10n.mediaImportTitleJav,
    _ImportTab.video => l10n.mediaImportTitleVideo,
  };

  String _description(AppLocalizations l10n) => switch (_activeTab) {
    _ImportTab.javMovie => l10n.mediaImportDescriptionJav,
    _ImportTab.video => l10n.mediaImportDescriptionVideo,
  };

  Widget _buildCreateButton(AppLocalizations l10n) => AppButton(
    key: const Key('media-import-create-button'),
    label: l10n.mediaImportCreateAction,
    variant: AppButtonVariant.primary,
    isLoading: _isSubmitting,
    icon: const Icon(Icons.drive_folder_upload_outlined),
    onPressed: _isCreating ? null : () => unawaited(_createImport()),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final description = Text(
      '${_description(l10n)} ${l10n.mediaImportDescriptionSuffix}',
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
            tabs: [
              Tab(
                key: const Key('media-import-tab-jav'),
                text: l10n.mediaImportTabJav,
              ),
              Tab(
                key: const Key('media-import-tab-video'),
                text: l10n.mediaImportTabVideo,
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
        SliverToBoxAdapter(
          child: AppContentCard(
            title: _title(l10n),
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
                      _buildCreateButton(l10n),
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
                label: l10n.mediaImportViewTasksAction,
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
            child: _buildCreateButton(l10n),
          ),
        ),
      ],
    );
  }
}
