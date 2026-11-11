import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_api_provider.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/status/presentation/status_placeholders.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/system_log_export_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';

/// The two platform shells use the same status request and reset flow, while
/// keeping their content spacing and action layout appropriate for the device.
enum SystemMaintenanceContentVariant { desktop, mobile }

class SystemMaintenanceContent extends ConsumerStatefulWidget {
  const SystemMaintenanceContent({
    super.key,
    required this.active,
    this.variant = SystemMaintenanceContentVariant.desktop,
  });

  final bool active;
  final SystemMaintenanceContentVariant variant;

  @override
  ConsumerState<SystemMaintenanceContent> createState() =>
      _SystemMaintenanceContentState();
}

class _SystemMaintenanceContentState
    extends ConsumerState<SystemMaintenanceContent> {
  static const _mediaInfoBackfillTaskKey = 'media_video_info_backfill';
  static const _fileHashBackfillTaskKey = 'media_file_hash_backfill';
  static const _thumbnailPackBackfillTaskKey = 'media_thumbnail_pack_backfill';
  static const _movieAssetPackBackfillTaskKey = 'movie_asset_pack_backfill';

  StatusImageSearchDto? _imageSearchStatus;
  String? _errorMessage;
  bool _isLoading = false;
  String? _submittingTaskKey;

  bool get _isMobile =>
      widget.variant == SystemMaintenanceContentVariant.mobile;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant SystemMaintenanceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_isLoading) {
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final status = await ref.read(statusApiProvider).getImageSearchStatus();
      if (!mounted) {
        return;
      }
      setState(() => _imageSearchStatus = status);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = apiErrorMessage(
          error,
          fallback: l10n.systemMaintenanceImageSearchLoadFailedFallback,
          l10n: l10n,
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox.shrink();
    }
    if (_isMobile) {
      return ColoredBox(
        key: const Key('mobile-settings-system-maintenance'),
        color: context.appColors.surfaceCard,
        child: AppAdaptiveRefreshScrollView(
          onRefresh: _load,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.only(
                top: context.appSpacing.md,
                bottom: context.appSpacing.lg,
              ),
              sliver: SliverToBoxAdapter(child: _buildContent(context)),
            ),
          ],
        ),
      );
    }
    return AppPageRefreshScope(onRefresh: _load, child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SystemLogExportCard(isMobile: _isMobile),
        SizedBox(height: context.appSpacing.xl),
        _buildImageSearchSection(context),
        SizedBox(height: context.appSpacing.xl),
        _buildMaintenanceTaskCard(
          context,
          taskKey: _mediaInfoBackfillTaskKey,
          title: l10n.systemMaintenanceMediaInfoBackfillTitle,
          description: l10n.systemMaintenanceMediaInfoBackfillDescription,
          successMessage: l10n.systemMaintenanceMediaInfoBackfillSuccess,
        ),
        SizedBox(height: context.appSpacing.xl),
        _buildMaintenanceTaskCard(
          context,
          taskKey: _fileHashBackfillTaskKey,
          title: l10n.systemMaintenanceFileHashBackfillTitle,
          description: l10n.systemMaintenanceFileHashBackfillDescription,
          successMessage: l10n.systemMaintenanceFileHashBackfillSuccess,
        ),
        SizedBox(height: context.appSpacing.xl),
        _buildMaintenanceTaskCard(
          context,
          taskKey: _thumbnailPackBackfillTaskKey,
          title: l10n.systemMaintenanceThumbnailPackTitle,
          description: l10n.systemMaintenanceThumbnailPackDescription,
          successMessage: l10n.systemMaintenanceThumbnailPackSuccess,
        ),
        SizedBox(height: context.appSpacing.xl),
        _buildMaintenanceTaskCard(
          context,
          taskKey: _movieAssetPackBackfillTaskKey,
          title: l10n.systemMaintenanceMovieAssetPackTitle,
          description: l10n.systemMaintenanceMovieAssetPackDescription,
          successMessage: l10n.systemMaintenanceMovieAssetPackSuccess,
        ),
      ],
    );
  }

  Widget _buildImageSearchSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _imageSearchStatus;
    if (status == null) {
      if (_errorMessage != null) {
        if (_isMobile) {
          return AppMobileSectionError(
            key: const Key('mobile-system-maintenance-error-state'),
            title: l10n.systemMaintenanceImageSearchLoadFailed,
            message: _errorMessage!,
            onRetry: _load,
            retryButtonKey: const Key('mobile-system-maintenance-retry-button'),
          );
        }
        return AppSectionError(
          title: l10n.systemMaintenanceImageSearchLoadFailed,
          message: _errorMessage!,
          onRetry: _load,
        );
      }
      // loading 用占位状态渲染真实卡片，由 [AppSkeletonizer] 灰化。
      final placeholder = imageSearchStatusPlaceholder();
      final placeholderIndexSpace = placeholder.indexSpace;
      return AppSkeletonizer(
        key: _isMobile
            ? const Key('mobile-system-maintenance-loading-state')
            : null,
        enabled: true,
        child: AppContentCard(
          title: l10n.systemMaintenanceImageSearchTitle,
          child: _isMobile
              ? _buildMobileCardBody(
                  context,
                  status: placeholder,
                  requiresRebuild: placeholderIndexSpace.requiresRebuild,
                  isRebuilding: placeholderIndexSpace.isRebuilding,
                )
              : _buildDesktopCardBody(
                  context,
                  status: placeholder,
                  requiresRebuild: placeholderIndexSpace.requiresRebuild,
                  isRebuilding: placeholderIndexSpace.isRebuilding,
                ),
        ),
      );
    }

    final indexSpace = status.indexSpace;
    final requiresRebuild = indexSpace.requiresRebuild;
    final isRebuilding = indexSpace.isRebuilding;
    return AppContentCard(
      key: Key(
        _isMobile
            ? 'mobile-system-maintenance-image-search-card'
            : 'configuration-system-maintenance-image-search-card',
      ),
      title: l10n.systemMaintenanceImageSearchTitle,
      child: _isMobile
          ? _buildMobileCardBody(
              context,
              status: status,
              requiresRebuild: requiresRebuild,
              isRebuilding: isRebuilding,
            )
          : _buildDesktopCardBody(
              context,
              status: status,
              requiresRebuild: requiresRebuild,
              isRebuilding: isRebuilding,
            ),
    );
  }

  Widget _buildMaintenanceTaskCard(
    BuildContext context, {
    required String taskKey,
    required String title,
    required String description,
    required String successMessage,
  }) {
    final l10n = AppLocalizations.of(context);
    final platformPrefix = _isMobile ? 'mobile' : 'configuration';
    final isSubmitting = _submittingTaskKey == taskKey;
    final hasSubmittingTask = _submittingTaskKey != null;
    final button = AppButton(
      key: Key('$platformPrefix-system-maintenance-$taskKey-run'),
      label: isSubmitting
          ? l10n.systemMaintenanceSubmit
          : l10n.systemMaintenanceRunNow,
      variant: AppButtonVariant.primary,
      size: _isMobile ? AppButtonSize.medium : AppButtonSize.small,
      isLoading: isSubmitting,
      onPressed: hasSubmittingTask
          ? null
          : () => unawaited(
              _runMaintenanceTask(
                taskKey: taskKey,
                successMessage: successMessage,
              ),
            ),
    );
    final descriptionText = Text(
      description,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        tone: AppTextTone.secondary,
      ),
    );

    return AppContentCard(
      key: Key('$platformPrefix-system-maintenance-$taskKey-card'),
      title: title,
      child: _isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                descriptionText,
                SizedBox(height: context.appSpacing.lg),
                button,
              ],
            )
          : Row(
              children: [
                Expanded(child: descriptionText),
                SizedBox(width: context.appSpacing.lg),
                button,
              ],
            ),
    );
  }

  Future<void> _runMaintenanceTask({
    required String taskKey,
    required String successMessage,
  }) async {
    if (_submittingTaskKey != null || !mounted) {
      return;
    }
    setState(() => _submittingTaskKey = taskKey);
    try {
      await ref.read(activityApiProvider).triggerJob(taskKey: taskKey);
      if (mounted) {
        showToast(successMessage, tone: AppToastTone.success);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is ApiException &&
          error.statusCode == 409 &&
          error.error?.code == 'task_conflict') {
        showToast(
          AppLocalizations.of(context).systemMaintenanceTaskRunning,
          tone: AppToastTone.info,
        );
      } else {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.systemMaintenanceSubmitFailed,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
      }
    } finally {
      if (mounted && _submittingTaskKey == taskKey) {
        setState(() => _submittingTaskKey = null);
      }
    }
  }

  Widget _buildDesktopCardBody(
    BuildContext context, {
    required StatusImageSearchDto status,
    required bool requiresRebuild,
    required bool isRebuilding,
  }) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            _buildImageSearchMessage(l10n, status),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              tone: requiresRebuild && !isRebuilding
                  ? AppTextTone.warning
                  : AppTextTone.secondary,
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.lg),
        _buildResetButton(
          key: const Key('configuration-system-maintenance-image-search-reset'),
          l10n: l10n,
          label: isRebuilding
              ? l10n.systemMaintenanceRebuilding
              : requiresRebuild
              ? l10n.systemMaintenanceRebuildNow
              : l10n.systemMaintenanceRebuildIndex,
          isRebuilding: isRebuilding,
          variant: AppButtonVariant.primary,
        ),
      ],
    );
  }

  Widget _buildMobileCardBody(
    BuildContext context, {
    required StatusImageSearchDto status,
    required bool requiresRebuild,
    required bool isRebuilding,
  }) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _buildImageSearchMessage(l10n, status),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            tone: requiresRebuild && !isRebuilding
                ? AppTextTone.warning
                : AppTextTone.secondary,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        if (requiresRebuild && !isRebuilding)
          Container(
            padding: EdgeInsets.all(context.appSpacing.md),
            decoration: BoxDecoration(
              color: colors.warningSurface,
              borderRadius: context.appRadius.mdBorder,
            ),
            child: Text(
              l10n.systemMaintenanceRebuildNotice,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.warning,
              ),
            ),
          ),
        if (requiresRebuild && !isRebuilding)
          SizedBox(height: context.appSpacing.md),
        SizedBox(
          width: double.infinity,
          child: _buildResetButton(
            key: const Key('mobile-system-maintenance-image-search-reset'),
            l10n: l10n,
            label: isRebuilding
                ? l10n.systemMaintenanceRebuilding
                : requiresRebuild
                ? l10n.systemMaintenanceRebuildNow
                : l10n.systemMaintenanceRebuildIndex,
            isRebuilding: isRebuilding,
            variant: AppButtonVariant.danger,
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton({
    required Key key,
    required AppLocalizations l10n,
    required String label,
    required bool isRebuilding,
    required AppButtonVariant variant,
  }) {
    return AppButton(
      key: key,
      label: _imageSearchStatus?.enabled == false
          ? l10n.systemMaintenanceDisabled
          : label,
      variant: variant,
      onPressed: isRebuilding || _imageSearchStatus?.enabled != true
          ? null
          : _confirmImageSearchReset,
    );
  }

  String _buildImageSearchMessage(
    AppLocalizations l10n,
    StatusImageSearchDto status,
  ) {
    if (!status.enabled) {
      return l10n.systemMaintenanceImageSearchDisabledMessage;
    }
    final indexSpace = status.indexSpace;
    if (indexSpace.isRebuilding) {
      return l10n.systemMaintenanceImageSearchRebuildingMessage;
    }
    if (indexSpace.requiresRebuild) {
      if (indexSpace.indexedSpaceId == null) {
        return l10n.systemMaintenanceImageSearchSpaceUnknownMessage;
      }
      return l10n.systemMaintenanceImageSearchSpaceChangedMessage(
        indexSpace.indexedSpaceId!,
        indexSpace.currentSpaceId ?? l10n.commonUnknown,
      );
    }
    return l10n.systemMaintenanceImageSearchRebuildHint;
  }

  Future<void> _confirmImageSearchReset() async {
    final status = _imageSearchStatus;
    if (status == null || !status.enabled || status.indexSpace.isRebuilding) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.systemMaintenanceRebuildDialogTitle,
      message: l10n.systemMaintenanceRebuildDialogMessage(
        _buildImageSearchMessage(l10n, status),
      ),
      confirmLabel: l10n.systemMaintenanceRebuildIndex,
      danger: true,
      dialogKey: Key(
        _isMobile
            ? 'mobile-system-maintenance-image-search-reset-confirm-dialog'
            : 'configuration-image-search-reset-confirm-dialog',
      ),
      confirmKey: Key(
        _isMobile
            ? 'mobile-system-maintenance-image-search-reset-confirm'
            : 'configuration-image-search-reset-confirm',
      ),
      cancelKey: Key(
        _isMobile
            ? 'mobile-system-maintenance-image-search-reset-cancel'
            : 'configuration-image-search-reset-cancel',
      ),
      onConfirm: () => ref.read(statusApiProvider).resetImageSearch(),
      failureFallback: l10n.systemMaintenanceRebuildFailed,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _load();
    if (mounted) {
      showToast(l10n.systemMaintenanceRebuildStarted, tone: AppToastTone.info);
    }
  }
}
