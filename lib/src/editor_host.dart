import 'package:flutter/widgets.dart';

/// Abstracts the platform webview that hosts the TinyMCE editor page.
///
/// Implementations:
///  - [CefEditorHost] (desktop): renders with CEF via webview_cef.
///  - Web: renders with an iframe (`package:web` + `dart:ui_web`).
///
/// The editor widget drives the host lifecycle: it loads [editorUri], waits
/// for the page to report `window.MailEditor`, injects the `window.MailFlutter`
/// bridge and calls `MailEditor.open(...)`. All editor↔Flutter communication
/// goes through [setMessageHandler] (JSON strings) and [evaluateJavascript].
abstract class RichTextEditorHost {
  /// Creates the webview and navigates to [url].
  ///
  /// [onMessage] receives JSON messages posted by the editor page through the
  /// `MailFlutter` bridge.
  Future<void> initialize(
    String url, {
    required ValueChanged<String> onMessage,
    void Function(String message)? onDiagnostic,
  });

  /// Builds the Flutter widget embedding the webview.
  Widget buildView();

  /// Evaluates [script] in the page, returning the string result (or null).
  Future<String?> evaluateJavascript(String script);

  /// Registers a handler for JSON messages posted from the page (via the
  /// `MailFlutter` bridge / console bridge).
  void setMessageHandler(ValueChanged<String>? handler);

  /// Requests keyboard focus on the webview.
  Future<void> requestFocus();

  /// Releases native resources.
  Future<void> dispose();
}
