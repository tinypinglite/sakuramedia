import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_market_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// 插件市场搜索框：输入内容直接写入市场 provider 的关键词。
class PluginMarketSearchField extends ConsumerStatefulWidget {
  const PluginMarketSearchField({super.key, required this.fieldKey});

  final Key fieldKey;

  @override
  ConsumerState<PluginMarketSearchField> createState() =>
      _PluginMarketSearchFieldState();
}

class _PluginMarketSearchFieldState
    extends ConsumerState<PluginMarketSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(pluginMarketProvider).value?.keyword ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppTextField(
      fieldKey: widget.fieldKey,
      controller: _controller,
      hintText: l10n.pluginMarketSearchHint,
      prefix: Icon(
        Icons.search_rounded,
        size: context.appComponentTokens.iconSizeSm,
        color: context.appTextPalette.muted,
      ),
      onChanged: ref.read(pluginMarketProvider.notifier).setKeyword,
    );
  }
}
