// PetalDropdown hook: flip the menu above its trigger when the viewport
// leaves no room below. Open/close stays on the inline display style
// LiveView.JS writes; the hook only reacts to that.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mount() {
  const el = document.createElement("div");
  el.className = "pc-dropdown";
  el.innerHTML = `
    <div>
      <button type="button">Menu</button>
    </div>
    <div id="dropdown-menu" class="pc-dropdown__menu-items-wrapper" phx-hook="PetalDropdown" style="display: none;" role="menu">
      <div class="py-1" role="none">
        <button type="button" class="pc-dropdown__menu-item">One</button>
      </div>
    </div>`;
  document.body.appendChild(el);

  const panel = el.querySelector(".pc-dropdown__menu-items-wrapper");
  const hook = Object.create(hooks.PetalDropdown);
  hook.el = panel;
  hook.mounted();
  mounted.push({ hook, el });

  return { hook, el, panel, trigger: el.querySelector("button") };
}

function withRects(
  { trigger, panel },
  { triggerTop, triggerBottom, panelHeight, viewport = 800 },
) {
  trigger.getBoundingClientRect = () => ({
    top: triggerTop,
    bottom: triggerBottom,
    left: 0,
    right: 120,
    width: 120,
    height: triggerBottom - triggerTop,
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

// MutationObserver delivers after the current task.
async function settle() {
  await new Promise((resolve) => setTimeout(resolve, 0));
}

async function show(panel) {
  panel.style.display = "block";
  await settle();
}

afterEach(() => {
  mounted.splice(0).forEach(({ hook, el }) => {
    hook.destroyed();
    el.remove();
  });
});

describe("panel flip", () => {
  it("stays below when there is room", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      triggerTop: 100,
      triggerBottom: 140,
      panelHeight: 200,
    });
    await show(dropdown.panel);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
    expect(dropdown.panel.style.maxHeight).toBe("");
  });

  it("flips above when the viewport has no room below and more above", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      triggerTop: 700,
      triggerBottom: 740,
      panelHeight: 200,
    });
    await show(dropdown.panel);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("re-measures on resize while open and clears the flip when room returns", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      triggerTop: 700,
      triggerBottom: 740,
      panelHeight: 200,
    });
    await show(dropdown.panel);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);

    withRects(dropdown, {
      triggerTop: 100,
      triggerBottom: 140,
      panelHeight: 200,
    });
    window.dispatchEvent(new Event("resize"));
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("re-measures on scroll while open", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      triggerTop: 100,
      triggerBottom: 140,
      panelHeight: 200,
    });
    await show(dropdown.panel);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);

    withRects(dropdown, {
      triggerTop: 700,
      triggerBottom: 740,
      panelHeight: 200,
    });
    window.dispatchEvent(new Event("scroll"));
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("caps the panel when neither side fits, on the winning side", async () => {
    const dropdown = mount();
    // viewport 300: above the trigger 172px, below 52px, panel wants 200px
    withRects(dropdown, {
      triggerTop: 180,
      triggerBottom: 220,
      panelHeight: 200,
      viewport: 300,
    });
    await show(dropdown.panel);
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
    // room above = 180 - 8
    expect(dropdown.panel.style.maxHeight).toBe("172px");
    expect(dropdown.panel.style.overflowY).toBe("auto");
  });

  it("the cap clears when room returns", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      triggerTop: 180,
      triggerBottom: 220,
      panelHeight: 200,
      viewport: 300,
    });
    await show(dropdown.panel);
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
    const dropdown = mount();
    withRects(dropdown, {
      triggerTop: 700,
      triggerBottom: 740,
      panelHeight: 200,
    });
    await show(dropdown.panel);
    dropdown.panel.style.display = "none";
    await settle();
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(false);
    expect(dropdown.panel.style.maxHeight).toBe("");
  });

  it("updated() re-measures an open panel after a patch drops the flip", async () => {
    const dropdown = mount();
    withRects(dropdown, {
      triggerTop: 700,
      triggerBottom: 740,
      panelHeight: 200,
    });
    await show(dropdown.panel);
    dropdown.panel.removeAttribute("data-flip");
    dropdown.hook.updated();
    expect(dropdown.panel.hasAttribute("data-flip")).toBe(true);
  });
});
