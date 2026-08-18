import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'editor_controller.dart';
import 'editor_host.dart';
import 'editor_message.dart';
import 'editor_host_factory_stub.dart'
    if (dart.library.js_interop) 'editor_host_factory_web.dart';

/// Entry point to obtain a platform-appropriate [RichTextEditorHost].
///
/// Desktop uses [CefEditorHost]; web uses an iframe host. Conditionally
/// exported so the CEF dependency is only pulled in on desktop.
RichTextEditorHost Function() get createRichTextEditorHost =>
    createEditorHostImpl;

/// A cross-platform rich text (TinyMCE) editor.
///
/// [editorUri] points at the editor page served by [EditorAssetServer]. The
/// page reports `window.MailEditor` once ready; the widget injects the
/// `window.MailFlutter` bridge and calls `MailEditor.open(...)` with
/// [initialHtml].
class RichTextEditorWidget extends StatefulWidget {
  final Uri editorUri;
  final String? initialHtml;
  final ValueChanged<EditorMessage>? onMessage;
  final RichTextEditorController? controller;
  final bool isDark;
  final bool readOnly;
  final void Function(String message)? onDiagnostic;

  const RichTextEditorWidget({
    super.key,
    required this.editorUri,
    this.initialHtml,
    this.onMessage,
    this.controller,
    this.isDark = false,
    this.readOnly = false,
    this.onDiagnostic,
  });

  @override
  State<RichTextEditorWidget> createState() => _RichTextEditorWidgetState();
}

class _RichTextEditorWidgetState extends State<RichTextEditorWidget> {
  RichTextEditorHost? _host;
  Future<void>? _initFuture;
  bool _initialFocusRequested = false;

  /// Prefix for console-based fallback bridge messages from the editor page.
  static const _consoleBridgePrefix = '__MF__:';

  @override
  void initState() {
    super.initState();
    widget.controller?.dispose();
    _initFuture = _initializeEditor();
  }

  @override
  void dispose() {
    _host = null;
    super.dispose();
  }

  void _onMessage(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final msg = EditorMessage.fromJson(decoded);
      if (msg.type == EditorMessageType.ready) {
        widget.controller?.markReady();
        _focusEditorOnce();
      }
      widget.onMessage?.call(msg);
    } catch (e) {
      _diagnostic('bridge error: $e');
    }
  }

  Future<void> _initializeEditor() async {
    try {
      final host = createRichTextEditorHost();
      _host = host;
      await host.initialize(
        widget.editorUri.toString(),
        onMessage: _onMessage,
        onDiagnostic: _diagnostic,
      );
      widget.controller?.attach(host);
      if (mounted) setState(() {});
      await _openEditor();
    } catch (error) {
      _reportError('Editor initialization failed: $error');
    }
  }

  Future<void> _openEditor() async {
    final host = _host;
    if (host == null) return;

    // Wait for the page to expose window.MailEditor (poll up to ~10s).
    var ready = false;
    for (var attempt = 0; attempt < 100; attempt++) {
      final result = await host.evaluateJavascript(
        'typeof window.MailEditor !== "undefined" ? "yes" : "no"',
      );
      if (RichTextEditorController.jsStringResult(result) == 'yes') {
        ready = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!ready) {
      _reportError('MailEditor API missing after page load');
      return;
    }

    // Inject the bridge. The editor page also posts to window.parent for the
    // web iframe host; defineProperty prevents the native channel from
    // overwriting it later.
    await host.evaluateJavascript('''
      (function() {
        var bridge = {
          postMessage: function(msg) {
            try { window.parent.postMessage(msg, '*'); } catch (e) {}
            console.log('$_consoleBridgePrefix' + msg);
          }
        };
        try {
          Object.defineProperty(window, 'MailFlutter', {
            value: bridge, writable: false, configurable: false
          });
        } catch (e) {
          window.MailFlutter = bridge;
        }
      })();
    ''');

    final initialHtml = widget.initialHtml ?? '';
    final escaped = initialHtml
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
    final theme = widget.isDark ? 'dark' : 'light';
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    await host.evaluateJavascript(
      "window.MailEditor.open({html: '$escaped', theme: '$theme', "
      'devicePixelRatio: $devicePixelRatio, '
      'readonly: ${widget.readOnly}})',
    );
    _diagnostic('MailEditor.open() called');
  }

  void _focusEditorOnce() {
    if (_initialFocusRequested) return;
    _initialFocusRequested = true;
    unawaited(_host?.requestFocus());
  }

  void _reportError(String error) {
    widget.onMessage?.call(
      EditorMessage(type: EditorMessageType.error, error: error),
    );
    _diagnostic('editor error=$error');
  }

  void _diagnostic(String message) {
    widget.onDiagnostic?.call(message);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Editor failed to load'));
        }
        final host = _host;
        if (host == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return host.buildView();
      },
    );
  }
}
