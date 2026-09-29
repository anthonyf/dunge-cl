'use strict';

// Runs a compiled Dunge browser runtime under Node with a minimal DOM stub,
// clicks the requested choices, and prints what was rendered as a list of
// s-expression frames for tests/parity/support.lisp to READ.
//
// Usage: node harness.js GAME.js|GAME.html CHOICE-NUMBER...
//
// Frames:
//   (:title "..." :text ("..." ...) :choices ("..." ...))  after each render
//   (:end t)                   the game ended or the scene has no choices
//   (:missing-choice N)        choice N was requested but not rendered
//   (:error "...")             the runtime threw

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

function bootRuntime(file) {
  const elements = {};
  for (const id of MOUNT_IDS) {
    elements[id] = new StubElement('div');
  }
  const storage = new Map();
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
  const [file, ...choiceArgs] = argv;
  if (!file) {
    throw new Error('Usage: node harness.js GAME.js|GAME.html CHOICE-NUMBER...');
  }
  const choices = choiceArgs.map(Number);
  const frames = [];

  function record(elements) {
    const choiceNodes = elements['dunge-choices'].children;
    const buttons = choiceNodes.filter((node) => node.tagName === 'BUTTON');
    const notes = choiceNodes
      .filter((node) => node.tagName !== 'BUTTON')
      .map((node) => node.textContent);
    if (notes.includes(GAME_ENDED_TEXT)) {
      frames.push('(:end t)');
      return { ended: true, buttons: [] };
    }
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
    const elements = bootRuntime(file);
    let state = record(elements);
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
    }
  } catch (error) {
    frames.push(sexpList([':error', sexpString(error && error.message)]));
  }
  process.stdout.write(`${sexpList(frames)}\n`);
}

main(process.argv.slice(2));
