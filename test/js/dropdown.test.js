// Dropdown panel: LiveView.JS toggles display; PetalDropdown flips the
// menu above the trigger when the viewport has no room below.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mount() {
  const wrap = document.createElement("div");
  wrap.className = "pc-dropdown";
  wrap.innerHTML = `
    <div><button type="button">Menu</button></div>
    <div id="menu" class="pc-dropdown__menu-items-wrapper" style="display: none;"></div>
  `;
  document.body.appendChild(wrap);
  const panel = wrap.querySelector("#menu");
  const button = wrap.querySelector("button");
  const hook = Object.create(hooks.PetalDropdown);
  hook.el = panel;
  hook.mounted();
  mounted.push({ hook, wrap });
  return { hook, panel, button, wrap };
}

function withRects(
  { button, panel },
  { controlTop, controlBottom, panelHeight, viewport = 800 },
) {
  button.getBoundingClientRect = () => ({
    top: controlTop,
    bottom: controlBottom,
    left: 0,
    right: 80,
    width: 80,
    height: controlBottom - controlTop,
  });
  Object.defineProperty(panel, "offsetHeight", {
    configurable: true,
    value: panelHeight,
  });
  Object.defineProperty(window, "innerHeight", {
    configurable: true,
    value: viewport,
    writable: true,
  });
}

function show(panel) {
  panel.style.display = "block";
}

// MutationObserver notifies on a microtask.
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("dropdown panel flip", () => {
  afterEach(() => {
    mounted.splice(0).forEach(({ hook, wrap }) => {
      hook.destroyed();
      wrap.remove();
    });
  });

  it("stays below when there is room", async () => {
    const c = mount();
    withRects(c, { controlTop: 100, controlBottom: 140, panelHeight: 200 });
    show(c.panel);
    await flush();
    expect(c.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("flips above when the viewport has no room below and more above", async () => {
    const c = mount();
    withRects(c, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    show(c.panel);
    await flush();
    expect(c.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("re-measures on resize while open and clears the flip when room returns", async () => {
    const c = mount();
    withRects(c, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    show(c.panel);
    await flush();
    expect(c.panel.hasAttribute("data-flip")).toBe(true);
    withRects(c, { controlTop: 100, controlBottom: 140, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    expect(c.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("hiding the menu clears the flip", async () => {
    const c = mount();
    withRects(c, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    show(c.panel);
    await flush();
    expect(c.panel.hasAttribute("data-flip")).toBe(true);
    c.panel.style.display = "none";
    await flush();
    expect(c.panel.hasAttribute("data-flip")).toBe(false);
  });
});
