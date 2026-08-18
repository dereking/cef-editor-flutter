import 'package:flutter/material.dart';
import 'package:cef_editor/cef_editor.dart';

void main() {
  runApp(const CefEditorExampleApp());
}

class CefEditorExampleApp extends StatelessWidget {
  const CefEditorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('cef_editor (web)')),
        body: const Padding(
          padding: EdgeInsets.all(12),
          child: EditorDemo(),
        ),
      ),
    );
  }
}

class EditorDemo extends StatefulWidget {
  const EditorDemo({super.key});

  @override
  State<EditorDemo> createState() => _EditorDemoState();
}

class _EditorDemoState extends State<EditorDemo> {
  final _controller = RichTextEditorController();
  String _status = 'loading...';
  String _html = '';

  @override
  Widget build(BuildContext context) {
    // On web the editor page is served by the Flutter web asset server.
    final editorUri = Uri.parse(
        '/assets/packages/cef_editor/web_editor/dist/index.html');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status: $_status'),
        const SizedBox(height: 4),
        Text('HTML length: ${_html.length}'),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(
              onPressed: () async {
                final html = await _controller.getHTML();
                setState(() => _html = html);
              },
              child: const Text('Get HTML'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _controller.setHTML('<p>Hello <b>world</b> from cef_editor web</p>'),
              child: const Text('Set HTML'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                final t = await _controller.getText();
                setState(() => _status = 'text: $t');
              },
              child: const Text('Get Text'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RichTextEditorWidget(
            editorUri: editorUri,
            initialHtml: '<p>Edit <i>me</i> on the web 🎉</p>',
            controller: _controller,
            onMessage: (msg) {
              setState(() {
                _status = 'msg: ${msg.type.name}';
                if (msg.html != null) _html = msg.html!;
              });
            },
          ),
        ),
      ],
    );
  }
}
