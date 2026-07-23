import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> copyTextToClipboard(String text) async {
  if (web.window.isSecureContext) {
    try {
      await web.window.navigator.clipboard.writeText(text).toDart;
      return true;
    } catch (_) {
      // Fall back for browsers that deny the Clipboard API.
    }
  }
  return _copyTextWithLegacyApi(text);
}

bool _copyTextWithLegacyApi(String text) {
  final textArea =
      web.HTMLTextAreaElement()
        ..value = text
        ..readOnly = true
        ..style.cssText =
            'position:fixed;left:0;top:0;width:1px;height:1px;'
            'opacity:0;pointer-events:none;';
  final body = web.document.body;
  if (body == null) {
    return false;
  }

  body.append(textArea);
  try {
    textArea.focus();
    textArea.select();
    textArea.setSelectionRange(0, text.length);
    return web.document.execCommand('copy');
  } catch (_) {
    return false;
  } finally {
    textArea.remove();
  }
}
