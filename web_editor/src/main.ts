import tinymce from 'tinymce/tinymce';
import type { Editor } from 'tinymce/tinymce';
import 'tinymce/themes/silver';
import 'tinymce/models/dom';
import 'tinymce/icons/default';

// Plugins (all MIT-licensed community plugins)
import 'tinymce/plugins/advlist';
import 'tinymce/plugins/autolink';
import 'tinymce/plugins/lists';
import 'tinymce/plugins/link';
import 'tinymce/plugins/image';
import 'tinymce/plugins/code';
import 'tinymce/plugins/searchreplace';

import { postToFlutter } from './flutter_bridge';
import { MailEditorContextMenu } from './context_menu';
import { calculatePastedImageSize } from './pasted_image_size';

let initialHtml = '';
let initPromise: Promise<void> | null = null;
let currentTheme: 'light' | 'dark' = 'light';
let currentDevicePixelRatio = window.devicePixelRatio;
let currentReadOnly = false;
const pastedImageMarker = 'data-mail-pasted-image';

function reportStartupError(error: unknown): void {
  const message = error instanceof Error ? error.message : String(error);
  console.error('[MailEditor] startup error:', message);
  postToFlutter({ type: 'mail.editor.error', error: message });
}

window.addEventListener('error', (event) => {
  reportStartupError(event.error ?? event.message);
});

window.addEventListener('unhandledrejection', (event) => {
  reportStartupError(event.reason);
});

declare global {
  interface Window {
    MailEditor: {
      open(config: {
        html: string;
        theme?: 'light' | 'dark';
        devicePixelRatio?: number;
        readonly?: boolean;
      }): void;
      getHTML(): string;
      getText(): string;
      setHTML(html: string): void;
      getSelectedText(): string;
      getSelectedHTML(): string;
      getSelectionBookmark(): string | null;
      moveToBookmark(bookmarkJson: string): boolean;
      replaceSelectedContent(html: string, bookmarkJson?: string): boolean;
      setReadOnly(readOnly: boolean): void;
    };
  }
}

function notifyContentChanged(editor: Editor): void {
  postToFlutter({
    type: 'mail.editor.changed',
    html: editor.getContent(),
    plainText: editor.getContent({ format: 'text' }),
  });
}

function normalizePastedImage(
  editor: Editor,
  image: HTMLImageElement,
): void {
  const applySize = () => {
    const body = editor.getBody();
    if (!body) return;

    const size = calculatePastedImageSize({
      naturalWidth: image.naturalWidth,
      naturalHeight: image.naturalHeight,
      devicePixelRatio: currentDevicePixelRatio,
      maxWidth: body.clientWidth,
    });
    if (!size) return;

    image.style.width = `${size.width}px`;
    image.style.height = `${size.height}px`;
    notifyContentChanged(editor);
  };

  if (image.complete) {
    applySize();
  } else {
    image.addEventListener('load', applySize, { once: true });
  }
}

function initEditor(): void {
  console.log('[MailEditor] tinymce.init() starting');
  void tinymce.init({
    selector: '#editor',
    license_key: 'gpl',
    menubar: false,
    skin_url: 'skins/ui/oxide',
    content_css: 'skins/ui/oxide/content.css',
    plugins: 'advlist autolink lists link image code searchreplace',
    toolbar: [
      'bold italic underline strikethrough | bullist numlist | alignleft aligncenter alignright | link image | code removeformat',
    ].join(' | '),
    toolbar_mode: 'wrap',
    branding: false,
    promotion: false,
    statusbar: false,
    resize: false,
    image_dimensions: true,
    image_advtab: false,
    content_style: `
      body {
        font: 12.5px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        margin: 10px 12px;
        color: inherit;
        padding: 0;
      }
      a { color: inherit; }
      blockquote {
        margin: 8px 0;
        padding-left: 16px;
        border-left: 3px solid #ccc;
      }
      table { border-collapse: collapse; }
      td, th { border: 1px solid #ccc; padding: 4px 8px; }
      img { max-width: 100%; height: auto; }
    `,
    setup: (editor) => {
      editor.on('init', () => {
        console.log('[MailEditor] tinymce init complete, has initialHtml:', !!initialHtml);
        if (initialHtml) {
          editor.setContent(initialHtml);
          initialHtml = '';
        }
        if (currentReadOnly) {
          editor.mode.set('readonly');
        } else {
          // Move DOM focus into the editor body so the caret is active
          // without requiring the user to Alt-Tab/click away and back.
          editor.focus();
        }
        // Attach custom right-click context menu
        new MailEditorContextMenu(editor);
        postToFlutter({ type: 'mail.editor.ready' });
      });

      editor.on('input change', () => notifyContentChanged(editor));

      editor.on('PastePostProcess', (event) => {
        event.node
          .querySelectorAll('img')
          .forEach((image) => image.setAttribute(pastedImageMarker, ''));

        window.setTimeout(() => {
          const body = editor.getBody();
          if (!body) return;
          body
            .querySelectorAll<HTMLImageElement>(`img[${pastedImageMarker}]`)
            .forEach((image) => {
              image.removeAttribute(pastedImageMarker);
              normalizePastedImage(editor, image);
            });
        });

        notifyContentChanged(editor);
      });

      editor.on('keydown', (event) => {
        if ((event.metaKey || event.ctrlKey) && event.key === 'Enter') {
          event.preventDefault();
          event.stopPropagation();
          postToFlutter({ type: 'mail.editor.send' });
          return;
        }
        if (event.key.startsWith('Arrow')) {
          event.stopPropagation();
        }
      });
    },
  }).catch(reportStartupError);
}

console.log('[MailEditor] script loaded, defining MailEditor API');

window.MailEditor = {
  open(config) {
    console.log('[MailEditor] open() called, html length:', (config.html || '').length);
    initialHtml = config.html || '';
    currentReadOnly = config.readonly === true;
    if (
      typeof config.devicePixelRatio === 'number' &&
      Number.isFinite(config.devicePixelRatio) &&
      config.devicePixelRatio > 0
    ) {
      currentDevicePixelRatio = config.devicePixelRatio;
    } else {
      currentDevicePixelRatio = window.devicePixelRatio;
    }
    const editor = tinymce.activeEditor;
    if (editor) {
      console.log('[MailEditor] editor already active, reusing');
      editor.setContent(initialHtml);
      postToFlutter({ type: 'mail.editor.ready' });
    } else {
      console.log('[MailEditor] initializing new editor');
      initEditor();
    }
  },
  getHTML() {
    return tinymce.activeEditor?.getContent() || '';
  },
  getText() {
    return tinymce.activeEditor?.getContent({ format: 'text' }) || '';
  },
  setHTML(html: string) {
    const editor = tinymce.activeEditor;
    if (editor) {
      editor.setContent(html);
      postToFlutter({
        type: 'mail.editor.changed',
        html: editor.getContent(),
        plainText: editor.getContent({ format: 'text' }),
      });
    }
  },
  getSelectedText(): string {
    const editor = tinymce.activeEditor;
    if (editor) {
      return editor.selection.getContent({ format: 'text' }) || '';
    }
    return '';
  },
  getSelectedHTML(): string {
    const editor = tinymce.activeEditor;
    if (editor) {
      return editor.selection.getContent() || '';
    }
    return '';
  },
  getSelectionBookmark(): string | null {
    const editor = tinymce.activeEditor;
    if (editor && !editor.selection.isCollapsed()) {
      const bookmark = editor.selection.getBookmark(2);
      return JSON.stringify(bookmark);
    }
    return null;
  },
  moveToBookmark(bookmarkJson: string): boolean {
    const editor = tinymce.activeEditor;
    if (editor) {
      try {
        const bookmark = JSON.parse(bookmarkJson);
        editor.selection.moveToBookmark(bookmark);
        return true;
      } catch (e) {
        console.warn('[MailEditor] failed to restore bookmark:', e);
      }
    }
    return false;
  },
  replaceSelectedContent(html: string, bookmarkJson?: string): boolean {
    const editor = tinymce.activeEditor;
    if (!editor) return false;
    if (bookmarkJson) {
      try {
        const bookmark = JSON.parse(bookmarkJson);
        editor.selection.moveToBookmark(bookmark);
        editor.selection.setContent(html);
        postToFlutter({
          type: 'mail.editor.changed',
          html: editor.getContent(),
          plainText: editor.getContent({ format: 'text' }),
        });
        return true;
      } catch (e) {
        console.warn('[MailEditor] replaceSelectedContent bookmark error:', e);
      }
    }
    // Fallback: no bookmark, use current selection or insert at cursor
    if (!editor.selection.isCollapsed()) {
      editor.selection.setContent(html);
    } else {
      editor.insertContent(html);
    }
    postToFlutter({
      type: 'mail.editor.changed',
      html: editor.getContent(),
      plainText: editor.getContent({ format: 'text' }),
    });
    return true;
  },
  setReadOnly(readOnly: boolean): void {
    currentReadOnly = readOnly;
    const editor = tinymce.activeEditor;
    if (editor) {
      editor.mode.set(readOnly ? 'readonly' : 'design');
    }
  },
};
