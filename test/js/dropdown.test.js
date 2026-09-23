// PetalDropdown hook behavior.
//
// The markup mirrors what PetalComponents.Dropdown renders: a .pc-dropdown
// container holding the trigger and the options panel the hook sits on.
// LiveView.JS owns open/close by writing the panel's inline display, so
// these specs drive the hook the same way.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mountDropdown() {
  const container = document.createElement("div");
  container.className = "pc-dropdown";
  container.innerHTML = `
    <div><button type="button">Menu</button></div>
    <div id="dd" class="pc-dropdown__menu-items-wrapper" role="menu"
      phx-hook="PetalDropdown" style="display: none;">
      <div class="py-1" role="none"></div>
    </div>`;
  document.body.appendChild(container);

  const panel = container.querySelector("#dd");
  const hook = Object.create(hooks.PetalDropdown);
  hook.el = panel;
  hook.mounted();
  mounted.push({ hook, container });
  return { hook, container, panel };
}

function withRects(d, { top, bottom, panelHeight, viewport = 800 }) {
  d.container.getBoundingClientRect = () => ({
    top,
    bottom,
    left: 0,
    right: 100,
    width: 100,
    height: bottom - top,
  });
  Object.defineProperty(d.panel, "offsetHeight", {
    configurable: true,
    value: panelHeight,
  });
  Object.defineProperty(window, "innerHeight", {
    configurable: true,
    value: viewport,
    writable: true,
  });
}

// MutationObserver callbacks are microtasks
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

async function open(d) {
  d.panel.style.display = "block";
  await flush();
}

async function close(d) {
  d.panel.style.display = "none";
  await flush();
}

afterEach(() => {
  mounted.splice(0).forEach(({ hook, container }) => {
    hook.destroyed();
    container.remove();
  });
});

describe("panel flip", () => {
  it("stays below when there is room", async () => {
    const d = mountDropdown();
    withRects(d, { top: 100, bottom: 140, panelHeight: 200 });
    await open(d);
    expect(d.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("flips above when the viewport has no room below and more above", async () => {
    const d = mountDropdown();
    withRects(d, { top: 700, bottom: 740, panelHeight: 200 });
    await open(d);
    expect(d.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("stays below when there is even less room above", async () => {
    const d = mountDropdown();
    withRects(d, {
      top: 40,
      bottom: 80,
      panelHeight: 200,
      viewport: 150,
    });
    await open(d);
    expect(d.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("does nothing while closed", async () => {
    const d = mountDropdown();
    withRects(d, { top: 700, bottom: 740, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    expect(d.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("re-measures on resize while open and clears the flip when room returns", async () => {
    const d = mountDropdown();
    withRects(d, { top: 700, bottom: 740, panelHeight: 200 });
    await open(d);
    expect(d.panel.hasAttribute("data-flip")).toBe(true);
    withRects(d, { top: 100, bottom: 140, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    expect(d.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("clears the flip on close and re-decides on the next open", async () => {
    const d = mountDropdown();
    withRects(d, { top: 700, bottom: 740, panelHeight: 200 });
    await open(d);
    await close(d);
    expect(d.panel.hasAttribute("data-flip")).toBe(false);
    withRects(d, { top: 100, bottom: 140, panelHeight: 200 });
    window.dispatchEvent(new Event("scroll"));
    expect(d.panel.hasAttribute("data-flip")).toBe(false);
    await open(d);
    expect(d.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("restores the flip after a patch strips it", async () => {
    const d = mountDropdown();
    withRects(d, { top: 700, bottom: 740, panelHeight: 200 });
    await open(d);
    d.panel.removeAttribute("data-flip");
    d.hook.updated();
    expect(d.panel.hasAttribute("data-flip")).toBe(true);
  });
});
