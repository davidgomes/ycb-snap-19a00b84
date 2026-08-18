// PetalDropdown hook behavior.
//
// The markup built here mirrors what PetalComponents.Dropdown renders -
// test/petal/dropdown_test.exs pins that structure on the Elixir side;
// update both together if the anatomy changes. LiveView.JS owns the
// panel's show/hide, so these specs drive the inline `display` the way
// JS.toggle does and pin the placement the hook derives from it.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mountDropdown({ id = "dropdown", placement = "left" } = {}) {
  const el = document.createElement("div");
  el.id = `${id}_container`;
  el.className = "pc-dropdown";
  el.innerHTML = `
    <div>
      <button type="button" class="pc-dropdown__trigger-button--with-label">
        Options
      </button>
    </div>
    <div id="${id}" role="menu" style="display: none;"
      class="pc-dropdown__menu-items-wrapper-placement--${placement} pc-dropdown__menu-items-wrapper">
      <div class="py-1" role="none">
        <button role="menuitem" class="pc-dropdown__menu-item">One</button>
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
    trigger: el.querySelector("button"),
    panel: el.querySelector(".pc-dropdown__menu-items-wrapper"),
    // JS.toggle sets the inline display; the MutationObserver behind it is
    // async, so specs measure through the hook's own sync point.
    open() {
      this.panel.style.display = "block";
      hook.sync();
    },
    close() {
      this.panel.style.display = "none";
      hook.sync();
    },
  };
}

function withRects(d, { top, bottom, panelHeight, viewport = 800 }) {
  d.trigger.getBoundingClientRect = () => ({
    top,
    bottom,
    left: 0,
    right: 200,
    width: 200,
    height: bottom - top,
  });
  Object.defineProperty(d.panel, "offsetHeight", {
    configurable: true,
    value: panelHeight,
  });
  Object.defineProperty(window, "innerHeight", {
    configurable: true,
    writable: true,
    value: viewport,
  });
}

afterEach(() => {
  mounted.splice(0).forEach((hook) => hook.destroyed());
  document.body.innerHTML = "";
});

describe("panel flip", () => {
  it("stays below when there is room", () => {
    const d = mountDropdown();
    withRects(d, { top: 100, bottom: 140, panelHeight: 200 });
    d.open();
    expect(d.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("flips above when the viewport has no room below and more above", () => {
    const d = mountDropdown();
    withRects(d, { top: 700, bottom: 740, panelHeight: 200 });
    d.open();
    expect(d.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("stays below when neither side fits but below has the most room", () => {
    const d = mountDropdown();
    withRects(d, { top: 100, bottom: 140, panelHeight: 900 });
    d.open();
    expect(d.panel.hasAttribute("data-flip")).toBe(false);
  });

  it("re-measures on scroll while open and clears the flip when room returns", () => {
    const d = mountDropdown();
    withRects(d, { top: 700, bottom: 740, panelHeight: 200 });
    d.open();
    expect(d.panel.hasAttribute("data-flip")).toBe(true);

    withRects(d, { top: 100, bottom: 140, panelHeight: 200 });
    window.dispatchEvent(new Event("scroll"));
    expect(d.panel.hasAttribute("data-flip")).toBe(false);

    withRects(d, { top: 700, bottom: 740, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    expect(d.panel.hasAttribute("data-flip")).toBe(true);
  });

  it("close clears the flip and stops measuring", () => {
    const d = mountDropdown();
    withRects(d, { top: 700, bottom: 740, panelHeight: 200 });
    d.open();
    d.close();
    expect(d.panel.hasAttribute("data-flip")).toBe(false);

    window.dispatchEvent(new Event("resize"));
    expect(d.panel.hasAttribute("data-flip")).toBe(false);
  });
});
