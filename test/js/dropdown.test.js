// PetalDropdown hook: which side of the trigger the menu opens on.
//
// The markup mirrors PetalComponents.Dropdown: a trigger wrapper followed
// by the menu panel, which LiveView.JS opens by writing inline display.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mount({ triggerTop, triggerBottom, panelHeight = 200 }) {
  const wrap = document.createElement("div");
  wrap.className = "pc-dropdown";
  wrap.innerHTML = `
    <div><button type="button">Options</button></div>
    <div id="menu" class="pc-dropdown__menu-items-wrapper" role="menu" style="display: none;"></div>
  `;
  document.body.appendChild(wrap);

  const trigger = wrap.firstElementChild;
  trigger.getBoundingClientRect = () => ({
    top: triggerTop,
    bottom: triggerBottom,
  });
  const el = wrap.querySelector("#menu");
  Object.defineProperty(el, "offsetHeight", {
    configurable: true,
    get: () => (el.style.display === "none" ? 0 : panelHeight),
  });

  const hook = Object.create(hooks.PetalDropdown);
  hook.el = el;
  hook.mounted();
  mounted.push({ hook, wrap });
  return { hook, el };
}

// MutationObserver callbacks run as microtasks
const flush = () => new Promise((r) => setTimeout(r, 0));

afterEach(() => {
  while (mounted.length) {
    const { hook, wrap } = mounted.pop();
    hook.destroyed();
    wrap.remove();
  }
});

describe("PetalDropdown", () => {
  it("opens downward when there is room below", async () => {
    const { el } = mount({ triggerTop: 100, triggerBottom: 140 });
    el.style.display = "block";
    await flush();
    expect(el.hasAttribute("data-flip")).toBe(false);
  });

  it("flips upward when the viewport leaves no room below", async () => {
    const h = window.innerHeight;
    const { el } = mount({ triggerTop: h - 60, triggerBottom: h - 20 });
    el.style.display = "block";
    await flush();
    expect(el.hasAttribute("data-flip")).toBe(true);
  });

  it("stays downward when above has even less room", async () => {
    const { el } = mount({
      triggerTop: 40,
      triggerBottom: 80,
      panelHeight: window.innerHeight,
    });
    el.style.display = "block";
    await flush();
    expect(el.hasAttribute("data-flip")).toBe(false);
  });

  it("re-applies the flip after a patch strips it", async () => {
    const h = window.innerHeight;
    const { hook, el } = mount({ triggerTop: h - 60, triggerBottom: h - 20 });
    el.style.display = "block";
    await flush();
    el.removeAttribute("data-flip");
    hook.updated();
    expect(el.hasAttribute("data-flip")).toBe(true);
  });
});
