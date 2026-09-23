// PetalDropdown hook: flip the panel above its trigger when the viewport
// leaves no room below. LiveView.JS opens/closes the panel by writing its
// inline display, so these specs drive the hook the same way.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];
const VIEW_H = 800;
const PANEL_H = 200;

function mount({ triggerTop, viewH = VIEW_H }) {
  window.innerHeight = viewH;
  const root = document.createElement("div");
  root.className = "pc-dropdown";
  root.innerHTML = `
    <div><button type="button">Options</button></div>
    <div id="dd" class="pc-dropdown__menu-items-wrapper" role="menu" style="display: none;"></div>
  `;
  document.body.appendChild(root);

  // jsdom does no layout: hand the hook the geometry a browser would
  root.getBoundingClientRect = () => ({
    top: triggerTop,
    bottom: triggerTop + 36,
    left: 0,
    right: 100,
    width: 100,
    height: 36,
  });
  const el = root.querySelector("#dd");
  Object.defineProperty(el, "offsetHeight", { get: () => PANEL_H });

  const hook = Object.create(hooks.PetalDropdown);
  hook.el = el;
  hook.mounted();
  mounted.push({ hook, root });
  return { hook, el, root };
}

// MutationObserver callbacks run as a microtask
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

async function open(el) {
  el.style.display = "block";
  await flush();
}

async function close(el) {
  el.style.display = "none";
  await flush();
}

describe("PetalDropdown", () => {
  afterEach(() => {
    mounted.splice(0).forEach(({ hook, root }) => {
      hook.destroyed();
      root.remove();
    });
  });

  it("opens downward when there is room below", async () => {
    const { el } = mount({ triggerTop: 100 });
    await open(el);
    expect(el.hasAttribute("data-flip")).toBe(false);
  });

  it("flips upward when the viewport leaves no room below", async () => {
    const { el } = mount({ triggerTop: VIEW_H - 80 });
    await open(el);
    expect(el.hasAttribute("data-flip")).toBe(true);
  });

  it("stays below when neither side fits but below has more room", async () => {
    const { el } = mount({ triggerTop: 60, viewH: 300 });
    await open(el);
    expect(el.hasAttribute("data-flip")).toBe(false);
  });

  it("clears the flip once the panel is hidden", async () => {
    const { el } = mount({ triggerTop: VIEW_H - 80 });
    await open(el);
    expect(el.hasAttribute("data-flip")).toBe(true);
    await close(el);
    expect(el.hasAttribute("data-flip")).toBe(false);
  });

  it("re-asserts the flip after a patch strips it from an open panel", async () => {
    const { hook, el } = mount({ triggerTop: VIEW_H - 80 });
    await open(el);

    // what LiveView's attribute merge does to attributes the server never rendered
    el.removeAttribute("data-flip");
    hook.updated();
    expect(el.hasAttribute("data-flip")).toBe(true);
  });

  it("re-evaluates on resize while open", async () => {
    const { el } = mount({ triggerTop: 500 });
    await open(el);
    expect(el.hasAttribute("data-flip")).toBe(false);

    window.innerHeight = 600;
    window.dispatchEvent(new Event("resize"));
    expect(el.hasAttribute("data-flip")).toBe(true);
  });

  it("ignores resize once closed", async () => {
    const { el } = mount({ triggerTop: 500 });
    await open(el);
    await close(el);

    window.innerHeight = 600;
    window.dispatchEvent(new Event("resize"));
    expect(el.hasAttribute("data-flip")).toBe(false);
  });
});
