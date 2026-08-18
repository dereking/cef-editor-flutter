import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_cef/webview_cef.dart';

enum MailEditorMessageType { ready, changed, send, error, unknown }

class MailEditorMessage {
  final MailEditorMessageType type;
  final String? html;
  final String? plainText;
  final String? error;

  const MailEditorMessage({
    required this.type,
    this.html,
    this.plainText,
    this.error,
  });

  factory MailEditorMessage.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String?;
    return MailEditorMessage(
      type: switch (rawType) {
        'mail.editor.ready' => MailEditorMessageType.ready,
        'mail.editor.changed' => MailEditorMessageType.changed,
        'mail.editor.send' => MailEditorMessageType.send,
        'mail.editor.error' => MailEditorMessageType.error,
        _ => MailEditorMessageType.unknown,
      },
      html: json['html'] as String?,
      plainText: json['plainText'] as String?,
      error: json['error'] as String?,
    );
  }
}

/// Controller for external operations on the mail CEF editor.
class MailCefEditorController {
  WebViewController? _webViewController;
  bool _editorReady = false;

  bool get isReady => _editorReady;

  void attach(WebViewController controller) {
    _webViewController = controller;
  }

  void markReady() {
    _editorReady = true;
  }

  Future<String> getHTML() async {
    final result = await _webViewController?.evaluateJavascript(
      'window.MailEditor ? window.MailEditor.getHTML() : ""',
    );
    return MailCefEditorController.jsStringResult(result) ?? '';
  }

  Future<String> getText() async {
    final result = await _webViewController?.evaluateJavascript(
      'window.MailEditor ? window.MailEditor.getText() : ""',
    );
    return MailCefEditorController.jsStringResult(result) ?? '';
  }

  Future<void> setHTML(String html) async {
    final escaped = html
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
    await _webViewController?.evaluateJavascript(
      "window.MailEditor && window.MailEditor.setHTML('$escaped')",
    );
  }

  Future<void> insertHTML(String html) async {
    final escaped = html
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
    await _webViewController?.evaluateJavascript(
      "tinymce.activeEditor && tinymce.activeEditor.insertContent('$escaped')",
    );
  }

  Future<String> getSelectedText() async {
    final result = await _webViewController?.evaluateJavascript(
      'window.MailEditor ? window.MailEditor.getSelectedText() : ""',
    );
    return MailCefEditorController.jsStringResult(result) ?? '';
  }

  Future<String> getSelectedHTML() async {
    final result = await _webViewController?.evaluateJavascript(
      'window.MailEditor ? window.MailEditor.getSelectedHTML() : ""',
    );
    return MailCefEditorController.jsStringResult(result) ?? '';
  }

  /// Returns a JSON-encoded bookmark string if there's a non-collapsed
  /// selection, or null if the selection is collapsed / empty.
  Future<String?> getSelectionBookmark() async {
    final result = await _webViewController?.evaluateJavascript(
      'window.MailEditor ? window.MailEditor.getSelectionBookmark() : null',
    );
    if (result == null) return null;
    final raw = result.toString();
    if (raw == 'null' || raw.isEmpty) return null;
    return MailCefEditorController.jsStringResult(result);
  }

  /// Sets the editor to readonly or design mode. Use to prevent keyboard
  /// shortcuts from leaking through to the editor while a dialog is open.
  Future<void> setReadOnly(bool readOnly) async {
    final mode = readOnly ? 'readonly' : 'design';
    await _webViewController?.evaluateJavascript(
      "tinymce.activeEditor && tinymce.activeEditor.mode.set('$mode')",
    );
  }

  Future<void> requestFocus() async {
    _webViewController?.requestFocus();
  }

  /// Replaces the content at the given bookmark with [html].
  /// If [bookmarkJson] is null, replaces current selection or inserts at cursor.
  Future<void> replaceSelectedContent(String html,
      {String? bookmarkJson}) async {
    final escaped = html
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
    final escapedBookmark = bookmarkJson
        ?.replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n');
    final bookmarkArg =
        escapedBookmark != null ? "'$escapedBookmark'" : 'undefined';
    await _webViewController?.evaluateJavascript(
      "window.MailEditor && window.MailEditor.replaceSelectedContent('$escaped', $bookmarkArg)",
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

  void dispose() {
    // Don't dispose the WebViewController — it's managed by the widget.
    _webViewController = null;
    _editorReady = false;
  }
}

class MailCefEditorWidget extends StatefulWidget {
  final Uri editorUri;
  final String? initialHtml;
  final ValueChanged<MailEditorMessage>? onMessage;
  final MailCefEditorController? controller;
  final bool isDark;
  final void Function(String message)? onDiagnostic;

  const MailCefEditorWidget({
    super.key,
    required this.editorUri,
    this.initialHtml,
    this.onMessage,
    this.controller,
    this.isDark = false,
    this.onDiagnostic,
  });

  @override
  State<MailCefEditorWidget> createState() => _MailCefEditorWidgetState();
}

class _MailCefEditorWidgetState extends State<MailCefEditorWidget> {
  WebViewController? _webViewController;
  Future<void>? _initFuture;
  bool _pageReady = false;
  bool _bridgeReady = false;
  bool _editorOpened = false;
  bool _initialFocusRequested = false;
  Future<void>? _pageBridgeFuture;

  /// Prefix for console-based fallback messages when CEF native JS channel
  /// is unavailable. The JS side calls console.log('__MF__:' + json) and we
  /// intercept those messages here.
  static const _consoleBridgePrefix = '__MF__:';

  @override
  void initState() {
    super.initState();
    widget.controller?.dispose();
    _initFuture = _initializeEditor();
  }

  @override
  void dispose() {
    // Do NOT dispose the CEF WebViewController here.
    // In sub-windows (separate Flutter engine via desktop_multi_window),
    // disposing the CEF view during engine teardown can crash the main
    // window because CEF is a per-process singleton. The engine teardown
    // will clean up native resources at the plugin level.
    _webViewController = null;
    super.dispose();
  }

  void _onMessage(JavascriptMessage message) {
    try {
      debugPrint('[MailCefEditor] JS message received: ${message.message}');
      final decoded = jsonDecode(message.message) as Map<String, dynamic>;
      final msg = MailEditorMessage.fromJson(decoded);
      if (msg.type == MailEditorMessageType.ready) {
        debugPrint('[MailCefEditor] editor ready!');
        widget.controller?.markReady();
        _focusEditorOnce();
      }
      widget.onMessage?.call(msg);
    } catch (e) {
      debugPrint('[MailCefEditor] bridge error: $e');
    }
  }

  void _onEditorPageLoadEnd(String url) {
    _diagnostic('page load end url=$url');
    if (!mounted || !_isEditorPageUrl(url)) return;
    _pageReady = true;
    unawaited(_registerPageBridgeAndOpenEditor());
  }

  bool _isEditorPageUrl(String url) {
    final loadedUri = Uri.tryParse(url);
    if (loadedUri == null) return false;
    final editorUri = widget.editorUri;
    return loadedUri.scheme == editorUri.scheme &&
        loadedUri.host == editorUri.host &&
        loadedUri.port == editorUri.port &&
        loadedUri.path == editorUri.path;
  }

  Future<void> _registerPageBridgeAndOpenEditor() {
    return _pageBridgeFuture ??= _registerPageBridgeAndOpenEditorImpl();
  }

  Future<void> _registerPageBridgeAndOpenEditorImpl() async {
    try {
      final c = _webViewController;
      if (c == null || !_pageReady) return;
      await c.setJavaScriptChannels({
        JavascriptChannel(
          name: 'MailFlutter',
          onMessageReceived: _onMessage,
        ),
      });
      _bridgeReady = true;
      _diagnostic('page bridge registered');
      debugPrint('[MailCefEditor] JS channel re-registered after navigation');
      await _openEditor();
    } catch (error) {
      debugPrint('[MailCefEditor] page bridge setup error: $error');
      _pageBridgeFuture = null;
      if (!mounted) return;
      widget.onMessage?.call(
        MailEditorMessage(
          type: MailEditorMessageType.error,
          error: error.toString(),
        ),
      );
      _diagnostic('page bridge setup error=$error');
    }
  }

  Future<void> _initializeEditor() async {
    try {
      debugPrint('[MailCefEditor] initializing CEF runtime...');
      await _MailEditorCefRuntime.ensureInitialized();
      _diagnostic('CEF runtime initialized');
      debugPrint('[MailCefEditor] CEF runtime ready');
      final c = WebviewManager().createWebView(
        loading: const Center(child: CircularProgressIndicator()),
        injectUserScripts: InjectUserScripts(),
      );
      _webViewController = c;
      widget.controller?.attach(c);

      // Trigger a rebuild so the FutureBuilder shows the CEF view
      // (with its own loading indicator) instead of the plain spinner.
      if (mounted) setState(() {});

      c.setWebviewListener(
        WebviewEventsListener(
          onLoadEnd: (_, url) {
            _onEditorPageLoadEnd(url);
          },
          onLoadError: (_, errorCode, errorText, failedUrl) {
            _reportError(
              'Editor page failed to load: $errorText ($errorCode)',
            );
            _diagnostic(
              'page load error code=$errorCode text=$errorText url=$failedUrl',
            );
          },
          onConsoleMessage: (level, message, source, line) {
            // Intercept console-based MailFlutter bridge messages
            if (message.startsWith(_consoleBridgePrefix)) {
              final json = message.substring(_consoleBridgePrefix.length);
              try {
                final decoded = jsonDecode(json) as Map<String, dynamic>;
                final msg = MailEditorMessage.fromJson(decoded);
                if (msg.type == MailEditorMessageType.ready) {
                  debugPrint('[MailCefEditor] editor ready! (console bridge)');
                  widget.controller?.markReady();
                  _focusEditorOnce();
                }
                widget.onMessage?.call(msg);
              } catch (e) {
                debugPrint('[MailCefEditor] console bridge parse error: $e');
              }
              return;
            }
            // Log all console messages for debugging (level 0=info, 1=log, 2=debug, 3=warn, 4=error)
            if (level >= 3) {
              _diagnostic(
                  'page console level=$level line=$line message=$message');
              debugPrint('[MailCefEditorWidget] console: $message');
            } else {
              debugPrint('[MailCefEditorWidget] console(info): $message');
            }
          },
        ),
      );

      // Initialize with about:blank so we can register JS channels before
      // navigating to the editor page. Some CEF implementations only inject
      // bindings into the current frame, so we re-register after navigation.
      debugPrint('[MailCefEditor] initializing with about:blank');
      await c.initialize('about:blank');
      await c.ready;
      _diagnostic('CEF controller ready');
      debugPrint('[MailCefEditor] CEF controller ready');

      debugPrint('[MailCefEditor] setting up JS channel');
      await c.setJavaScriptChannels({
        JavascriptChannel(
          name: 'MailFlutter',
          onMessageReceived: _onMessage,
        ),
      });
      _bridgeReady = true;

      debugPrint('[MailCefEditor] loading editor URL: ${widget.editorUri}');
      _pageReady = false;
      _pageBridgeFuture = null;
      await c.loadUrl(widget.editorUri.toString());
      _diagnostic('editor URL navigation requested');
      debugPrint('[MailCefEditor] editor URL navigation requested');
    } catch (error) {
      debugPrint('[MailCefEditorWidget] init error: $error');
      if (!mounted) return;
      widget.onMessage?.call(
        MailEditorMessage(
          type: MailEditorMessageType.error,
          error: error.toString(),
        ),
      );
      _diagnostic('editor initialization error=$error');
    }
  }

  void _focusEditorOnce() {
    if (_initialFocusRequested) return;
    _initialFocusRequested = true;
    // Editor initialization is asynchronous. Never take focus back from a
    // recipient, subject, or other Flutter input after this initial request.
    // A new compose window may already have Flutter's default focus by the
    // time CEF reports readiness. In that case Flutter will not emit another
    // focus-change notification, so explicitly re-assert native CEF focus.
    final controller = _webViewController;
    if (controller == null) return;
    if (controller.hasFocus) {
      unawaited(controller.setClientFocus(true));
      return;
    }
    controller.requestFocus();
  }

  Future<void> _openEditor() async {
    if (_editorOpened) {
      debugPrint('[MailCefEditor] _openEditor skipped: already opened');
      return;
    }
    if (!_pageReady || !_bridgeReady) {
      debugPrint(
          '[MailCefEditor] _openEditor skipped: pageReady=$_pageReady bridgeReady=$_bridgeReady');
      return;
    }

    debugPrint('[MailCefEditor] checking for window.MailEditor...');
    try {
      final result = await _webViewController?.evaluateJavascript(
        'typeof window.MailEditor !== "undefined" ? "yes" : "no"',
      );
      if (MailCefEditorController.jsStringResult(result) != 'yes') {
        _reportError('MailEditor API missing after page load');
        _diagnostic('MailEditor API missing after page load');
        return;
      }
    } catch (e) {
      _reportError('MailEditor API check failed: $e');
      _diagnostic('MailEditor API check error=$e');
      return;
    }

    _editorOpened = true;

    // Always inject the console bridge. The native CEF JS channel's
    // postMessage may be non-functional ("not a function" in some CEF
    // versions). Object.defineProperty with writable:false prevents
    // the native channel from overwriting the bridge later.
    debugPrint('[MailCefEditor] injecting console bridge');
    await _webViewController?.evaluateJavascript('''
      (function() {
        var bridge = {
          postMessage: function(msg) {
            console.log('$_consoleBridgePrefix' + msg);
          }
        };
        try {
          Object.defineProperty(window, 'MailFlutter', {
            value: bridge,
            writable: false,
            configurable: false
          });
          console.log('[MailEditor] console bridge injected');
        } catch (e) {
          window.MailFlutter = bridge;
          console.log('[MailEditor] console bridge injected (fallback)');
        }
      })();
    ''');

    final initialHtml = widget.initialHtml ?? '';
    debugPrint(
        '[MailCefEditor] calling MailEditor.open(), html length=${initialHtml.length}');
    final escaped = initialHtml
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
    final theme = widget.isDark ? 'dark' : 'light';
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    try {
      await _webViewController?.evaluateJavascript(
        "window.MailEditor.open({html: '$escaped', theme: '$theme', "
        'devicePixelRatio: $devicePixelRatio})',
      );
      debugPrint('[MailCefEditor] MailEditor.open() called successfully');
    } catch (error) {
      debugPrint('[MailCefEditor] open error: $error');
      _reportError('Unable to start the mail editor: $error');
    }
  }

  void _reportError(String error) {
    widget.onMessage?.call(
      MailEditorMessage(type: MailEditorMessageType.error, error: error),
    );
    _diagnostic('editor error=$error');
  }

  void _diagnostic(String message) {
    debugPrint('[MailCefEditor] $message');
    widget.onDiagnostic?.call(message);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[MailCefEditor] FutureBuilder error: ${snapshot.error}');
          return const Center(
            child: Text('Editor failed to load'),
          );
        }
        final c = _webViewController;
        if (c == null) {
          // CEF initialization is still in progress (first await in
          // _initializeEditor hasn't returned yet). Show a spinner.
          return const Center(child: CircularProgressIndicator());
        }
        return ValueListenableBuilder<bool>(
          valueListenable: c,
          builder: (_, ready, __) {
            return ready ? c.webviewWidget : c.loadingWidget;
          },
        );
      },
    );
  }
}

class _MailEditorCefRuntime {
  static Future<void>? _initialization;

  static Future<void> ensureInitialized() {
    if (WebviewManager().value) {
      return Future<void>.value();
    }
    return _initialization ??= WebviewManager().initialize(
      userAgent: 'GlinkMail/1.0',
    );
  }
}
