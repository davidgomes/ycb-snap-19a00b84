// PetalDropdown places the menu LiveView.JS shows and hides.
// Open is `style.display !== "none"` — the same inline style JS.toggle writes.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mountDropdown() {
  const el = document.createElement("div");
  el.id = "account-menu";
  el.className = "pc-dropdown";
  el.innerHTML = `
    <div>
      <button type="button">Menu</button>
    </div>
    <div class="pc-dropdown__menu-items-wrapper" style="display: none;" role="menu">
      <div class="py-1"><a class="pc-dropdown__menu-item" role="menuitem">One</a></div>
    </div>`;
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

function withRects(
  dropdown,
  { controlTop, controlBottom, panelHeight, viewport = 800 },
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
    value: viewport,
    writable: true,
  });
}

// MutationObserver delivers after the current stack, same as a real browser.
function flush() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

async function open(dropdown) {
  dropdown.panel.style.display = "block";
  await flush();
}

afterEach(() => {
  mounted.splice(0).forEach(({ hook, el }) => {
    hook.destroyed();
    el.remove();
  });
  delete window.visualViewport;
});

describe("dropdown panel flip", () => {
  it("stays below when there is room", async () => {
    const dropdown = mountDropdown();
    withRects(dropdown, { controlTop: 100, controlBottom: 140, panelHeight: 200 });
    await open(dropdown);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
    expect(dropdown.panel.style.maxHeight).toBe("");
  });

  it("flips above when the viewport has no room below and more above", async () => {
    const dropdown = mountDropdown();
    withRects(dropdown, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    await open(dropdown);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("re-measures on resize while open and clears the flip when room returns", async () => {
    const dropdown = mountDropdown();
    withRects(dropdown, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    await open(dropdown);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
    withRects(dropdown, { controlTop: 100, controlBottom: 140, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("caps the menu when neither side fits, on the winning side", async () => {
    const dropdown = mountDropdown();
    // viewport 300: above the trigger 172px, below 72px, panel wants 200px
    withRects(dropdown, {
      controlTop: 180,
      controlBottom: 220,
      panelHeight: 200,
      viewport: 300,
    });
    await open(dropdown);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
    expect(dropdown.panel.style.maxHeight).toBe("172px");
    expect(dropdown.panel.style.overflowY).toBe("auto");
  });

  it("close clears the flip so the next open measures fresh", async () => {
    const dropdown = mountDropdown();
    withRects(dropdown, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    await open(dropdown);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
    dropdown.panel.style.display = "none";
    await flush();
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
    expect(dropdown.panel.style.maxHeight).toBe("");
  });
});
