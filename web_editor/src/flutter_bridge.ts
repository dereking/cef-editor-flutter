export type FlutterMessage =
  | { type: 'mail.editor.ready' }
  | { type: 'mail.editor.changed'; html: string; plainText: string }
  | { type: 'mail.editor.send' }
  | { type: 'mail.editor.error'; error: string }
  | { type: 'mail.editor.imagePasted' };

declare global {
  interface Window {
    MailFlutter?: { postMessage(message: string): void };
  }
}

const pendingMessages: string[] = [];

function flushPending(): void {
  while (pendingMessages.length > 0) {
    const msg = pendingMessages.shift()!;
    window.MailFlutter!.postMessage(msg);
  }
}

const CONSOLE_BRIDGE_PREFIX = '__MF__:';

function createConsoleBridge(): void {
  try {
    Object.defineProperty(window, 'MailFlutter', {
      value: {
        postMessage(msg: string): void {
          console.log(CONSOLE_BRIDGE_PREFIX + msg);
        },
      },
      writable: false,
      configurable: false,
    });
    console.log('[MailEditor] console bridge created');
    flushPending();
  } catch (e) {
    // Already defined (by Dart side or native CEF), just flush
    if (typeof window.MailFlutter?.postMessage === 'function') {
      flushPending();
    }
  }
}

export function postToFlutter(message: FlutterMessage): void {
  console.log('[MailEditor] postToFlutter:', message.type);
  const json = JSON.stringify(message);
  if (window.MailFlutter) {
    if (pendingMessages.length > 0) {
      flushPending();
    }
    window.MailFlutter.postMessage(json);
  } else {
    // CEF may not have injected the channel yet. Queue the message
    // and retry when the channel becomes available.
    console.warn('[MailEditor] MailFlutter channel not available, queuing message');
    pendingMessages.push(json);
    // Poll for the channel to appear (CEF injection may be delayed)
    if (pendingMessages.length === 1) {
      const checkInterval = setInterval(() => {
        if (window.MailFlutter) {
          clearInterval(checkInterval);
          flushPending();
        }
      }, 50);
      // After 3 seconds without the native channel, fall back to console bridge
      setTimeout(() => {
        clearInterval(checkInterval);
        if (pendingMessages.length > 0 && !window.MailFlutter) {
          console.warn('[MailEditor] native channel unavailable, falling back to console bridge');
          createConsoleBridge();
          flushPending();
        }
      }, 3000);
    }
  }
}
