import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/platform/clipboard_copy.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/account/data/account_dto.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_api_provider.dart';
import 'package:sakuramedia/features/account/presentation/providers/api_keys_provider.dart';
import 'package:sakuramedia/features/agent_connect/data/agent_connection_text.dart';
import 'package:sakuramedia/features/agent_connect/data/agent_skill_dto.dart';
import 'package:sakuramedia/features/agent_connect/presentation/providers/agent_skills_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/configuration_tab_request_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';

class AgentConnectCard extends ConsumerStatefulWidget {
  const AgentConnectCard({super.key, required this.isMobile});

  final bool isMobile;

  @override
  ConsumerState<AgentConnectCard> createState() => _AgentConnectCardState();
}

class _AgentConnectCardState extends ConsumerState<AgentConnectCard> {
  final Set<String> _selectedSkillNames = <String>{};
  int? _selectedKeyId;
  bool _isCopying = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(agentSkillsCatalogProvider);
    final keys = ref.watch(apiKeysProvider);
    final selectedSkills = _selectedSkills(catalog.value);
    final selectedKey = _selectedKey(keys.value);
    final selectedKeyId = selectedKey?.id;
    final canCopy =
        !_isCopying &&
        selectedSkills.isNotEmpty &&
        selectedKeyId != null &&
        catalog.hasValue &&
        keys.hasValue;

    return AppContentCard(
      key: const Key('agent-connect-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.agentConnectDescription,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: context.appSpacing.md),
          catalog.when(
            loading: () => _buildLoading(context, l10n),
            error: (error, _) => AppSectionError(
              title: l10n.agentConnectLoadFailed,
              message: apiErrorMessage(
                error,
                fallback: l10n.agentConnectLoadFailed,
                l10n: l10n,
              ),
              onRetry: _reloadCatalog,
            ),
            data: (data) => _buildSkillSection(context, l10n, data),
          ),
          SizedBox(height: context.appSpacing.lg),
          keys.when(
            loading: () => _buildLoading(context, l10n),
            error: (error, _) => AppSectionError(
              title: l10n.errorApiKeysLoadFailed,
              message: apiErrorMessage(
                error,
                fallback: l10n.errorApiKeysLoadFailed,
                l10n: l10n,
              ),
              onRetry: _reloadKeys,
            ),
            data: (data) => _buildKeySection(context, l10n, data),
          ),
          SizedBox(height: context.appSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              key: const Key('agent-connect-copy'),
              label: _isCopying
                  ? l10n.agentConnectCopying
                  : l10n.agentConnectCopy,
              icon: const Icon(Icons.content_copy_rounded),
              variant: AppButtonVariant.primary,
              isLoading: _isCopying,
              onPressed: canCopy
                  ? () => _copyConnection(
                      selectedSkills: selectedSkills,
                      selectedKeyId: selectedKeyId,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.appSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppInlineSpinner(),
          SizedBox(width: context.appSpacing.sm),
          Text(
            l10n.agentConnectLoading,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillSection(
    BuildContext context,
    AppLocalizations l10n,
    AgentSkillsCatalogDto catalog,
  ) {
    final skills = catalog.skills;
    if (skills.isEmpty) {
      return AppEmptyState.section(
        icon: Icons.extension_off_outlined,
        message: l10n.agentConnectEmpty,
      );
    }
    final availableNames = skills.map((skill) => skill.name).toSet();
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final selectedCount = _selectedSkillNames
        .where(availableNames.contains)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.agentConnectSelectedCount(selectedCount),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.muted,
                ),
              ),
            ),
            AppButton(
              key: const Key('agent-connect-select-all'),
              label: l10n.agentConnectSelectAll,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.xSmall,
              onPressed: _isCopying
                  ? null
                  : () => setState(
                      () => _selectedSkillNames.addAll(availableNames),
                    ),
            ),
            if (selectedCount > 0)
              AppButton(
                key: const Key('agent-connect-clear'),
                label: l10n.agentConnectClearSelection,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.xSmall,
                onPressed: _isCopying
                    ? null
                    : () => setState(_selectedSkillNames.clear),
              ),
          ],
        ),
        SizedBox(height: context.appSpacing.sm),
        AppSettingsGroup(
          children: [
            for (final skill in skills)
              _AgentSkillRow(
                key: Key('agent-skill-${skill.name}'),
                skill: skill,
                selected: _selectedSkillNames.contains(skill.name),
                chinese: chinese,
                enabled: !_isCopying,
                onToggle: () => _toggleSkill(skill.name),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeySection(
    BuildContext context,
    AppLocalizations l10n,
    List<ApiKeyDto> keys,
  ) {
    if (keys.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _keyTitle(context, l10n),
          SizedBox(height: context.appSpacing.sm),
          AppEmptyState.section(
            icon: Icons.key_off_outlined,
            message: l10n.apiKeysEmpty,
          ),
          _buildCreateKeyButton(l10n),
        ],
      );
    }

    if (keys.every((key) => !key.hasRecoverableFlag)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _keyTitle(context, l10n),
          SizedBox(height: context.appSpacing.sm),
          Text(
            l10n.agentConnectRevealUnsupported,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.error,
            ),
          ),
        ],
      );
    }

    final recoverableKeys = keys.where((key) => key.recoverable).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _keyTitle(context, l10n),
        SizedBox(height: context.appSpacing.sm),
        if (recoverableKeys.isEmpty) ...[
          Text(
            l10n.agentConnectNoRecoverableKey,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.warning,
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
        ],
        RadioGroup<int>(
          groupValue: _selectedKey(keys)?.id,
          onChanged: (value) {
            if (value == null || _isCopying) {
              return;
            }
            for (final key in keys) {
              if (key.id == value && key.recoverable) {
                setState(() => _selectedKeyId = key.id);
                break;
              }
            }
          },
          child: AppSettingsGroup(
            children: [
              for (final key in keys)
                _AgentApiKeyRow(
                  key: Key('agent-api-key-${key.id}'),
                  apiKey: key,
                  selected: key.id == _selectedKeyId,
                  enabled: key.recoverable && !_isCopying,
                ),
            ],
          ),
        ),
        if (recoverableKeys.isEmpty) _buildCreateKeyButton(l10n),
      ],
    );
  }

  Widget _keyTitle(BuildContext context, AppLocalizations l10n) {
    return Text(
      l10n.agentConnectSelectKeyTitle,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        weight: AppTextWeight.medium,
        tone: AppTextTone.primary,
      ),
    );
  }

  Widget _buildCreateKeyButton(AppLocalizations l10n) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AppButton(
        key: const Key('agent-connect-create-key'),
        label: l10n.agentConnectGoCreateKey,
        variant: AppButtonVariant.secondary,
        icon: const Icon(Icons.add_rounded),
        onPressed: _isCopying ? null : _openApiKeyCreation,
      ),
    );
  }

  List<AgentSkillDto> _selectedSkills(AgentSkillsCatalogDto? catalog) {
    return catalog?.skills
            .where((skill) => _selectedSkillNames.contains(skill.name))
            .toList(growable: false) ??
        const <AgentSkillDto>[];
  }

  ApiKeyDto? _selectedKey(List<ApiKeyDto>? keys) {
    final selectedId = _selectedKeyId;
    if (selectedId == null || keys == null) {
      return null;
    }
    for (final key in keys) {
      if (key.id == selectedId && key.recoverable) {
        return key;
      }
    }
    return null;
  }

  void _toggleSkill(String name) {
    if (_isCopying) {
      return;
    }
    setState(() {
      if (!_selectedSkillNames.add(name)) {
        _selectedSkillNames.remove(name);
      }
    });
  }

  Future<void> _reloadCatalog() async {
    ref.invalidate(agentSkillsCatalogProvider);
    await ref.read(agentSkillsCatalogProvider.future);
  }

  Future<void> _reloadKeys() async {
    ref.invalidate(apiKeysProvider);
    await ref.read(apiKeysProvider.future);
  }

  Future<void> _openApiKeyCreation() async {
    if (widget.isMobile) {
      await MobileRoutes.settingsAccountSecurity().push<void>(context);
      if (mounted) {
        ref.invalidate(apiKeysProvider);
      }
      return;
    }
    ref
        .read(configurationTabRequestProvider.notifier)
        .request('configuration-tab-account-security');
  }

  Future<void> _copyConnection({
    required List<AgentSkillDto> selectedSkills,
    required int selectedKeyId,
  }) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isCopying = true);
    try {
      final apiKey = await ref
          .read(accountApiProvider)
          .revealApiKey(selectedKeyId);
      final baseUrl = ref.read(baseUrlProvider).trim();
      if (baseUrl.isEmpty || apiKey.isEmpty) {
        throw StateError('Missing agent connection data');
      }
      final text = buildAgentConnectionText(
        baseUrl: baseUrl,
        apiKey: apiKey,
        skills: selectedSkills,
      );
      final copied = await copyTextToClipboard(text);
      if (!mounted) {
        return;
      }
      if (!copied) {
        showToast(l10n.agentConnectCopyFailed, tone: AppToastTone.error);
        return;
      }
      showToast(l10n.agentConnectCopied, tone: AppToastTone.success);
    } catch (error) {
      if (error is ApiException &&
          error.statusCode == 404 &&
          error.error?.code != 'api_key_not_found') {
        if (mounted) {
          showToast(
            l10n.agentConnectRevealUnsupported,
            tone: AppToastTone.error,
          );
        }
        return;
      }
      if (error is ApiException &&
          (error.statusCode == 404 || error.statusCode == 409)) {
        ref.invalidate(apiKeysProvider);
        if (mounted) {
          setState(() => _selectedKeyId = null);
        }
      }
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.agentConnectRevealKeyFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isCopying = false);
      }
    }
  }
}

class _AgentSkillRow extends StatelessWidget {
  const _AgentSkillRow({
    super.key,
    required this.skill,
    required this.selected,
    required this.chinese,
    required this.enabled,
    required this.onToggle,
  });

  final AgentSkillDto skill;
  final bool selected;
  final bool chinese;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return AppInteractiveSurface(
      onTap: enabled ? onToggle : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IgnorePointer(
              child: Checkbox(
                value: selected,
                onChanged: enabled ? (_) {} : null,
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.displayNameFor(chinese),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      weight: AppTextWeight.medium,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    [
                      skill.name,
                      l10n.agentConnectVersion(skill.version),
                      if (skill.author.isNotEmpty) skill.author,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.muted,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    skill.descriptionFor(chinese),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentApiKeyRow extends StatelessWidget {
  const _AgentApiKeyRow({
    super.key,
    required this.apiKey,
    required this.selected,
    required this.enabled,
  });

  final ApiKeyDto apiKey;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lastUsed = formatUpdatedAtLabel(apiKey.lastUsedAt);
    return Material(
      color: Colors.transparent,
      child: RadioListTile<int>(
        value: apiKey.id,
        enabled: enabled,
        selected: selected,
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.appSpacing.lg,
          vertical: context.appSpacing.xs,
        ),
        title: Text(
          apiKey.name.isEmpty ? l10n.apiKeyUnnamed : apiKey.name,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: selected ? AppTextWeight.medium : AppTextWeight.regular,
            tone: selected ? AppTextTone.accent : AppTextTone.primary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                apiKey.keyHint,
                lastUsed == null
                    ? l10n.apiKeyNeverUsed
                    : l10n.apiKeyLastUsed(lastUsed),
              ].join(' · '),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.muted,
              ),
            ),
            if (!apiKey.recoverable) ...[
              SizedBox(height: context.appSpacing.xs),
              Text(
                l10n.agentConnectKeyUnavailable,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
