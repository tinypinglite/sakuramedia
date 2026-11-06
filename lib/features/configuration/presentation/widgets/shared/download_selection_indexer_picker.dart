import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_header.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

Future<List<String>?> showDownloadSelectionIndexerPicker(
  BuildContext context, {
  required String title,
  required String description,
  required List<String> availableNames,
  required List<String> selectedNames,
  bool ordered = false,
}) {
  return showAppAdaptiveModal<List<String>>(
    context: context,
    modalKey: const Key('download-selection-indexer-picker'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    mobileHeightFactor: 0.82,
    showDesktopCloseButton: false,
    builder: (_) => _DownloadSelectionIndexerPicker(
      title: title,
      description: description,
      availableNames: availableNames,
      selectedNames: selectedNames,
      ordered: ordered,
    ),
  );
}

class _DownloadSelectionIndexerPicker extends StatefulWidget {
  const _DownloadSelectionIndexerPicker({
    required this.title,
    required this.description,
    required this.availableNames,
    required this.selectedNames,
    required this.ordered,
  });

  final String title;
  final String description;
  final List<String> availableNames;
  final List<String> selectedNames;
  final bool ordered;

  @override
  State<_DownloadSelectionIndexerPicker> createState() =>
      _DownloadSelectionIndexerPickerState();
}

class _DownloadSelectionIndexerPickerState
    extends State<_DownloadSelectionIndexerPicker> {
  late final List<String> _options;
  late final List<String> _selected;

  @override
  void initState() {
    super.initState();
    final seen = <String>{};
    _options = <String>[
      for (final name in <String>[
        ...widget.selectedNames,
        ...widget.availableNames,
      ])
        if (name.trim().isNotEmpty && seen.add(name.toLowerCase())) name.trim(),
    ];
    _selected = <String>[
      for (final name in widget.selectedNames)
        if (_options.any((item) => item.toLowerCase() == name.toLowerCase()))
          _options.firstWhere(
            (item) => item.toLowerCase() == name.toLowerCase(),
          ),
    ];
  }

  void _toggle(String name) {
    final index = _selected.indexWhere(
      (item) => item.toLowerCase() == name.toLowerCase(),
    );
    setState(() {
      if (index >= 0) {
        _selected.removeAt(index);
      } else {
        _selected.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final isDrawer = AppAdaptiveModalShellScope.maybeIsDrawer(context);
    final body = _options.isEmpty
        ? AppPickerIosState(message: l10n.downloadSelectionNoIndexers)
        : SingleChildScrollView(
            child: AppPickerIosSection(
              header: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.commonSelectedCount(_selected.length),
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.muted,
                      ),
                    ),
                  ),
                  AppPickerIosActionButton(
                    key: const Key('download-selection-indexer-picker-clear'),
                    label: l10n.downloadSelectionClearSelection,
                    onPressed: _selected.isEmpty
                        ? null
                        : () => setState(_selected.clear),
                  ),
                ],
              ),
              children: [
                for (final name in _options)
                  Builder(
                    builder: (context) {
                      final selectedIndex = _selected.indexWhere(
                        (item) => item.toLowerCase() == name.toLowerCase(),
                      );
                      final available = widget.availableNames.any(
                        (item) => item.toLowerCase() == name.toLowerCase(),
                      );
                      return AppPickerIosRow(
                        optionKey: Key(
                          'download-selection-indexer-option-$name',
                        ),
                        selected: selectedIndex >= 0,
                        showCheckmark: true,
                        onTap: () => _toggle(name),
                        title: available
                            ? name
                            : l10n.downloadSelectionIndexerUnavailable(name),
                        trailingText: widget.ordered && selectedIndex >= 0
                            ? '${selectedIndex + 1}'
                            : null,
                      );
                    },
                  ),
              ],
            ),
          );
    return Column(
      mainAxisSize: isDrawer ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPickerHeader(
          title: widget.title,
          description: widget.description,
          onClose: () => Navigator.of(context).pop(),
          closeKey: const Key('download-selection-indexer-picker-close'),
          onDone: () => Navigator.of(context).pop(List<String>.from(_selected)),
          doneKey: const Key('download-selection-indexer-picker-done'),
        ),
        SizedBox(height: spacing.lg),
        AppPickerListFrame(isDrawer: isDrawer, child: body),
      ],
    );
  }
}
