// PetalDropdown only flips an already-open panel. LiveView.JS owns
// show/hide (inline display); the hook watches that style.
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mountDropdown() {
  const el = document.createElement("div");
  el.className = "pc-dropdown";
  el.innerHTML = `
    <div>
      <button type="button">Menu</button>
    </div>
    <div class="pc-dropdown__menu-items-wrapper" style="display: none;"></div>
  `;
  document.body.appendChild(el);
  const hook = Object.create(hooks.PetalDropdown);
  hook.el = el;
  hook.mounted();
  mounted.push(hook);
  return {
    hook,
    trigger: el.querySelector("button"),
    panel: el.querySelector(".pc-dropdown__menu-items-wrapper"),
  };
}

function withRects(c, { controlTop, controlBottom, panelHeight, viewport = 800 }) {
  c.trigger.getBoundingClientRect = () => ({
    top: controlTop,
    bottom: controlBottom,
    left: 0,
    right: 120,
    width: 120,
    height: controlBottom - controlTop,
  });
  Object.defineProperty(c.panel, "offsetHeight", {
    configurable: true,
    value: panelHeight,
  });
  Object.defineProperty(window, "innerHeight", {
    configurable: true,
    value: viewport,
    writable: true,
  });
}

async function show(c) {
  c.panel.style.display = "block";
  await Promise.resolve();
}

async function hide(c) {
  c.panel.style.display = "none";
  await Promise.resolve();
}

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  mounted.splice(0).forEach((hook) => hook.destroyed());
});

describe("dropdown panel flip", () => {
  it("stays below when there is room", async () => {
    const c = mountDropdown();
    withRects(c, { controlTop: 100, controlBottom: 140, panelHeight: 200 });
    await show(c);
    expect(c.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("flips above when the viewport has no room below and more above", async () => {
    const c = mountDropdown();
    withRects(c, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    await show(c);
    expect(c.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("re-measures on resize while open and clears the flip when room returns", async () => {
    const c = mountDropdown();
    withRects(c, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    await show(c);
    expect(c.panel.hasAttribute("data-flip")).toBe(true);
    withRects(c, { controlTop: 100, controlBottom: 140, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    expect(c.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("close clears the flip so the next open measures fresh", async () => {
    const c = mountDropdown();
    withRects(c, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    await show(c);
    expect(c.panel.hasAttribute("data-flip")).toBe(true);
    await hide(c);
    expect(c.panel.hasAttribute("data-flip")).toBe(false);
    withRects(c, { controlTop: 100, controlBottom: 140, panelHeight: 200 });
    await show(c);
    expect(c.panel.hasAttribute("data-flip")).toBe(false);
  });
});
