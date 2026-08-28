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
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

class SystemMaintenanceSection extends ConsumerStatefulWidget {
  const SystemMaintenanceSection({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<SystemMaintenanceSection> createState() =>
      _SystemMaintenanceSectionState();
}

class _SystemMaintenanceSectionState
    extends ConsumerState<SystemMaintenanceSection> {
  StatusImageSearchDto? _imageSearchStatus;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant SystemMaintenanceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      unawaited(_load());
    }
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
    return AppPageRefreshScope(onRefresh: _load, child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final status = _imageSearchStatus;
    if (status == null) {
      if (_errorMessage != null) {
        return AppSectionError(
          title: '图搜索状态加载失败',
          message: _errorMessage!,
          onRetry: _load,
        );
      }
      return const AppSectionSkeleton(lineCount: 3);
    }

    final indexSpace = status.indexSpace;
    final requiresRebuild = indexSpace.requiresRebuild;
    final isRebuilding = indexSpace.isRebuilding;
    return AppContentCard(
      key: const Key('configuration-system-maintenance-image-search-card'),
      title: '图搜索索引',
      child: Row(
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
          AppButton(
            key: const Key(
              'configuration-system-maintenance-image-search-reset',
            ),
            label: isRebuilding
                ? '重建中'
                : requiresRebuild
                ? '立即重建'
                : '重建索引',
            variant: AppButtonVariant.primary,
            onPressed: isRebuilding ? null : _confirmImageSearchReset,
          ),
        ],
      ),
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
      dialogKey: const Key('configuration-image-search-reset-confirm-dialog'),
      confirmKey: const Key('configuration-image-search-reset-confirm'),
      cancelKey: const Key('configuration-image-search-reset-cancel'),
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
