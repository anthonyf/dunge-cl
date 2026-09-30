'use strict';

// Runs a compiled Dunge browser runtime under Node with a minimal DOM stub,
// clicks the requested choices, and prints what was rendered as a list of
// s-expression frames for tests/parity/support.lisp to READ.
//
// Usage: node harness.js [--reload-after=N] GAME.js|GAME.html CHOICE-NUMBER...
//
// --reload-after=N reboots the page after the Nth choice, keeping its
// localStorage, as a browser refresh would. A faithful restore renders exactly
// what was shown before the reload and adds no frame; otherwise the reloaded
// render is recorded as (:reload-mismatch FRAME).
//
// Frames:
//   (:title "..." :text ("..." ...) :choices ("..." ...))  after each render
//   (:end t)                   the game ended or the scene has no choices
//   (:end t :text ("..." ...)) the game ended and showed final messages
//   (:missing-choice N)        choice N was requested but not rendered
//   (:error "...")             the runtime threw
//   (:reload-mismatch FRAME)   the page rendered FRAME after a reload instead
//                              of what it showed before

const fs = require('fs');
const vm = require('vm');

const MOUNT_IDS = [
  'dunge-controls',
  'dunge-new-game',
  'dunge-scene',
  'dunge-scene-title',
  'dunge-scene-body',
  'dunge-choices',
];

const GAME_ENDED_TEXT = 'The game has ended.';

class StubElement {
  constructor(tagName) {
    this.tagName = String(tagName).toUpperCase();
    this.children = [];
    this.listeners = {};
    this.className = '';
    this.id = '';
    this.type = '';
    this.disabled = false;
    this.ownText = '';
  }

  appendChild(child) {
    this.children.push(child);
    return child;
  }

  addEventListener(type, listener) {
    (this.listeners[type] ||= []).push(listener);
  }

  set innerHTML(value) {
    if (value !== '') {
      throw new Error('The parity DOM stub only supports clearing innerHTML.');
    }
    this.children = [];
    this.ownText = '';
  }

  get innerHTML() {
    throw new Error('The parity DOM stub does not support reading innerHTML.');
  }

  set textContent(value) {
    this.children = [];
    this.ownText = value == null ? '' : String(value);
  }

  get textContent() {
    return this.ownText + this.children.map((child) => child.textContent).join('');
  }

  click() {
    for (const listener of this.listeners.click || []) {
      listener();
    }
  }
}

function loadScript(file) {
  const source = fs.readFileSync(file, 'utf8');
  if (!/\.html?$/i.test(file)) {
    return source;
  }
  const match = source.match(/<script>([\s\S]*)<\/script>/);
  if (!match) {
    throw new Error(`No <script> element found in ${file}.`);
  }
  return match[1];
}

function sexpString(value) {
  return `"${String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

function sexpList(items) {
  return `(${items.join(' ')})`;
}

function bootRuntime(file, storage) {
  const elements = {};
  for (const id of MOUNT_IDS) {
    elements[id] = new StubElement('div');
  }
  const documentListeners = {};
  const context = {
    console,
    document: {
      getElementById: (id) => elements[id] || null,
      createElement: (tagName) => new StubElement(tagName),
      addEventListener: (type, listener) => {
        (documentListeners[type] ||= []).push(listener);
      },
    },
    location: { search: '', hash: '' },
    localStorage: {
      getItem: (key) => (storage.has(key) ? storage.get(key) : null),
      setItem: (key, value) => {
        storage.set(key, String(value));
      },
      removeItem: (key) => {
        storage.delete(key);
      },
    },
    addEventListener() {},
  };
  context.window = context;
  vm.createContext(context);
  vm.runInContext(loadScript(file), context, { filename: file });
  for (const listener of documentListeners.DOMContentLoaded || []) {
    listener();
  }
  return elements;
}

function main(argv) {
  let reloadAfter = null;
  const reloadOption = argv.length > 0 && argv[0].match(/^--reload-after=(\d+)$/);
  if (reloadOption) {
    reloadAfter = Number(reloadOption[1]);
    argv = argv.slice(1);
  }
  const [file, ...choiceArgs] = argv;
  if (!file) {
    throw new Error('Usage: node harness.js [--reload-after=N] GAME.js|GAME.html CHOICE-NUMBER...');
  }
  const choices = choiceArgs.map(Number);
  const frames = [];
  // Body paragraphs shown by the last recorded frame. Ending the game appends
  // any final messages after them without re-rendering the scene.
  let shownBodyLength = 0;

  function record(elements) {
    const body = elements['dunge-scene-body'].children;
    const choiceNodes = elements['dunge-choices'].children;
    const buttons = choiceNodes.filter((node) => node.tagName === 'BUTTON');
    const notes = choiceNodes
      .filter((node) => node.tagName !== 'BUTTON')
      .map((node) => node.textContent);
    if (notes.includes(GAME_ENDED_TEXT)) {
      const finalText = body.slice(shownBodyLength).map((node) => sexpString(node.textContent));
      frames.push(finalText.length > 0
        ? sexpList([':end', 't', ':text', sexpList(finalText)])
        : '(:end t)');
      return { ended: true, buttons: [] };
    }
    shownBodyLength = body.length;
    frames.push(sexpList([
      ':title', sexpString(elements['dunge-scene-title'].textContent),
      ':text', sexpList(elements['dunge-scene-body'].children
        .map((node) => sexpString(node.textContent))),
      ':choices', sexpList(buttons.map((button) => sexpString(button.textContent))),
    ]));
    if (buttons.length === 0) {
      frames.push('(:end t)');
      return { ended: true, buttons };
    }
    return { ended: false, buttons };
  }

  try {
    const storage = new Map();
    let elements = bootRuntime(file, storage);
    let state = record(elements);
    let clicks = 0;
    for (const choice of choices) {
      if (state.ended) {
        break;
      }
      const button = state.buttons[choice - 1];
      if (!button) {
        frames.push(sexpList([':missing-choice', String(choice)]));
        break;
      }
      button.click();
      state = record(elements);
      clicks += 1;
      if (clicks === reloadAfter && !state.ended) {
        const shown = frames.pop();
        elements = bootRuntime(file, storage);
        state = record(elements);
        const reloaded = frames.pop();
        frames.push(reloaded === shown
          ? shown
          : sexpList([':reload-mismatch', reloaded]));
      }
    }
  } catch (error) {
    frames.push(sexpList([':error', sexpString(error && error.message)]));
  }
  process.stdout.write(`${sexpList(frames)}\n`);
}

main(process.argv.slice(2));
