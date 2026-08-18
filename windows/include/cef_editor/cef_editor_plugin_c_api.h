#ifndef CEF_EDITOR_PLUGIN_C_API_H_
#define CEF_EDITOR_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

// Registration entry point. cef_editor is a build-hook-only plugin: it has no
// native Dart-facing API, but Flutter requires a registered plugin class so the
// host build pulls in windows/CMakeLists.txt (which builds the editor web
// assets and publishes them to the host build directory).
FLUTTER_PLUGIN_EXPORT void CefEditorPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}
#endif

#endif  // CEF_EDITOR_PLUGIN_C_API_H_
