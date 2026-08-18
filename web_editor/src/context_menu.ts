/**
 * Custom right-click context menu for the mail editor.
 *
 * Intercepts the native `contextmenu` event on TinyMCE's editor body and
 * presents a styled popup menu with common email-editing actions.
 */

interface MenuItem {
  label: string;
  shortcut?: string;
  action: () => void;
  disabled?: boolean;
  separator?: 'before' | 'after';
}

export class MailEditorContextMenu {
  private editor: any; // tinymce.Editor
  private menuEl: HTMLDivElement | null = null;

  constructor(editor: any) {
    this.editor = editor;
    this.attach();
  }

  // ── lifecycle ──────────────────────────────────────────────────────

  private attached = false;

  private attach(): void {
    if (this.attached) return;

    const editor = this.editor;

    const attachListeners = () => {
      if (this.attached) return;
      this.attached = true;

      const body = editor.getBody();
      if (body) {
        body.addEventListener('contextmenu', this.handleBodyContextMenu);
      }

      // Also attach to the editor container so right-clicking the
      // toolbar / chrome area shows the menu as well.
      const container = editor.getContainer();
      if (container) {
        container.addEventListener('contextmenu', this.handleContainerContextMenu);
      }
    };

    if (editor.initialized) {
      attachListeners();
    } else {
      editor.on('init', attachListeners);
    }

    // Close on outside interactions
    document.addEventListener('click', this.hide, true);
    document.addEventListener('contextmenu', this.hide, true);
    document.addEventListener('keydown', this.handleKeyDown);
    window.addEventListener('scroll', this.hide, true);
  }

  destroy(): void {
    this.hide();

    const editor = this.editor;
    const body = editor.getBody();
    if (body) {
      body.removeEventListener('contextmenu', this.handleBodyContextMenu);
    }
    const container = editor.getContainer();
    if (container) {
      container.removeEventListener('contextmenu', this.handleContainerContextMenu);
    }

    document.removeEventListener('click', this.hide, true);
    document.removeEventListener('contextmenu', this.hide, true);
    document.removeEventListener('keydown', this.handleKeyDown);
    window.removeEventListener('scroll', this.hide, true);
  }

  private handleBodyContextMenu = (e: MouseEvent): void => {
    e.preventDefault();
    e.stopPropagation();
    this.show(e);
  };

  private handleContainerContextMenu = (e: MouseEvent): void => {
    // Only show context menu if the click target is part of the
    // editor chrome (not the content area — already handled above).
    const target = e.target as HTMLElement;
    if (target.closest('.tox-editor-header') || target.closest('.tox-toolbar')) {
      e.preventDefault();
      e.stopPropagation();
      this.show(e);
    }
  };

  private handleKeyDown = (e: KeyboardEvent): void => {
    if (e.key === 'Escape') this.hide();
  };

  // ── menu items ─────────────────────────────────────────────────────

  private menuItems(): MenuItem[] {
    const editor = this.editor;
    const hasSelection = !editor.selection.isCollapsed();

    return [
      // ── undo / redo ──
      {
        label: '撤销',
        shortcut: 'Ctrl+Z',
        action: () => editor.undoManager.undo(),
        disabled: !editor.undoManager.hasUndo(),
        separator: 'after',
      },
      {
        label: '重做',
        shortcut: 'Ctrl+Y',
        action: () => editor.undoManager.redo(),
        disabled: !editor.undoManager.hasRedo(),
        separator: 'after',
      },

      // ── clipboard ──
      {
        label: '剪切',
        shortcut: 'Ctrl+X',
        action: () => editor.execCommand('cut'),
        disabled: !hasSelection,
      },
      {
        label: '复制',
        shortcut: 'Ctrl+C',
        action: () => editor.execCommand('copy'),
        disabled: !hasSelection,
      },
      {
        label: '粘贴',
        shortcut: 'Ctrl+V',
        action: () => editor.execCommand('paste'),
        separator: 'after',
      },

      // ── selection ──
      {
        label: '全选',
        shortcut: 'Ctrl+A',
        action: () => editor.execCommand('selectall'),
        separator: 'after',
      },

      // ── inline formatting ──
      {
        label: '加粗',
        shortcut: 'Ctrl+B',
        action: () => editor.execCommand('bold'),
      },
      {
        label: '斜体',
        shortcut: 'Ctrl+I',
        action: () => editor.execCommand('italic'),
      },
      {
        label: '下划线',
        shortcut: 'Ctrl+U',
        action: () => editor.execCommand('underline'),
      },
      {
        label: '删除线',
        action: () => editor.execCommand('strikethrough'),
        separator: 'after',
      },

      // ── block formatting ──
      {
        label: '无序列表',
        action: () => editor.execCommand('InsertUnorderedList'),
      },
      {
        label: '有序列表',
        action: () => editor.execCommand('InsertOrderedList'),
        separator: 'after',
      },

      // ── insert ──
      {
        label: '插入链接',
        shortcut: 'Ctrl+K',
        action: () => editor.execCommand('link'),
      },
      {
        label: '插入图片',
        action: () => {
          editor.execCommand('mceImage');
        },
        separator: 'after',
      },

      // ── utilities ──
      {
        label: '清除格式',
        action: () => editor.execCommand('removeformat'),
        disabled: !hasSelection,
      },
      {
        label: '查看源码',
        action: () => editor.execCommand('code'),
      },
    ];
  }

  // ── render ─────────────────────────────────────────────────────────

  private show(e: MouseEvent): void {
    this.hide();

    const menu = this.buildMenu();
    document.body.appendChild(menu);
    this.menuEl = menu;

    // Position near the click but keep the menu on-screen.
    const rect = menu.getBoundingClientRect();
    let left = e.pageX;
    let top = e.pageY;

    if (left + rect.width > window.innerWidth - 4) {
      left = window.innerWidth - rect.width - 4;
    }
    if (top + rect.height > window.innerHeight - 4) {
      top = window.innerHeight - rect.height - 4;
    }
    if (left < 0) left = 0;
    if (top < 0) top = 0;

    menu.style.left = `${left}px`;
    menu.style.top = `${top}px`;
  }

  private buildMenu(): HTMLDivElement {
    const menu = document.createElement('div');
    menu.className = 'mail-context-menu';

    // Inline styles so we don't need a separate CSS file.
    // Uses currentColor / transparent gaps so it blends with editor
    // chrome without hardcoding a specific theme.
    menu.style.cssText = [
      'position:fixed',
      'z-index:2147483647' /* TinyMCE's z-index is ~65535; fly above it */,
      'min-width:208px',
      'background:#fff',
      'border:1px solid #d9d9d9',
      'border-radius:8px',
      'box-shadow:0 6px 20px rgba(0,0,0,.14)',
      'padding:4px 0',
      'font:13px/1.4 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif',
      'color:#1a1a1a',
      'user-select:none',
    ].join(';');

    const items = this.menuItems();

    for (const item of items) {
      if (item.separator === 'before') {
        menu.appendChild(this.buildDivider());
      }
      menu.appendChild(this.buildItem(item));
      if (item.separator === 'after') {
        menu.appendChild(this.buildDivider());
      }
    }

    // Prevent mousedown on the menu from immediately closing it (the
    // global document click listener fires on the same event loop).
    menu.addEventListener('mousedown', (ev) => ev.stopPropagation());

    return menu;
  }

  private buildDivider(): HTMLDivElement {
    const el = document.createElement('div');
    el.style.cssText = 'height:1px;background:#e8e8e8;margin:4px 8px';
    return el;
  }

  private buildItem(item: MenuItem): HTMLDivElement {
    const el = document.createElement('div');
    el.style.cssText = [
      'padding:6px 12px',
      'display:flex',
      'align-items:center',
      'gap:24px',
      `cursor:${item.disabled ? 'default' : 'pointer'}`,
      `opacity:${item.disabled ? '0.35' : '1'}`,
    ].join(';');

    // Label
    const label = document.createElement('span');
    label.style.flex = '1';
    label.textContent = item.label;
    el.appendChild(label);

    // Shortcut hint
    if (item.shortcut) {
      const hint = document.createElement('span');
      hint.style.cssText = 'opacity:.45;font-size:11.5px';
      hint.textContent = item.shortcut;
      el.appendChild(hint);
    }

    if (!item.disabled) {
      el.addEventListener('mouseenter', () => {
        el.style.backgroundColor = '#f3f3f3';
      });
      el.addEventListener('mouseleave', () => {
        el.style.backgroundColor = '';
      });
      el.addEventListener('click', (ev) => {
        ev.preventDefault();
        ev.stopPropagation();
        item.action();
        this.hide();
        this.editor.focus();
      });
    }

    return el;
  }

  private hide(): void {
    if (this.menuEl) {
      this.menuEl.remove();
      this.menuEl = null;
    }
  }
}
