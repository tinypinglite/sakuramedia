import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/app_version_info_state.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';

class AppVersionInfoCard extends ConsumerStatefulWidget {
  const AppVersionInfoCard({super.key, this.isCompact = false, this.cardKey});

  final bool isCompact;
  final Key? cardKey;

  @override
  ConsumerState<AppVersionInfoCard> createState() => _AppVersionInfoCardState();
}

class _AppVersionInfoCardState extends ConsumerState<AppVersionInfoCard> {
  Timer? _updateCheckTimer;
  String? _frontendUpdateVersion;
  String? _backendUpdateVersion;
  bool _isCheckingUpdates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_checkForUpdates());
      }
    });
    _updateCheckTimer = Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(_checkForUpdates());
    });
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdates) {
      return;
    }
    _isCheckingUpdates = true;
    try {
      await ref.read(appVersionInfoProvider.notifier).load();
      if (!mounted) {
        return;
      }
      final frontendVersion =
          ref.read(appVersionInfoProvider).value?.frontendVersion ?? '';
      final backendVersion =
          ref.read(appVersionInfoProvider).value?.backendVersion ?? '';
      final statusApi = ref.read(statusApiProvider);
      if (frontendVersion.isNotEmpty) {
        try {
          final updateVersion = await statusApi.checkFrontendUpdate(
            frontendVersion,
          );
          if (mounted) {
            setState(() => _frontendUpdateVersion = updateVersion);
          }
        } catch (_) {}
      }
      if (backendVersion.isNotEmpty) {
        try {
          final updateVersion = await statusApi.checkBackendUpdate(
            backendVersion,
          );
          if (mounted) {
            setState(() => _backendUpdateVersion = updateVersion);
          }
        } catch (_) {}
      }
      if (!mounted) {
        return;
      }

      try {
        final plugins = ref.read(pluginsProvider);
        final notifier = ref.read(pluginsProvider.notifier);
        if (plugins.hasError) {
          await notifier.reload();
        } else {
          await ref.read(pluginsProvider.future);
        }
        await notifier.checkUpdates();
      } catch (_) {}
    } finally {
      _isCheckingUpdates = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionInfo =
        ref.watch(appVersionInfoProvider).value ?? AppVersionInfoState.initial;
    final pluginUpdateCount =
        ref.watch(pluginsProvider).value?.updates.length ?? 0;
    final frontendVersion = versionInfo.frontendVersionLabel;
    final backendVersion = versionInfo.backendVersionLabel;
    final hasFrontendUpdate = _frontendUpdateVersion != null;
    final hasBackendUpdate = _backendUpdateVersion != null;
    final hasUpdates =
        hasFrontendUpdate || hasBackendUpdate || pluginUpdateCount > 0;
    final tooltipLabel = [
      versionInfo.tooltipLabel,
      if (hasFrontendUpdate) '客户端可更新至 $_frontendUpdateVersion',
      if (hasBackendUpdate) '服务端可更新至 $_backendUpdateVersion',
      if (pluginUpdateCount > 0) '$pluginUpdateCount 个插件可更新',
    ].join('\n');

    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldUseCompact =
            widget.isCompact || constraints.maxWidth < _versionCardMinWidth;
        if (shouldUseCompact) {
          return Tooltip(
            message: tooltipLabel,
            waitDuration: const Duration(milliseconds: 300),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    key: const Key('sidebar-version-info-collapsed'),
                    width: context.appSidebarTokens.itemHeight,
                    height: context.appSidebarTokens.itemHeight,
                    decoration: BoxDecoration(
                      color: hasUpdates
                          ? context.appColors.selectionSurface
                          : context.appColors.surfaceMuted,
                      borderRadius: context.appRadius.smBorder,
                    ),
                    child: Icon(
                      hasUpdates
                          ? Icons.system_update_rounded
                          : Icons.info_outline_rounded,
                      size: context.appComponentTokens.iconSizeSm,
                      color: hasUpdates
                          ? context.appTextPalette.accent
                          : context.appTextPalette.muted,
                    ),
                  ),
                  if (hasUpdates)
                    Positioned(
                      top: -context.appSpacing.xs,
                      right: -context.appSpacing.xs,
                      child: Container(
                        key: const Key('sidebar-version-update-dot'),
                        width: context.appComponentTokens.iconSize3xs,
                        height: context.appComponentTokens.iconSize3xs,
                        decoration: BoxDecoration(
                          color: context.appTextPalette.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.appColors.selectionSurface,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        return Container(
          key: widget.cardKey ?? const Key('sidebar-version-info'),
          padding: EdgeInsets.all(context.appSpacing.md),
          decoration: BoxDecoration(
            color: context.appColors.surfaceCard,
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(color: context.appColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '系统版本',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.medium,
                        tone: AppTextTone.tertiary,
                      ),
                    ),
                  ),
                  if (hasUpdates)
                    const AppBadge(
                      label: '有更新',
                      tone: AppBadgeTone.primary,
                      size: AppBadgeSize.compact,
                    ),
                ],
              ),
              SizedBox(height: context.appSpacing.sm),
              _VersionRow(label: '客户端', value: frontendVersion),
              SizedBox(height: context.appSpacing.xs),
              _VersionRow(label: '服务端', value: backendVersion),
              if (hasUpdates) ...[
                SizedBox(height: context.appSpacing.sm),
                Divider(height: 1, color: context.appColors.divider),
                SizedBox(height: context.appSpacing.sm),
                _VersionUpdateNotice(
                  frontendUpdateVersion: _frontendUpdateVersion,
                  backendUpdateVersion: _backendUpdateVersion,
                  pluginUpdateCount: pluginUpdateCount,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

const double _versionCardMinWidth = 144;

class _VersionUpdateNotice extends StatelessWidget {
  const _VersionUpdateNotice({
    required this.frontendUpdateVersion,
    required this.backendUpdateVersion,
    required this.pluginUpdateCount,
  });

  final String? frontendUpdateVersion;
  final String? backendUpdateVersion;
  final int pluginUpdateCount;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (frontendUpdateVersion != null) '客户端 $frontendUpdateVersion',
      if (backendUpdateVersion != null) '服务端 $backendUpdateVersion',
      if (pluginUpdateCount > 0) '$pluginUpdateCount 个插件',
    ].join(' · ');

    return Container(
      key: const Key('sidebar-update-notice'),
      padding: EdgeInsets.all(context.appSpacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.selectionSurface,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Row(
        children: [
          Icon(
            Icons.system_update_rounded,
            size: context.appComponentTokens.iconSizeSm,
            color: context.appTextPalette.accent,
          ),
          SizedBox(width: context.appSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '发现可用更新',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.accent,
                  ),
                ),
                SizedBox(height: context.appSpacing.xs),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s10,
                    tone: AppTextTone.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.medium,
              tone: AppTextTone.tertiary,
            ),
          ),
        ),
      ],
    );
  }
}
