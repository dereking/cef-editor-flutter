cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "cef_editor_plugin")
project(${PROJECT_NAME} LANGUAGES CXX)

# The plugin itself is a build-hook-only stub (no runtime Dart API).
set(CEF_EDITOR_PLUGIN_SOURCES
  "cef_editor_plugin_c_api.cpp"
)

add_library(${PROJECT_NAME} SHARED ${CEF_EDITOR_PLUGIN_SOURCES})
apply_standard_settings(${PROJECT_NAME})
set_target_properties(${PROJECT_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PROJECT_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PROJECT_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PROJECT_NAME} PRIVATE flutter)

# === Build the editor web assets from source and publish to the host build dir ===
# The TinyMCE editor page is built from web_editor/src (TypeScript/Vite). When a
# Flutter project depends on this package, its CMake build invokes this rule so
# the editor JS is compiled automatically and the result lands next to the host
# executable under <build>/cef-editor (EditorAssetServer serves it from there on
# desktop). Requires a Node.js toolchain.
set(CEF_EDITOR_WEB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../web_editor")
# Resolve symlinks (flutter .plugin_symlinks) so MSBuild dependency tracking
# sees real paths.
get_filename_component(CEF_EDITOR_WEB_REAL "${CEF_EDITOR_WEB_DIR}" REALPATH)
message(STATUS "cef_editor web dir: ${CEF_EDITOR_WEB_DIR}")
message(STATUS "cef_editor web real: ${CEF_EDITOR_WEB_REAL}")
set(CEF_EDITOR_STAMP "${CMAKE_BINARY_DIR}/cef_editor_dist.stamp")

add_custom_command(
  OUTPUT "${CEF_EDITOR_STAMP}"
  COMMAND node "${CEF_EDITOR_WEB_REAL}/scripts/build.mjs" "${CEF_EDITOR_WEB_REAL}"
  COMMAND ${CMAKE_COMMAND} -E make_directory
          "${CMAKE_BINARY_DIR}/runner/$<CONFIG>/cef-editor"
  COMMAND ${CMAKE_COMMAND} -E copy_directory
          "${CEF_EDITOR_WEB_REAL}/dist"
          "${CMAKE_BINARY_DIR}/runner/$<CONFIG>/cef-editor"
  COMMAND ${CMAKE_COMMAND} -E touch "${CEF_EDITOR_STAMP}"
  DEPENDS
    "${CEF_EDITOR_WEB_REAL}/scripts/build.mjs"
    "${CEF_EDITOR_WEB_REAL}/package.json"
  COMMENT "Building cef_editor editor web assets"
  VERBATIM
)
add_custom_target(cef_editor_web ALL DEPENDS "${CEF_EDITOR_STAMP}")
add_dependencies(${PROJECT_NAME} cef_editor_web)
