// PetalDropdown hook: the menu still opens and closes through LiveView.JS.
// The hook only watches the panel's display and flips it above the trigger
// when the viewport leaves no room below.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mountDropdown() {
  const el = document.createElement("div");
  el.id = "menu";
  el.className = "pc-dropdown";
  el.setAttribute("phx-hook", "PetalDropdown");
  el.innerHTML = `
    <div>
      <button type="button">Menu</button>
    </div>
    <div class="pc-dropdown__menu-items-wrapper" id="menu-panel" style="display: none;">
      <div class="py-1" role="none">
        <button type="button" class="pc-dropdown__menu-item">One</button>
      </div>
    </div>`;
  document.body.appendChild(el);

  const hook = Object.create(hooks.PetalDropdown);
  hook.el = el;
  hook.mounted();
  mounted.push(hook);

  return {
    hook,
    el,
    trigger: el.querySelector(":scope > div > button"),
    panel: el.querySelector(".pc-dropdown__menu-items-wrapper"),
  };
}

function withRects(dropdown, { triggerTop, triggerBottom, panelHeight, viewport = 800 }) {
  dropdown.trigger.getBoundingClientRect = () => ({
    top: triggerTop,
    bottom: triggerBottom,
    left: 0,
    right: 120,
    width: 120,
    height: triggerBottom - triggerTop,
  });
  Object.defineProperty(dropdown.panel, "offsetHeight", {
    configurable: true,
    value: panelHeight,
  });
  Object.defineProperty(window, "innerHeight", {
    configurable: true,
    value: viewport,
    writable: true,
  });
}

// The hook hears LiveView.JS show/hide through a MutationObserver, which
// delivers on a microtask.
async function shown(dropdown) {
  dropdown.panel.style.display = "block";
  await new Promise((resolve) => setTimeout(resolve, 0));
}

async function hidden(dropdown) {
  dropdown.panel.style.display = "none";
  await new Promise((resolve) => setTimeout(resolve, 0));
}

afterEach(() => {
  mounted.forEach((hook) => hook.destroyed());
  mounted.length = 0;
  document.body.innerHTML = "";
});

describe("panel flip", () => {
  it("stays below when there is room", async () => {
    const dropdown = mountDropdown();
    withRects(dropdown, { triggerTop: 100, triggerBottom: 140, panelHeight: 200 });
    await shown(dropdown);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
    expect(dropdown.panel.style.maxHeight).toBe("");
  });

  it("flips above when the viewport has no room below and more above", async () => {
    const dropdown = mountDropdown();
    withRects(dropdown, { triggerTop: 700, triggerBottom: 740, panelHeight: 200 });
    await shown(dropdown);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("re-measures on scroll while open and clears the flip when room returns", async () => {
    const dropdown = mountDropdown();
    withRects(dropdown, { triggerTop: 700, triggerBottom: 740, panelHeight: 200 });
    await shown(dropdown);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);

    withRects(dropdown, { triggerTop: 100, triggerBottom: 140, panelHeight: 200 });
    window.dispatchEvent(new Event("scroll"));
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("re-measures on resize while open", async () => {
    const dropdown = mountDropdown();
    withRects(dropdown, { triggerTop: 100, triggerBottom: 140, panelHeight: 200 });
    await shown(dropdown);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);

    withRects(dropdown, { triggerTop: 700, triggerBottom: 740, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("caps the panel when neither side fits, on the winning side", async () => {
    const dropdown = mountDropdown();
    // viewport 300: above the trigger 172px, below 52px, panel wants 200px
    withRects(dropdown, {
      triggerTop: 180,
      triggerBottom: 220,
      panelHeight: 200,
      viewport: 300,
    });
    await shown(dropdown);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
    // room above = 180 - 8 = 172
    expect(dropdown.panel.style.maxHeight).toBe("172px");
    expect(dropdown.panel.style.overflowY).toBe("auto");
  });

  it("the cap clears when room returns", async () => {
    const dropdown = mountDropdown();
    withRects(dropdown, {
      triggerTop: 180,
      triggerBottom: 220,
      panelHeight: 200,
      viewport: 300,
    });
    await shown(dropdown);
    expect(dropdown.panel.style.maxHeight).not.toBe("");

    withRects(dropdown, {
      triggerTop: 100,
      triggerBottom: 140,
      panelHeight: 200,
      viewport: 800,
    });
    window.dispatchEvent(new Event("resize"));
    expect(dropdown.panel.style.maxHeight).toBe("");
    expect(dropdown.panel.style.overflowY).toBe("");
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("close clears the flip so the next open measures fresh", async () => {
    const dropdown = mountDropdown();
    withRects(dropdown, { triggerTop: 700, triggerBottom: 740, panelHeight: 200 });
    await shown(dropdown);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
    await hidden(dropdown);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
    expect(dropdown.panel.style.maxHeight).toBe("");
  });

  it("does not flip a closed menu when the viewport changes", async () => {
    const dropdown = mountDropdown();
    withRects(dropdown, { triggerTop: 700, triggerBottom: 740, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    window.dispatchEvent(new Event("scroll"));
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
  });
});
