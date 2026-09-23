// PetalDropdown hook: flip the menu above its trigger when the viewport
// has no room below. LiveView.JS owns open/close by writing the panel's
// inline display; the hook only reacts to that and to scroll/resize.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mount() {
  const el = document.createElement("div");
  el.id = "menu-root";
  el.className = "pc-dropdown";
  el.innerHTML = `
    <div>
      <button type="button" aria-haspopup="true">Menu</button>
    </div>
    <div class="pc-dropdown__menu-items-wrapper" style="display: none;">
      <div class="py-1" role="none">
        <a href="#" role="menuitem">One</a>
      </div>
    </div>
  `;
  document.body.appendChild(el);

  const hook = Object.create(hooks.PetalDropdown);
  hook.el = el;
  hook.mounted();
  mounted.push({ hook, el });

  return {
    hook,
    el,
    trigger: el.querySelector("button"),
    panel: el.querySelector(".pc-dropdown__menu-items-wrapper"),
  };
}

// MutationObserver delivers in a microtask queued ahead of this await.
async function settle() {
  await Promise.resolve();
}

function withRects(
  dropdown,
  {
    controlTop,
    controlBottom,
    panelHeight,
    viewport = 800,
    layoutHeight = viewport,
    viewportTop = 0,
  },
) {
  dropdown.trigger.getBoundingClientRect = () => ({
    top: controlTop,
    bottom: controlBottom,
    left: 0,
    right: 120,
    width: 120,
    height: controlBottom - controlTop,
  });
  Object.defineProperty(dropdown.panel, "offsetHeight", {
    configurable: true,
    value: panelHeight,
  });
  Object.defineProperty(window, "innerHeight", {
    configurable: true,
    value: layoutHeight,
    writable: true,
  });
  Object.defineProperty(window, "visualViewport", {
    configurable: true,
    value: {
      offsetTop: viewportTop,
      height: viewport,
      addEventListener() {},
      removeEventListener() {},
    },
  });
}

describe("PetalDropdown", () => {
  afterEach(() => {
    mounted.splice(0).forEach(({ hook, el }) => {
      hook.destroyed();
      el.remove();
    });
  });

  it("stays below when there is room", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      controlTop: 100,
      controlBottom: 140,
      panelHeight: 200,
    });
    dropdown.panel.style.display = "block";
    await settle();
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
    expect(dropdown.panel.style.maxHeight).toBe("");
  });

  it("flips above when the viewport has no room below and more above", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      controlTop: 700,
      controlBottom: 740,
      panelHeight: 200,
    });
    dropdown.panel.style.display = "block";
    await settle();
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
    expect(dropdown.panel.style.maxHeight).toBe("");
  });

  it("re-measures on resize while open and clears the flip when room returns", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      controlTop: 700,
      controlBottom: 740,
      panelHeight: 200,
    });
    dropdown.panel.style.display = "block";
    await settle();
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);

    withRects(dropdown, {
      controlTop: 100,
      controlBottom: 140,
      panelHeight: 200,
    });
    window.dispatchEvent(new Event("resize"));
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("re-measures on scroll while open", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      controlTop: 100,
      controlBottom: 140,
      panelHeight: 200,
    });
    dropdown.panel.style.display = "block";
    await settle();
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);

    withRects(dropdown, {
      controlTop: 700,
      controlBottom: 740,
      panelHeight: 200,
    });
    window.dispatchEvent(new Event("scroll"));
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("caps the panel when neither side fits, on the winning side", async () => {
    const dropdown = mount();
    // viewport 300: above the trigger 172px, below 72px, panel wants 200px
    withRects(dropdown, {
      controlTop: 180,
      controlBottom: 220,
      panelHeight: 200,
      viewport: 300,
    });
    dropdown.panel.style.display = "block";
    await settle();
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
    // room above = 180 - 8 = 172
    expect(dropdown.panel.style.maxHeight).toBe("172px");
    expect(dropdown.panel.style.overflowY).toBe("auto");
  });

  it("never crosses the edge even when less than a row fits", async () => {
    const dropdown = mount();
    // room above = 40 - 8 = 32: a sliver, but contained
    withRects(dropdown, {
      controlTop: 40,
      controlBottom: 80,
      panelHeight: 200,
      viewport: 100,
    });
    dropdown.panel.style.display = "block";
    await settle();
    expect(dropdown.panel.style.maxHeight).toBe("32px");
  });

  it("the cap clears when room returns", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      controlTop: 180,
      controlBottom: 220,
      panelHeight: 200,
      viewport: 300,
    });
    dropdown.panel.style.display = "block";
    await settle();
    expect(dropdown.panel.style.maxHeight).not.toBe("");

    withRects(dropdown, {
      controlTop: 100,
      controlBottom: 140,
      panelHeight: 200,
      viewport: 800,
    });
    window.dispatchEvent(new Event("resize"));
    expect(dropdown.panel.style.maxHeight).toBe("");
    expect(dropdown.panel.style.overflowY).toBe("");
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("close clears the flip so the next open measures fresh", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      controlTop: 700,
      controlBottom: 740,
      panelHeight: 200,
    });
    dropdown.panel.style.display = "block";
    await settle();
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);

    dropdown.panel.style.display = "none";
    await settle();
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
    expect(dropdown.panel.style.maxHeight).toBe("");
  });

  it("measures against the visual viewport when the keyboard has shrunk it", async () => {
    const dropdown = mount();
    // The layout viewport is tall enough to open downward. The visible
    // region ends just under the trigger, which is what a keyboard does.
    withRects(dropdown, {
      controlTop: 400,
      controlBottom: 440,
      panelHeight: 200,
      viewport: 480,
      layoutHeight: 900,
    });
    dropdown.panel.style.display = "block";
    await settle();
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("ignores scroll after close", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      controlTop: 700,
      controlBottom: 740,
      panelHeight: 200,
    });
    dropdown.panel.style.display = "block";
    await settle();
    dropdown.panel.style.display = "none";
    await settle();

    withRects(dropdown, {
      controlTop: 100,
      controlBottom: 140,
      panelHeight: 200,
    });
    window.dispatchEvent(new Event("scroll"));
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
  });
});
