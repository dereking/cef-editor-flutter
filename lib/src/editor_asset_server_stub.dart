/// Web placeholder for [EditorAssetServer].
///
/// `dart:io` is unavailable on web; the editor assets are served by the
/// Flutter web server at the canonical asset URL instead. Use [editorPageUri]
/// to obtain the editor page URL on web.
class EditorAssetServer {
  const EditorAssetServer._();

  static Uri get instanceUri => Uri.parse(
        '/assets/packages/cef_editor/web_editor/dist/index.html',
      );
}
