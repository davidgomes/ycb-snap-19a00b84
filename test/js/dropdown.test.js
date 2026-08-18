// PetalDropdown hook: keeping an open menu inside the viewport.
//
// The panel is CSS-positioned under its trigger and toggled by
// LiveView.JS, so every spec here drives the hook the way LiveView does -
// by writing the panel's inline display - and then asks whether the flip
// and the cap match the room the trigger actually has.
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

// jsdom has no visual viewport; the hook falls back to the window when
// there is none, and the mobile spec below supplies its own.
beforeEach(() => {
  Object.defineProperty(window, "visualViewport", {
    value: undefined,
    configurable: true,
  });
  Object.defineProperty(window, "innerHeight", {
    value: 800,
    configurable: true,
    writable: true,
  });
});

afterEach(() => {
  mounted.splice(0).forEach(({ hook, wrap }) => {
    hook.destroyed();
    wrap.remove();
  });
});

// The component's markup, trimmed to what the hook reads.
function markup(id, placement) {
  return `
    <div class="pc-dropdown">
      <div>
        <button type="button" aria-haspopup="true" data-pc-dropdown-trigger>
          Open
        </button>
      </div>
      <div
        id="${id}"
        role="menu"
        class="pc-dropdown__menu-items-wrapper pc-dropdown__menu-items-wrapper-placement--${placement}"
        style="display: none;"
      >
        <div class="py-1"><button class="pc-dropdown__menu-item">Edit</button></div>
      </div>
    </div>
  `;
}

function mount({ id = "menu", placement = "left" } = {}) {
  const wrap = document.createElement("div");
  wrap.innerHTML = markup(id, placement);
  document.body.appendChild(wrap);

  const el = wrap.querySelector(`#${id}`);
  const hook = Object.create(hooks.PetalDropdown);
  hook.el = el;
  hook.mounted();
  mounted.push({ hook, wrap });

  return {
    hook,
    el,
    wrap,
    trigger: wrap.querySelector("[data-pc-dropdown-trigger]"),
  };
}

// Where the trigger sits and how tall the menu wants to be. Height comes
// off offsetHeight because the hook reads layout height, not the
// transform-scaled rect of the opening transition.
function geometry(
  { trigger, el },
  { top, height = 40, menuHeight, viewport = 800 },
) {
  trigger.getBoundingClientRect = () => ({
    top,
    bottom: top + height,
    left: 0,
    right: 160,
    width: 160,
    height,
  });
  Object.defineProperty(el, "offsetHeight", {
    configurable: true,
    value: menuHeight,
  });
  Object.defineProperty(window, "innerHeight", {
    configurable: true,
    writable: true,
    value: viewport,
  });
}

// A macrotask outlasts the microtask a MutationObserver callback runs in.
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
const frame = () =>
  new Promise((resolve) => requestAnimationFrame(() => resolve()));

// What JS.toggle writes on the panel, minus the transition classes.
const show = async (el) => {
  el.style.display = "block";
  await flush();
};
const hide = async (el) => {
  el.style.display = "none";
  await flush();
};

const flipped = (el) => el.getAttribute("data-pc-flip") === "top";

describe("PetalDropdown", () => {
  it("leaves a menu with room below alone", async () => {
    const d = mount();
    geometry(d, { top: 100, menuHeight: 200 });

    await show(d.el);

    expect(flipped(d.el)).toBe(false);
    // no cap either: a menu that fits keeps its natural height, so no
    // scrollbar appears inside a four-item menu
    expect(d.el.style.maxHeight).toBe("");
    expect(d.el.style.overflowY).toBe("");
  });

  it("flips above the trigger when the viewport leaves no room below", async () => {
    const d = mount();
    // the last row of a table: 60px under the trigger, 700 over it
    geometry(d, { top: 700, menuHeight: 200 });

    await show(d.el);

    expect(flipped(d.el)).toBe(true);
    // it fits above, so it is not also capped
    expect(d.el.style.maxHeight).toBe("");
  });

  it("stays below when below is short but above is shorter", async () => {
    const d = mount();
    // a trigger near the top of the screen: flipping would clip harder
    geometry(d, { top: 60, menuHeight: 200, viewport: 300 });

    await show(d.el);

    expect(flipped(d.el)).toBe(false);
    // 300 - 100 - 8 of room, so the menu scrolls within it
    expect(d.el.style.maxHeight).toBe("192px");
    expect(d.el.style.overflowY).toBe("auto");
  });

  it("caps the flipped menu to the room above and scrolls it", async () => {
    const d = mount();
    // 200 above, 92 below, and a menu that wants 400
    geometry(d, { top: 200, menuHeight: 400, viewport: 340 });

    await show(d.el);

    expect(flipped(d.el)).toBe(true);
    expect(d.el.style.maxHeight).toBe("192px");
    expect(d.el.style.overflowY).toBe("auto");
  });

  it("never caps taller than the room it has, however cramped", async () => {
    const d = mount();
    // a strip barely taller than the trigger itself
    geometry(d, { top: 30, height: 40, menuHeight: 300, viewport: 80 });

    await show(d.el);

    // whichever side wins, the cap stays inside the strip
    const cap = parseFloat(d.el.style.maxHeight);
    expect(cap).toBeGreaterThanOrEqual(0);
    expect(cap).toBeLessThan(80);
  });

  it("measures the flip before the first paint", async () => {
    const d = mount();
    geometry(d, { top: 700, menuHeight: 200 });

    d.el.style.display = "block";
    // one microtask, no frame: the panel must never paint downward first
    await Promise.resolve();

    expect(flipped(d.el)).toBe(true);
  });

  it("re-measures on scroll and drops the flip when room returns", async () => {
    const d = mount();
    geometry(d, { top: 700, menuHeight: 200 });
    await show(d.el);
    expect(flipped(d.el)).toBe(true);

    // the page scrolls the trigger back up the screen
    geometry(d, { top: 100, menuHeight: 200 });
    window.dispatchEvent(new Event("scroll"));
    await frame();

    expect(flipped(d.el)).toBe(false);
    expect(d.el.style.maxHeight).toBe("");
  });

  it("coalesces a scroll burst into one measurement per frame", async () => {
    const d = mount();
    geometry(d, { top: 100, menuHeight: 200 });
    await show(d.el);

    let passes = 0;
    const real = d.hook.position.bind(d.hook);
    d.hook.position = () => {
      passes += 1;
      real();
    };

    for (let i = 0; i < 10; i += 1) window.dispatchEvent(new Event("scroll"));
    expect(passes).toBe(0); // nothing runs synchronously

    await frame();
    await frame();
    expect(passes).toBe(1);
  });

  it("reads the visual viewport when a keyboard owns the bottom", async () => {
    Object.defineProperty(window, "visualViewport", {
      value: {
        offsetTop: 0,
        offsetLeft: 0,
        width: 375,
        height: 380,
        addEventListener: () => {},
        removeEventListener: () => {},
      },
      configurable: true,
    });

    const d = mount();
    // room below by the window's numbers, none inside the visible strip
    geometry(d, { top: 300, menuHeight: 200, viewport: 812 });

    await show(d.el);

    expect(flipped(d.el)).toBe(true);
  });

  it("closing clears the flip and the cap so the next open measures fresh", async () => {
    const d = mount();
    geometry(d, { top: 200, menuHeight: 400, viewport: 340 });
    await show(d.el);
    expect(flipped(d.el)).toBe(true);
    expect(d.el.style.maxHeight).not.toBe("");

    await hide(d.el);
    expect(flipped(d.el)).toBe(false);
    expect(d.el.style.maxHeight).toBe("");
    expect(d.el.style.overflowY).toBe("");
  });

  it("stops measuring once closed", async () => {
    const d = mount();
    geometry(d, { top: 100, menuHeight: 200 });
    await show(d.el);
    await hide(d.el);

    geometry(d, { top: 700, menuHeight: 200 });
    window.dispatchEvent(new Event("scroll"));
    await frame();

    expect(flipped(d.el)).toBe(false);
  });

  it("picks up a patch that closed the menu", async () => {
    const d = mount();
    geometry(d, { top: 700, menuHeight: 200 });
    await show(d.el);
    expect(flipped(d.el)).toBe(true);

    // a patch re-renders the panel with the server's display: none
    d.el.setAttribute("style", "display: none;");
    d.hook.updated();

    expect(flipped(d.el)).toBe(false);
    // and the closed panel is no longer tracking the viewport
    geometry(d, { top: 700, menuHeight: 200 });
    window.dispatchEvent(new Event("scroll"));
    await frame();
    expect(flipped(d.el)).toBe(false);
  });

  it("leaves a menu it cannot measure untouched", async () => {
    const d = mount();
    // jsdom's zeroes, or a panel with no laid-out items
    geometry(d, { top: 0, height: 0, menuHeight: 0 });

    await show(d.el);

    expect(flipped(d.el)).toBe(false);
    expect(d.el.style.maxHeight).toBe("");
  });

  it("measures a nested menu against its own trigger", async () => {
    const d = mount();
    // a dropdown inside a dropdown: the inner panel's trigger is the
    // inner one, even though the outer trigger is on the page first
    const inner = document.createElement("div");
    inner.innerHTML = markup("inner-menu", "right");
    d.el.querySelector(".py-1").appendChild(inner);

    const el = inner.querySelector("#inner-menu");
    const hook = Object.create(hooks.PetalDropdown);
    hook.el = el;
    hook.mounted();
    mounted.push({ hook, wrap: inner });

    const innerTrigger = inner.querySelector("[data-pc-dropdown-trigger]");
    expect(hook.trigger()).toBe(innerTrigger);

    geometry(
      { trigger: innerTrigger, el },
      { top: 700, menuHeight: 200, viewport: 800 },
    );
    // the outer trigger sits high on the page - reading it would keep the
    // inner menu pointing down, off the bottom of the screen
    geometry(d, { top: 100, menuHeight: 200 });

    await show(el);
    expect(flipped(el)).toBe(true);
  });
});
