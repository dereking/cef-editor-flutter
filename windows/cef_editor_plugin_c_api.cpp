#include "include/cef_editor/cef_editor_plugin_c_api.h"

// No-op registration: cef_editor is a build-hook-only plugin (see
// windows/CMakeLists.txt). Keeping the symbol satisfies Flutter's plugin
// registrant without introducing any native runtime behavior.
void CefEditorPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {}
