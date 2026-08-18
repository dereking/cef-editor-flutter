enum ComposeQuoteMode {
  none,
  reply,
  forward,
}

class ComposeBodyBuilder {
  const ComposeBodyBuilder._();

  /// Builds the HTML loaded into the editor when replying or forwarding.
  ///
  /// Keeping the quote in this document means the compose window needs only
  /// one CEF browser: the editable mail editor.
  static String buildEditorInitialHtml({
    required String editorHtml,
    required ComposeQuoteMode quoteMode,
    String? quoteHeader,
    String? quoteHtml,
  }) {
    return buildHtml(
      editorHtml: editorHtml,
      quoteMode: quoteMode,
      quoteHeader: quoteHeader,
      quoteHtml: quoteHtml,
    );
  }

  static bool hasEmbeddedQuote(String html) {
    return html.contains('class="gmail_quote"') ||
        html.contains("class='gmail_quote'");
  }

  static String buildHtml({
    required String editorHtml,
    required ComposeQuoteMode quoteMode,
    String? quoteHeader,
    String? quoteHtml,
  }) {
    final content = editorHtml.trim().isEmpty ? '<p></p>' : editorHtml.trim();
    final buffer = StringBuffer()
      ..write('<div class="reply-content">')
      ..write(content)
      ..write('</div>');

    final originalHtml = quoteHtml?.trim();
    if (quoteMode == ComposeQuoteMode.none ||
        originalHtml == null ||
        originalHtml.isEmpty) {
      return buffer.toString();
    }

    buffer.write('<br>');
    if (quoteMode == ComposeQuoteMode.forward) {
      buffer.write('<div class="gmail_quote forwarded-message">');
    } else {
      buffer.write('<div class="gmail_quote">');
    }

    buffer.write('<blockquote>');
    final header = quoteHeader?.trim();
    if (header != null && header.isNotEmpty) {
      buffer
        ..write('<div class="quote-header">')
        ..write(_escapeHtmlPreservingLineBreaks(header))
        ..write('</div>');
    }
    buffer
      ..write(originalHtml)
      ..write('</blockquote></div>');
    return buffer.toString();
  }

  static String buildPlainText({
    required String editorText,
    required ComposeQuoteMode quoteMode,
    String? quoteHeader,
    String? quoteText,
  }) {
    final content = editorText.trimRight();
    final originalText = quoteText?.trimRight();
    if (quoteMode == ComposeQuoteMode.none ||
        originalText == null ||
        originalText.isEmpty) {
      return content;
    }

    final buffer = StringBuffer();
    if (content.isNotEmpty) {
      buffer
        ..write(content)
        ..write('\n\n');
    }

    final header = quoteHeader?.trim();
    if (header != null && header.isNotEmpty) {
      buffer..writeln(header);
    }

    for (final line in originalText.split('\n')) {
      buffer
        ..write('> ')
        ..writeln(line);
    }
    return buffer.toString().trimRight();
  }

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String _escapeHtmlPreservingLineBreaks(String input) {
    return _escapeHtml(input).replaceAll(RegExp(r'\r?\n'), '<br/>');
  }
}
