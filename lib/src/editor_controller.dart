import 'dart:convert';

import 'editor_host.dart';

/// Controller for external operations on the rich text editor.
///
/// Methods evaluate JavaScript in the editor page through [RichTextEditorHost].
/// The editor page exposes a `window.MailEditor` API (TinyMCE wrapper); see the
/// bundled `web_editor` assets for the page implementation.
class RichTextEditorController {
  RichTextEditorHost? _host;
  bool _editorReady = false;

  bool get isReady => _editorReady;

  /// The host is attached by the editor widget once created.
  void attach(RichTextEditorHost host) {
    _host = host;
  }

  void markReady() {
    _editorReady = true;
  }

  Future<String> getHTML() async {
    final result = await _host?.evaluateJavascript(
      'window.MailEditor ? window.MailEditor.getHTML() : ""',
    );
    return jsStringResult(result) ?? '';
  }

  Future<String> getText() async {
    final result = await _host?.evaluateJavascript(
      'window.MailEditor ? window.MailEditor.getText() : ""',
    );
    return jsStringResult(result) ?? '';
  }

  Future<void> setHTML(String html) async {
    await _host?.evaluateJavascript(
      "window.MailEditor && window.MailEditor.setHTML('${_escape(html)}')",
    );
  }

  Future<void> insertHTML(String html) async {
    await _host?.evaluateJavascript(
      "tinymce.activeEditor && tinymce.activeEditor.insertContent('${_escape(html)}')",
    );
  }

  Future<String> getSelectedText() async {
    final result = await _host?.evaluateJavascript(
      'window.MailEditor ? window.MailEditor.getSelectedText() : ""',
    );
    return jsStringResult(result) ?? '';
  }

  Future<String> getSelectedHTML() async {
    final result = await _host?.evaluateJavascript(
      'window.MailEditor ? window.MailEditor.getSelectedHTML() : ""',
    );
    return jsStringResult(result) ?? '';
  }

  /// Returns a JSON-encoded bookmark string if there's a non-collapsed
  /// selection, or null if the selection is collapsed / empty.
  Future<String?> getSelectionBookmark() async {
    final result = await _host?.evaluateJavascript(
      'window.MailEditor ? window.MailEditor.getSelectionBookmark() : null',
    );
    if (result == null) return null;
    final raw = result.toString();
    if (raw == 'null' || raw.isEmpty) return null;
    return jsStringResult(result);
  }

  /// Sets the editor to readonly or design mode.
  Future<void> setReadOnly(bool readOnly) async {
    final mode = readOnly ? 'readonly' : 'design';
    await _host?.evaluateJavascript(
      "tinymce.activeEditor && tinymce.activeEditor.mode.set('$mode')",
    );
  }

  Future<void> requestFocus() async {
    await _host?.requestFocus();
  }

  /// Replaces the content at the given bookmark with [html].
  Future<void> replaceSelectedContent(
    String html, {
    String? bookmarkJson,
  }) async {
    final escapedBookmark = bookmarkJson == null
        ? null
        : _escape(bookmarkJson);
    final bookmarkArg =
        escapedBookmark != null ? "'$escapedBookmark'" : 'undefined';
    await _host?.evaluateJavascript(
      "window.MailEditor && window.MailEditor.replaceSelectedContent('${_escape(html)}', $bookmarkArg)",
    );
  }

  static String? jsStringResult(Object? value) {
    if (value == null) return null;
    final raw = value.toString();
    if (raw.isNotEmpty &&
        raw.startsWith('"') &&
        raw.endsWith('"') &&
        raw.length >= 2) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is String) return decoded;
      } catch (_) {}
    }
    return raw;
  }

  static String _escape(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
  }

  void dispose() {
    // Don't dispose the host — it's managed by the widget.
    _host = null;
    _editorReady = false;
  }
}
