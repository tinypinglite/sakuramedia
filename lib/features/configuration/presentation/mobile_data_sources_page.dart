import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_shell/app_badge.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

class MobileDataSourcesPage extends StatefulWidget {
  const MobileDataSourcesPage({super.key});

  @override
  State<MobileDataSourcesPage> createState() => _MobileDataSourcesPageState();
}

class _MobileDataSourcesPageState extends State<MobileDataSourcesPage> {
  late final TextEditingController _activationCodeController;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isActivating = false;
  bool _isSyncingAuthorization = false;
  bool _isTestingConnectivity = false;
  bool _obscureActivationCode = true;
  String? _errorMessage;
  MetadataProviderLicenseStatusDto? _status;
  MetadataProviderLicenseConnectivityTestDto? _connectivityTest;

  MetadataProviderLicenseApi get _api =>
      context.read<MetadataProviderLicenseApi>();

  bool get _hasBusyAction =>
      _isLoading ||
      _isRefreshing ||
      _isActivating ||
      _isSyncingAuthorization ||
      _isTestingConnectivity;

  @override
  void initState() {
    super.initState();
    _activationCodeController = TextEditingController();
    unawaited(_loadStatus());
  }

  @override
  void dispose() {
    _activationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return ColoredBox(
      key: const Key('mobile-settings-data-sources'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: _refreshStatus,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.md,
                    spacing.md,
                    spacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(child: _buildBody(context)),
                ),
              ],
            ),
          ),
          if (_errorMessage == null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                spacing.md,
                spacing.md,
                spacing.md,
                spacing.md,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                border: Border(top: BorderSide(color: colors.divider)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: AppButton(
                  key: const Key('mobile-data-sources-activate-button'),
                  label: _isActivating ? '激活中' : '激活授权',
                  variant: AppButtonVariant.primary,
                  isLoading: _isActivating,
                  icon:
                      _isActivating
                          ? null
                          : const Icon(Icons.verified_outlined),
                  onPressed: _hasBusyAction ? null : _activate,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const _MobileDataSourcesLoadingSection();
    }

    if (_errorMessage != null) {
      return _MobileDataSourcesErrorSection(
        message: _errorMessage!,
        onRetry: _loadStatus,
      );
    }

    final spacing = context.appSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileDataSourcesOverviewCard(
          status: _status,
          statusLabel: _licenseStatusLabel(_status),
          statusDescription: _licenseStatusDescription(_status),
          connectivityLabel: _connectivityStatusLabel(),
        ),
        SizedBox(height: spacing.md),
        _buildActivationCard(context),
        SizedBox(height: spacing.md),
        _buildDiagnosticsCard(context),
      ],
    );
  }

  Widget _buildActivationCard(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      key: const Key('mobile-data-sources-activation-card'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '激活授权',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            '激活码仅用于本次请求，前端不会保存，后端也不会写入配置文件。请妥善保管激活码，避免泄露给他人。同一个激活码同一时间仅能激活一个实例；若后续用于激活其他实例，当前实例将会失效。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('mobile-data-sources-activation-field'),
            controller: _activationCodeController,
            label: '激活码',
            hintText: 'SMB-XXXX-XXXX-XXXX',
            obscureText: _obscureActivationCode,
            enabled: !_hasBusyAction,
            suffix: AppIconButton(
              key: const Key(
                'mobile-data-sources-activation-visibility-button',
              ),
              tooltip: _obscureActivationCode ? '显示激活码' : '隐藏激活码',
              semanticLabel: _obscureActivationCode ? '显示激活码' : '隐藏激活码',
              size: AppIconButtonSize.compact,
              icon: Icon(
                _obscureActivationCode
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed:
                  _hasBusyAction
                      ? null
                      : () => setState(() {
                        _obscureActivationCode = !_obscureActivationCode;
                      }),
            ),
          ),
          SizedBox(height: spacing.md),
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: [
              AppButton(
                key: const Key('mobile-data-sources-refresh-button'),
                label: _isRefreshing ? '刷新中' : '刷新状态',
                size: AppButtonSize.small,
                isLoading: _isRefreshing,
                icon: _isRefreshing ? null : const Icon(Icons.refresh_rounded),
                onPressed: _hasBusyAction ? null : _refreshStatus,
              ),
              AppButton(
                key: const Key('mobile-data-sources-connectivity-button'),
                label: _isTestingConnectivity ? '检测中' : '测试连接',
                size: AppButtonSize.small,
                isLoading: _isTestingConnectivity,
                icon:
                    _isTestingConnectivity
                        ? null
                        : const Icon(Icons.cloud_sync_outlined),
                onPressed: _hasBusyAction ? null : _testConnectivity,
              ),
              AppButton(
                key: const Key('mobile-data-sources-sync-button'),
                label: _isSyncingAuthorization ? '同步中' : '同步授权',
                size: AppButtonSize.small,
                isLoading: _isSyncingAuthorization,
                icon:
                    _isSyncingAuthorization
                        ? null
                        : const Icon(Icons.sync_rounded),
                onPressed: _hasBusyAction ? null : _syncAuthorization,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsCard(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final status = _status;
    final connectivity = _connectivityTest;

    return Container(
      key: const Key('mobile-data-sources-diagnostics-card'),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('mobile-data-sources-diagnostics'),
          tilePadding: EdgeInsets.symmetric(horizontal: spacing.md),
          childrenPadding: EdgeInsets.fromLTRB(
            spacing.md,
            0,
            spacing.md,
            spacing.md,
          ),
          title: Text(
            '诊断信息',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.secondary,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: [
                  _MobileDataSourcesInfoPill(
                    label: '实例 ID',
                    value: status?.instanceId ?? '未提供',
                  ),
                  _MobileDataSourcesInfoPill(
                    label: '错误码',
                    value: _diagnosticValue(status?.errorCode),
                  ),
                  _MobileDataSourcesInfoPill(
                    label: '后端说明',
                    value: _diagnosticValue(status?.message),
                  ),
                  _MobileDataSourcesInfoPill(
                    label: '授权中心 URL',
                    value: _diagnosticValue(connectivity?.url),
                  ),
                  _MobileDataSourcesInfoPill(
                    label: '代理',
                    value:
                        connectivity == null
                            ? '未检测'
                            : (connectivity.proxyEnabled ? '已启用' : '未启用'),
                  ),
                  _MobileDataSourcesInfoPill(
                    label: '耗时',
                    value:
                        connectivity == null
                            ? '未检测'
                            : '${connectivity.elapsedMs} ms',
                  ),
                  _MobileDataSourcesInfoPill(
                    label: 'HTTP 状态',
                    value: connectivity?.statusCode?.toString() ?? '未提供',
                  ),
                  _MobileDataSourcesInfoPill(
                    label: '连接错误',
                    value: _diagnosticValue(connectivity?.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await _api.getStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '授权状态加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _refreshStatus() async {
    if (_hasBusyAction && !_isLoading) {
      return;
    }
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final status = await _api.getStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRefreshing = false;
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '授权状态加载失败，请稍后重试。');
      });
    }
  }

  Future<void> _testConnectivity() async {
    if (_hasBusyAction) {
      return;
    }

    setState(() {
      _isTestingConnectivity = true;
    });

    try {
      final result = await _api.testConnectivity();
      if (!mounted) {
        return;
      }
      setState(() {
        _connectivityTest = result;
        _isTestingConnectivity = false;
      });
      showToast(result.ok ? '授权中心连接正常' : '授权中心连接异常');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectivityTest = null;
        _isTestingConnectivity = false;
      });
      showToast(apiErrorMessage(error, fallback: '授权中心连接测试失败'));
    }
  }

  Future<void> _syncAuthorization() async {
    if (_hasBusyAction) {
      return;
    }

    setState(() {
      _isSyncingAuthorization = true;
    });

    try {
      final status = await _api.syncAuthorization();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _errorMessage = null;
        _isSyncingAuthorization = false;
      });
      showToast('授权状态已同步');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSyncingAuthorization = false;
      });
      showToast(apiErrorMessage(error, fallback: '同步授权失败'));
    }
  }

  Future<void> _activate() async {
    if (_hasBusyAction) {
      return;
    }
    final activationCode = _activationCodeController.text.trim();
    if (activationCode.isEmpty) {
      showToast('请输入激活码');
      return;
    }

    setState(() {
      _isActivating = true;
    });

    try {
      final status = await _api.activate(activationCode: activationCode);
      if (!mounted) {
        return;
      }
      _activationCodeController.clear();
      setState(() {
        _status = status;
        _errorMessage = null;
        _isActivating = false;
      });
      showToast('授权已激活');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _activationCodeController.clear();
      setState(() {
        _isActivating = false;
      });
      showToast(apiErrorMessage(error, fallback: '激活授权失败'));
    }
  }

  String _licenseStatusLabel(MetadataProviderLicenseStatusDto? status) {
    if (status == null) {
      return '未提供';
    }
    if (status.active) {
      return '已激活';
    }
    if (!status.configured) {
      return '未配置';
    }
    final errorCode = status.errorCode?.trim();
    if (errorCode == 'license_expired' ||
        _isUnixSecondsExpired(status.licenseValidUntil)) {
      return '授权已到期';
    }
    if (status.licenseValidUntil != null) {
      return '授权待同步';
    }
    if (errorCode == 'license_required') {
      return '未激活';
    }
    if (errorCode == null || errorCode.isEmpty) {
      return '未激活';
    }
    return '授权不可用';
  }

  String? _licenseStatusDescription(MetadataProviderLicenseStatusDto? status) {
    final label = _licenseStatusLabel(status);
    if (label == '授权待同步') {
      return '你的授权仍在有效期内，但当前设备需要重新同步授权后才能使用外部数据源。';
    }
    if (label == '授权已到期') {
      return '授权已到期，请使用新的激活码重新激活后继续使用外部数据源。';
    }
    if (label == '授权不可用') {
      return _licenseErrorSummary(status);
    }
    return null;
  }

  String _connectivityStatusLabel() {
    if (_isTestingConnectivity) {
      return '检测中';
    }
    final result = _connectivityTest;
    if (result == null) {
      return '未检测';
    }
    return result.ok ? '连接正常' : '连接异常';
  }

  String _licenseErrorSummary(MetadataProviderLicenseStatusDto? status) {
    final parts = <String>[];
    final errorCode = status?.errorCode?.trim();
    final message = status?.message?.trim();
    if (errorCode != null && errorCode.isNotEmpty) {
      parts.add('错误码: $errorCode');
    }
    if (message != null && message.isNotEmpty) {
      parts.add('说明: $message');
    }
    return parts.isEmpty ? '授权暂不可用' : parts.join(' · ');
  }
}

class _MobileDataSourcesOverviewCard extends StatelessWidget {
  const _MobileDataSourcesOverviewCard({
    required this.status,
    required this.statusLabel,
    required this.statusDescription,
    required this.connectivityLabel,
  });

  final MetadataProviderLicenseStatusDto? status;
  final String statusLabel;
  final String? statusDescription;
  final String connectivityLabel;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return Container(
      key: const Key('mobile-data-sources-overview-card'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '数据源授权',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s16,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      '数据源负责 DMM、JavDB、MissAV 等外部元数据能力，需要完成授权后使用。',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.md),
              AppBadge(
                label: statusLabel,
                tone: _statusBadgeTone(statusLabel),
                size: AppBadgeSize.compact,
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - spacing.sm) / 2;
              return Wrap(
                spacing: spacing.sm,
                runSpacing: spacing.sm,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _MobileDataSourcesMetricTile(
                      label: '授权状态',
                      value: statusLabel,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _MobileDataSourcesMetricTile(
                      label: '授权有效期',
                      value: _formatLicenseValidUntil(status),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _MobileDataSourcesMetricTile(
                      label: '授权中心',
                      value: connectivityLabel,
                    ),
                  ),
                ],
              );
            },
          ),
          if (statusDescription != null) ...[
            SizedBox(height: spacing.md),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(spacing.md),
              decoration: BoxDecoration(
                color: colors.warningSurface,
                borderRadius: context.appRadius.mdBorder,
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Text(
                statusDescription!,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.warning,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  AppBadgeTone _statusBadgeTone(String label) {
    return switch (label) {
      '已激活' => AppBadgeTone.success,
      '授权待同步' => AppBadgeTone.warning,
      '未激活' => AppBadgeTone.warning,
      '未配置' => AppBadgeTone.warning,
      '授权已到期' => AppBadgeTone.error,
      '授权不可用' => AppBadgeTone.error,
      _ => AppBadgeTone.neutral,
    };
  }
}

class _MobileDataSourcesMetricTile extends StatelessWidget {
  const _MobileDataSourcesMetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.xs / 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDataSourcesInfoPill extends StatelessWidget {
  const _MobileDataSourcesInfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.sm,
        vertical: context.appSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.smBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Text(
        '$label: $value',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }
}

class _MobileDataSourcesLoadingSection extends StatelessWidget {
  const _MobileDataSourcesLoadingSection();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      key: const Key('mobile-data-sources-loading'),
      children: List<Widget>.generate(5, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.md),
          child: Container(
            width: double.infinity,
            height: index == 0 ? 120 : 44,
            decoration: BoxDecoration(
              color: context.appColors.surfaceMuted,
              borderRadius: context.appRadius.lgBorder,
            ),
          ),
        );
      }),
    );
  }
}

class _MobileDataSourcesErrorSection extends StatelessWidget {
  const _MobileDataSourcesErrorSection({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mobile-data-sources-error-state'),
      padding: EdgeInsets.all(context.appSpacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppEmptyState(message: message),
          Align(
            alignment: Alignment.center,
            child: AppButton(
              key: const Key('mobile-data-sources-retry-button'),
              label: '重试',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => unawaited(onRetry()),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatLicenseValidUntil(MetadataProviderLicenseStatusDto? status) {
  if (status == null) {
    return '未提供';
  }
  final unixSeconds = status.licenseValidUntil;
  if (unixSeconds == null) {
    return status.active ? '永久有效' : '未提供';
  }
  final value = DateTime.fromMillisecondsSinceEpoch(
    unixSeconds * 1000,
    isUtc: true,
  );
  return '有效至 ${DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal())}';
}

bool _isUnixSecondsExpired(int? unixSeconds) {
  if (unixSeconds == null) {
    return false;
  }
  final value = DateTime.fromMillisecondsSinceEpoch(
    unixSeconds * 1000,
    isUtc: true,
  );
  return value.isBefore(DateTime.now().toUtc());
}

String _diagnosticValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return '未提供';
  }
  return trimmed;
}
