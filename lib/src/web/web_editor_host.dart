import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../editor_host.dart';

/// Web host: renders the editor page in an iframe and bridges calls over
/// `window.postMessage` (which works cross-origin).
///
/// The editor page must handle two postMessage protocols:
///  - `{type:'eval', id, script}` -> run `eval(script)` and post back
///    `{type:'eval-result', id, result}` (this lets the controller's
///    evaluateJavascript work across the cross-origin iframe boundary);
///  - bridge messages -> the page's `MailFlutter` bridge posts
///    `{type:'bridge', message}` to `window.parent`, which we forward to the
///    message handler.
class WebEditorHost implements RichTextEditorHost {
  web.HTMLIFrameElement? _iframe;
  ValueChanged<String>? _messageHandler;
  int _nextEvalId = 0;
  final Map<int, Completer<String?>> _pendingEvals = {};

  @override
  Widget buildView() {
    final iframe = _iframe;
    if (iframe == null) return const SizedBox.shrink();
    const viewType = 'cef_editor_webview';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (viewId) {
      return iframe;
    });
    return const HtmlElementView(viewType: viewType);
  }

  /// Creates the iframe, navigates to [url] and starts listening for messages.
  Future<void> initialize(
    String url, {
    required ValueChanged<String> onMessage,
    void Function(String message)? onDiagnostic,
  }) async {
    _messageHandler = onMessage;
    final iframe = web.HTMLIFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    _iframe = iframe;
    web.window.addEventListener('message', _onWindowMessage.toJS);
  }

  void _onWindowMessage(web.MessageEvent event) {
    final data = event.data;
    final text = data.toString();
    Map<String, dynamic>? msg;
    try {
      msg = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = msg['type'] as String?;
    if (type == 'eval-result') {
      final id = msg['id'] as int?;
      final completer = id == null ? null : _pendingEvals.remove(id);
      if (completer != null) {
        final result = msg['result'];
        completer.complete(result?.toString());
      }
      return;
    }
    if (type == 'bridge') {
      _messageHandler?.call(msg['message'] as String? ?? '');
    }
  }

  @override
  Future<String?> evaluateJavascript(String script) async {
    final iframe = _iframe;
    if (iframe == null) return null;
    final id = ++_nextEvalId;
    final completer = Completer<String?>();
    _pendingEvals[id] = completer;
    final payload = jsonEncode({'type': 'eval', 'id': id, 'script': script});
    iframe.contentWindow?.postMessage(payload.toJS, '*'.toJS);
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pendingEvals.remove(id);
        return null;
      },
    );
  }

  @override
  void setMessageHandler(ValueChanged<String>? handler) {
    _messageHandler = handler;
  }

  @override
  Future<void> requestFocus() async {
    _iframe?.focus();
  }

  @override
  Future<void> dispose() async {
    _pendingEvals.clear();
    _iframe = null;
  }
}
