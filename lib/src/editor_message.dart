/// Message types sent from the editor (TinyMCE) page to the Flutter host.
enum EditorMessageType { ready, changed, send, error, unknown }

/// A message posted from the editor page across the JS bridge.
class EditorMessage {
  final EditorMessageType type;
  final String? html;
  final String? plainText;
  final String? error;

  const EditorMessage({
    required this.type,
    this.html,
    this.plainText,
    this.error,
  });

  factory EditorMessage.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String?;
    return EditorMessage(
      type: switch (rawType) {
        'mail.editor.ready' => EditorMessageType.ready,
        'mail.editor.changed' => EditorMessageType.changed,
        'mail.editor.send' => EditorMessageType.send,
        'mail.editor.error' => EditorMessageType.error,
        _ => EditorMessageType.unknown,
      },
      html: json['html'] as String?,
      plainText: json['plainText'] as String?,
      error: json['error'] as String?,
    );
  }
}
