// PetalDropdown hook: flips the panel above its trigger when the
// viewport has no room below. jsdom does no layout, so the trigger's
// rect and the panel's height are stubbed per spec.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mount({ triggerTop, triggerBottom, panelHeight }) {
  const wrap = document.createElement("div");
  wrap.className = "pc-dropdown";
  wrap.innerHTML = `
    <div><button type="button">Open</button></div>
    <div id="menu" class="pc-dropdown__menu-items-wrapper" style="display: none;"></div>
  `;
  document.body.appendChild(wrap);

  wrap.querySelector("button").getBoundingClientRect = () => ({
    top: triggerTop,
    bottom: triggerBottom,
  });
  const el = wrap.querySelector("#menu");
  Object.defineProperty(el, "offsetHeight", { get: () => panelHeight });

  const hook = Object.create(hooks.PetalDropdown);
  hook.el = el;
  hook.mounted();
  mounted.push({ hook, wrap });
  return { hook, el };
}

const open = (el) => {
  el.style.display = "block";
  return new Promise((r) => setTimeout(r, 0));
};

describe("PetalDropdown", () => {
  afterEach(() => {
    mounted.splice(0).forEach(({ hook, wrap }) => {
      hook.destroyed();
      wrap.remove();
    });
  });

  it("opens downward when there is room below", async () => {
    const { el } = mount({ triggerTop: 100, triggerBottom: 130, panelHeight: 200 });
    await open(el);
    expect(el.hasAttribute("data-pc-flip")).toBe(false);
  });

  it("flips upward when the panel would overflow the bottom", async () => {
    const h = window.innerHeight;
    const { el } = mount({ triggerTop: h - 60, triggerBottom: h - 30, panelHeight: 200 });
    await open(el);
    expect(el.getAttribute("data-pc-flip")).toBe("top");
  });

  it("stays downward when above has even less room", async () => {
    const h = window.innerHeight;
    const { el } = mount({ triggerTop: 20, triggerBottom: 50, panelHeight: h });
    await open(el);
    expect(el.hasAttribute("data-pc-flip")).toBe(false);
  });

  it("re-decides on the next open", async () => {
    const h = window.innerHeight;
    const { el } = mount({ triggerTop: h - 60, triggerBottom: h - 30, panelHeight: 200 });
    await open(el);
    expect(el.getAttribute("data-pc-flip")).toBe("top");

    el.style.display = "none";
    await new Promise((r) => setTimeout(r, 0));
    el.parentElement.querySelector("button").getBoundingClientRect = () => ({
      top: 100,
      bottom: 130,
    });
    await open(el);
    expect(el.hasAttribute("data-pc-flip")).toBe(false);
  });
});
