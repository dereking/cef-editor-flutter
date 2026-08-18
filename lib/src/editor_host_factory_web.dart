import 'editor_host.dart';
import 'web/web_editor_host.dart';

/// Web factory: uses the iframe host (no CEF).
RichTextEditorHost createEditorHostImpl() => WebEditorHost();
