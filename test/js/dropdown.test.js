import { afterEach, describe, expect, it } from "vitest";
import { PetalDropdown } from "../../assets/js/petal_components.js";

function mountDropdown() {
  const el = document.createElement("div");
  el.className = "pc-dropdown";
  el.innerHTML = `
    <div><button type="button">Menu</button></div>
    <div class="pc-dropdown__menu-items-wrapper" style="display: none;" role="menu">
      <div class="py-1"><a role="menuitem">One</a></div>
    </div>
  `;
  document.body.appendChild(el);
  const hook = Object.create(PetalDropdown);
  hook.el = el;
  hook.mounted();
  hook.panel = el.querySelector(".pc-dropdown__menu-items-wrapper");
  hook.button = el.querySelector("button");
  return hook;
}

function withRects(hook, { controlTop, controlBottom, panelHeight, viewport = 800 }) {
  hook.button.getBoundingClientRect = () => ({
    top: controlTop,
    bottom: controlBottom,
    left: 0,
    right: 80,
    width: 80,
    height: controlBottom - controlTop,
  });
  Object.defineProperty(hook.panel, "offsetHeight", {
    configurable: true,
    value: panelHeight,
  });
  Object.defineProperty(window, "innerHeight", {
    configurable: true,
    value: viewport,
    writable: true,
  });
}

function flush() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

afterEach(() => {
  document.body.innerHTML = "";
});

describe("dropdown panel flip", () => {
  it("stays below when there is room", async () => {
    const hook = mountDropdown();
    withRects(hook, { controlTop: 100, controlBottom: 140, panelHeight: 200 });
    hook.panel.style.display = "block";
    await flush();
    expect(hook.panel.hasAttribute("data-flip")).toBe(false);
    expect(hook.panel.style.maxHeight).toBe("");
  });

  it("flips above when the viewport has no room below and more above", async () => {
    const hook = mountDropdown();
    withRects(hook, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    hook.panel.style.display = "block";
    await flush();
    expect(hook.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("clears the flip when the menu closes", async () => {
    const hook = mountDropdown();
    withRects(hook, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    hook.panel.style.display = "block";
    await flush();
    expect(hook.panel.hasAttribute("data-flip")).toBe(true);
    hook.panel.style.display = "none";
    await flush();
    expect(hook.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("re-measures on resize while open", async () => {
    const hook = mountDropdown();
    withRects(hook, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    hook.panel.style.display = "block";
    await flush();
    expect(hook.panel.hasAttribute("data-flip")).toBe(true);
    withRects(hook, { controlTop: 100, controlBottom: 140, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    expect(hook.panel.hasAttribute("data-flip")).toBe(false);
    hook.destroyed();
  });

  it("caps the panel when neither side fits", async () => {
    const hook = mountDropdown();
    withRects(hook, {
      controlTop: 300,
      controlBottom: 340,
      panelHeight: 500,
      viewport: 600,
    });
    hook.panel.style.display = "block";
    await flush();
    expect(hook.panel.hasAttribute("data-flip")).toBe(true);
    expect(hook.panel.style.maxHeight).not.toBe("");
    expect(hook.panel.style.overflowY).toBe("auto");
  });
});
