import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../editor_host.dart';

/// Mobile host backed by the platform webview (Android WebView / iOS WKWebView)
/// via `webview_flutter`.
///
/// The editor page is served by [EditorAssetServer] over the app's loopback
/// HTTP server; the platform webview loads it. Messages from the page arrive
/// through the `MailFlutter` JS channel (postMessage), and calls are evaluated
/// with `runJavaScriptReturningResult`.
class MobileEditorHost implements RichTextEditorHost {
  WebViewController? _controller;

  @override
  Future<void> initialize(
    String url, {
    required ValueChanged<String> onMessage,
    void Function(String message)? onDiagnostic,
  }) async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (pageUrl) {
            onDiagnostic?.call('page finished $pageUrl');
          },
          onWebResourceError: (error) {
            onDiagnostic?.call('web resource error: ${error.description}');
          },
        ),
      );
    await controller.addJavaScriptChannel(
      'MailFlutter',
      onMessageReceived: (message) => onMessage(message.message),
    );
    _controller = controller;
    await controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget buildView() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return WebViewWidget(controller: controller);
  }

  @override
  Future<String?> evaluateJavascript(String script) async {
    final controller = _controller;
    if (controller == null) return null;
    final result = await controller.runJavaScriptReturningResult(script);
    return result.toString();
  }

  @override
  void setMessageHandler(ValueChanged<String>? handler) {
    // Messages are routed through the JavascriptChannel registered in
    // initialize(). Kept for interface parity.
  }

  @override
  Future<void> requestFocus() async {
    // webview_flutter manages focus internally; nothing to do.
  }

  @override
  Future<void> dispose() async {
    _controller = null;
  }
}
