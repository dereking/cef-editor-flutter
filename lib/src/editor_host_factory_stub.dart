import 'cef/cef_editor_host.dart';
import 'editor_host.dart';

/// Desktop factory: uses the CEF webview host.
RichTextEditorHost createEditorHostImpl() => CefEditorHost();
