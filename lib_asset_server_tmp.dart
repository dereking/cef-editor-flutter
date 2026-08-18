import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MailEditorAssetServer {
  static const String _assetRoot = 'packages/glink_mail_client/web_editor/dist';
  static final MailEditorAssetServer instance = MailEditorAssetServer._();

  MailEditorAssetServer._();

  HttpServer? _server;
  Uri? _uri;
  void Function(String message)? onDiagnostic;

  Uri? get uri => _uri;

  Future<Uri> start({void Function(String message)? onDiagnostic}) async {
    this.onDiagnostic = onDiagnostic ?? this.onDiagnostic;
    if (_server != null && _uri != null) return _uri!;

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    _uri = Uri.parse('http://127.0.0.1:${server.port}/mail-editor/');
    _diagnostic('asset server started address=$_uri');
    unawaited(_serve(server));
    return _uri!;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _uri = null;
    _diagnostic('asset server stopped');
    await server?.close(force: true);
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      await _handle(request);
    }
  }

  Future<Uint8List?> _loadFromFileSystem(String assetPath) async {
    // assetPath format: packages/glink_mail_client/web_editor/dist/...
    // glink_mail_client is a path dependency at ../glink-mail-client
    // relative to the app directory. During flutter run, CWD is the app dir.
    final parts = assetPath.split('/');
    final pkgIndex = parts.indexOf('glink_mail_client');
    if (pkgIndex < 0) return null;

    final relativePath = parts.sublist(pkgIndex + 1).join('/');

    // Try relative to CWD (the app directory in debug mode).
    final candidates = [
      '../glink-mail-client/$relativePath',
      'app/glink-mail-client/$relativePath',
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    }

    return null;
  }

  Future<void> _handle(HttpRequest request) async {
    final path = assetPathFor(request.uri.path);
    _diagnostic('asset request path=${request.uri.path}');
    if (path == null) {
      debugPrint('[MailEditorAssetServer] 404: ${request.uri.path}');
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      _diagnostic('asset response status=404 path=${request.uri.path}');
      return;
    }

    debugPrint('[MailEditorAssetServer] ${request.uri.path} -> $path');
    try {
      final bytes = await rootBundle.load(path);
      final data = bytes.buffer.asUint8List();
      if (data.isEmpty) {
        debugPrint('[MailEditorAssetServer] empty: $path');
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          contentTypeFor(path),
        );
        request.response.add(data);
      }
    } catch (e) {
      // Fall back to filesystem for assets not bundled (e.g. deeply nested
      // TinyMCE skins that Flutter's asset bundling doesn't pick up).
      final fsData = await _loadFromFileSystem(path);
      if (fsData != null && fsData.isNotEmpty) {
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          contentTypeFor(path),
        );
        request.response.add(fsData);
      } else {
        debugPrint('[MailEditorAssetServer] error loading $path: $e');
        request.response.statusCode = HttpStatus.notFound;
      }
    } finally {
      await request.response.close();
      _diagnostic(
        'asset response status=${request.response.statusCode} path=$path',
      );
    }
  }

  void _diagnostic(String message) {
    debugPrint('[MailEditorAssetServer] $message');
    onDiagnostic?.call(message);
  }

  static String? assetPathFor(String requestPath) {
    var path = Uri.decodeComponent(requestPath);
    // Collapse repeated slashes (e.g. /mail-editor//skins/ → /mail-editor/skins/)
    path = path.replaceAll(RegExp(r'/+'), '/');
    if (path == '/' || path == '/mail-editor' || path == '/mail-editor/') {
      return '$_assetRoot/index.html';
    }
    if (!path.startsWith('/mail-editor/')) return null;

    path = path.substring('/mail-editor/'.length);
    if (path.isEmpty) return '$_assetRoot/index.html';
    if (path.contains('..') || path.startsWith('/')) return null;
    return '$_assetRoot/$path';
  }

  static String contentTypeFor(String path) {
    if (path.endsWith('.html')) return 'text/html; charset=utf-8';
    if (path.endsWith('.js')) return 'text/javascript; charset=utf-8';
    if (path.endsWith('.css')) return 'text/css; charset=utf-8';
    if (path.endsWith('.json')) return 'application/json; charset=utf-8';
    if (path.endsWith('.svg')) return 'image/svg+xml';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.woff2')) return 'font/woff2';
    if (path.endsWith('.woff')) return 'font/woff';
    if (path.endsWith('.ttf')) return 'font/ttf';
    if (path.endsWith('.eot')) return 'application/vnd.ms-fontobject';
    return 'application/octet-stream';
  }
}
