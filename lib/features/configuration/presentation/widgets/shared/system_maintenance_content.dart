import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
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
  StatusImageSearchDto? _imageSearchStatus;
  String? _errorMessage;
  bool _isLoading = false;

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
      setState(() {
        _errorMessage = apiErrorMessage(error, fallback: '图搜索状态加载失败，请稍后重试。');
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
        color: context.appColors.surfacePage,
        child: AppAdaptiveRefreshScrollView(
          onRefresh: _load,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                context.appSpacing.md,
                context.appSpacing.md,
                context.appSpacing.md,
                context.appSpacing.lg,
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
    final status = _imageSearchStatus;
    if (status == null) {
      if (_errorMessage != null) {
        if (_isMobile) {
          return AppMobileSectionError(
            key: const Key('mobile-system-maintenance-error-state'),
            title: '图搜索状态加载失败',
            message: _errorMessage!,
            onRetry: _load,
            retryButtonKey: const Key('mobile-system-maintenance-retry-button'),
          );
        }
        return AppSectionError(
          title: '图搜索状态加载失败',
          message: _errorMessage!,
          onRetry: _load,
        );
      }
      return _isMobile
          ? const AppMobileSkeletonCard(
              key: Key('mobile-system-maintenance-loading-state'),
            )
          : const AppSectionSkeleton(lineCount: 3);
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
      title: '图搜索索引',
      padding: _isMobile ? EdgeInsets.all(context.appSpacing.lg) : null,
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

  Widget _buildDesktopCardBody(
    BuildContext context, {
    required StatusImageSearchDto status,
    required bool requiresRebuild,
    required bool isRebuilding,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _buildImageSearchMessage(status),
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
          label: isRebuilding
              ? '重建中'
              : requiresRebuild
              ? '立即重建'
              : '重建索引',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _buildImageSearchMessage(status),
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
              '重建会清空现有图片索引，期间图搜索结果可能暂时不完整。',
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
            label: isRebuilding
                ? '重建中'
                : requiresRebuild
                ? '立即重建'
                : '重建索引',
            isRebuilding: isRebuilding,
            variant: AppButtonVariant.danger,
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton({
    required Key key,
    required String label,
    required bool isRebuilding,
    required AppButtonVariant variant,
  }) {
    return AppButton(
      key: key,
      label: label,
      variant: variant,
      onPressed: isRebuilding ? null : _confirmImageSearchReset,
    );
  }

  String _buildImageSearchMessage(StatusImageSearchDto status) {
    final indexSpace = status.indexSpace;
    if (indexSpace.isRebuilding) {
      return '图搜索索引正在后台重建，请稍候。';
    }
    if (indexSpace.requiresRebuild) {
      if (indexSpace.indexedSpaceId == null) {
        return '无法确认历史图搜索索引使用的嵌入空间，图搜索已暂停。请重建索引后再搜索。';
      }
      return '嵌入空间已从「${indexSpace.indexedSpaceId}」变更为「${indexSpace.currentSpaceId ?? '未知'}」，图搜索已暂停。请重建索引后再搜索。';
    }
    return '更换嵌入模型后，重建索引以重新生成全部图片向量。重建期间图搜索结果可能暂时不完整。';
  }

  Future<void> _confirmImageSearchReset() async {
    final status = _imageSearchStatus;
    if (status == null || status.indexSpace.isRebuilding) {
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: '重建图搜索索引',
      message:
          '${_buildImageSearchMessage(status)}\n\n这会清空现有图片索引并重新开始构建，确认继续吗？',
      confirmLabel: '重建索引',
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
      failureFallback: '重建图搜索索引失败',
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _load();
    if (mounted) {
      showToast('图搜索索引已开始重建');
    }
  }
}
