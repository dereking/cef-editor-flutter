import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';

import '../editor_host.dart';

/// Prefix for console-based bridge messages used by the editor page.
const String editorConsoleBridgePrefix = '__MF__:';

/// Desktop host backed by CEF (via webview_cef).
///
/// Messages from the editor page arrive through the native `MailFlutter` JS
/// channel and, as a fallback, through console messages prefixed with
/// [editorConsoleBridgePrefix].
class CefEditorHost implements RichTextEditorHost {
  WebViewController? _controller;

  /// Creates and configures the CEF webview and navigates to [url].
  Future<void> initialize(
    String url, {
    required ValueChanged<String> onMessage,
    void Function(String message)? onDiagnostic,
  }) async {
    await WebviewManager().initialize(userAgent: 'CefEditor/1.0');
    final c = WebviewManager().createWebView(
      loading: const Center(child: CircularProgressIndicator()),
      injectUserScripts: InjectUserScripts(),
    );
    _controller = c;

    c.setWebviewListener(
      WebviewEventsListener(
        onLoadError: (_, errorCode, errorText, failedUrl) {
          onDiagnostic?.call('page load error code=$errorCode '
              'text=$errorText url=$failedUrl');
        },
        onConsoleMessage: (level, message, source, line) {
          if (message.startsWith(editorConsoleBridgePrefix)) {
            onMessage(message.substring(editorConsoleBridgePrefix.length));
          }
        },
      ),
    );

    await c.initialize('about:blank');
    await c.ready;
    await c.setJavaScriptChannels({
      JavascriptChannel(
        name: 'MailFlutter',
        onMessageReceived: (m) => onMessage(m.message),
      ),
    });
    await c.loadUrl(url);
  }

  @override
  Widget buildView() {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: c,
      builder: (_, ready, __) => ready ? c.webviewWidget : c.loadingWidget,
    );
  }

  @override
  Future<String?> evaluateJavascript(String script) async {
    final result = await _controller?.evaluateJavascript(script);
    return result?.toString();
  }

  @override
  void setMessageHandler(ValueChanged<String>? handler) {
    // Messages are routed through the callbacks captured in initialize().
    // Keeping this for interface parity.
  }

  @override
  Future<void> requestFocus() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.hasFocus) {
      // A fresh compose window already owns Flutter focus (autofocus) before
      // CEF reports readiness, so Flutter emits no later focus-change
      // notification and never re-sends setClientFocus(true). Re-assert the
      // native CEF focus explicitly, otherwise the first click is processed
      // by an unfocused browser and the editor looks read-only until the user
      // clicks another field first.
      await controller.setClientFocus(true);
    } else {
      controller.requestFocus();
    }
  }

  @override
  Future<void> dispose() async {
    // The controller is owned by the widget; release the reference only.
    _controller = null;
  }
}
