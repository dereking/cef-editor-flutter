import 'dart:io';

import 'cef/cef_editor_host.dart';
import 'editor_host.dart';
import 'mobile/mobile_editor_host.dart';

/// Non-web factory: mobile (Android/iOS) uses the platform webview via
/// webview_flutter; desktop uses the CEF host.
RichTextEditorHost createEditorHostImpl() {
  if (Platform.isAndroid || Platform.isIOS) {
    return MobileEditorHost();
  }
  return CefEditorHost();
}
