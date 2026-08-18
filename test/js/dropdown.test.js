// PetalDropdown hook: keeping a menu inside the viewport.
//
// The panel is CSS-anchored under its trigger, so every spec here is
// about the trigger that sits too low for the menu it opens - the case
// where the anchor points off the bottom of the screen.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function build({ placement = "left", display = "none" } = {}) {
  const wrap = document.createElement("div");
  wrap.innerHTML = `
    <div class="pc-dropdown">
      <div><button type="button">Open options</button></div>
      <div
        id="menu"
        role="menu"
        style="display: ${display};"
        class="pc-dropdown__menu-items-wrapper pc-dropdown__menu-items-wrapper-placement--${placement}"
      ></div>
    </div>
  `;
  document.body.appendChild(wrap);

  return {
    wrap,
    el: wrap.querySelector("#menu"),
    container: wrap.querySelector(".pc-dropdown"),
  };
}

function attach(parts) {
  const hook = Object.create(hooks.PetalDropdown);
  hook.el = parts.el;
  hook.mounted();
  mounted.push({ hook, wrap: parts.wrap });

  return hook;
}

function mount(opts = {}) {
  const parts = build(opts);

  return { ...parts, hook: attach(parts) };
}

// jsdom lays nothing out, and the trigger's box plus the menu's natural
// height are the only two numbers the hook decides on - so specs supply
// them. No visualViewport in jsdom either, so the window is the box.
function withRects(
  { container, el },
  { triggerTop, triggerHeight = 36, menuHeight, viewport = 768 },
) {
  container.getBoundingClientRect = () => ({
    top: triggerTop,
    bottom: triggerTop + triggerHeight,
    left: 0,
    right: 200,
    width: 200,
    height: triggerHeight,
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

// The trigger's JS.toggle writes the inline display; the hook hears about
// it through a MutationObserver, whose callback lands a microtask later.
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

async function toggle(el, display) {
  el.style.display = display;
  await flush();
}

describe("PetalDropdown", () => {
  afterEach(() => {
    mounted.splice(0).forEach(({ hook, wrap }) => {
      hook.destroyed();
      wrap.remove();
    });
  });

  it("leaves a menu below its trigger when there is room", async () => {
    const parts = mount();
    withRects(parts, { triggerTop: 100, menuHeight: 200 });

    await toggle(parts.el, "block");

    expect(parts.el.hasAttribute("data-pc-flip")).toBe(false);
    // nothing to cap, so the panel keeps its natural height
    expect(parts.el.style.maxHeight).toBe("");
    expect(parts.el.style.overflowY).toBe("");
  });

  it("flips above the trigger when the menu does not fit below", async () => {
    const parts = mount();
    // a row action near the foot of the page: 16px below, 684 above
    withRects(parts, { triggerTop: 700, menuHeight: 200 });

    await toggle(parts.el, "block");

    expect(parts.el.getAttribute("data-pc-flip")).toBe("top");
    // the whole menu fits above, so it is not capped as well as flipped
    expect(parts.el.style.maxHeight).toBe("");
  });

  it("never flips into even less room", async () => {
    const parts = mount();
    // trigger at the top of a short viewport: below is tight, above is
    // nothing at all - flipping would put every item off-screen
    withRects(parts, { triggerTop: 10, menuHeight: 400, viewport: 300 });

    await toggle(parts.el, "block");

    expect(parts.el.hasAttribute("data-pc-flip")).toBe(false);
    // and the menu scrolls within the room it does have: 300 - 46 - 16
    expect(parts.el.style.maxHeight).toBe("238px");
    expect(parts.el.style.overflowY).toBe("auto");
  });

  it("caps the menu to the winning side when neither side fits", async () => {
    const parts = mount();
    // 48px below the trigger, 184 above, menu wants 400
    withRects(parts, { triggerTop: 200, menuHeight: 400, viewport: 300 });

    await toggle(parts.el, "block");

    expect(parts.el.getAttribute("data-pc-flip")).toBe("top");
    expect(parts.el.style.maxHeight).toBe("184px");
    expect(parts.el.style.overflowY).toBe("auto");
  });

  it("caps at zero rather than a negative height", async () => {
    const parts = mount();
    // a viewport strip shorter than the trigger itself
    withRects(parts, { triggerTop: 0, menuHeight: 200, viewport: 40 });

    await toggle(parts.el, "block");

    expect(parts.el.style.maxHeight).toBe("0px");
  });

  it("clears the flip on close so the next open measures fresh", async () => {
    const parts = mount();
    withRects(parts, { triggerTop: 700, menuHeight: 200 });

    await toggle(parts.el, "block");
    expect(parts.el.getAttribute("data-pc-flip")).toBe("top");

    await toggle(parts.el, "none");
    expect(parts.el.hasAttribute("data-pc-flip")).toBe(false);
    expect(parts.el.style.maxHeight).toBe("");

    // the page has scrolled by the time it opens again
    withRects(parts, { triggerTop: 100, menuHeight: 200 });
    await toggle(parts.el, "block");
    expect(parts.el.hasAttribute("data-pc-flip")).toBe(false);
  });

  it("re-measures on resize while the menu is open", async () => {
    const parts = mount();
    withRects(parts, { triggerTop: 700, menuHeight: 200 });

    await toggle(parts.el, "block");
    expect(parts.el.getAttribute("data-pc-flip")).toBe("top");

    // rotating the phone gives the menu its room below back
    withRects(parts, { triggerTop: 700, menuHeight: 200, viewport: 1200 });
    window.dispatchEvent(new Event("resize"));

    expect(parts.el.hasAttribute("data-pc-flip")).toBe(false);
  });

  it("re-asserts the flip after a patch strips it", async () => {
    const parts = mount();
    withRects(parts, { triggerTop: 700, menuHeight: 200 });

    await toggle(parts.el, "block");

    // what LiveView's merge does to an attribute the server never renders
    parts.el.removeAttribute("data-pc-flip");
    parts.hook.updated();

    expect(parts.el.getAttribute("data-pc-flip")).toBe("top");
  });

  it("does not measure a closed menu", () => {
    const parts = mount();
    withRects(parts, { triggerTop: 700, menuHeight: 200 });

    parts.hook.updated();

    expect(parts.el.hasAttribute("data-pc-flip")).toBe(false);
  });

  it("measures a menu that was already open when it mounted", () => {
    const parts = build({ display: "block" });
    withRects(parts, { triggerTop: 700, menuHeight: 200 });

    attach(parts);

    expect(parts.el.getAttribute("data-pc-flip")).toBe("top");
  });

  it("stops measuring once destroyed", async () => {
    const parts = mount();
    withRects(parts, { triggerTop: 700, menuHeight: 200 });

    parts.hook.destroyed();
    mounted.splice(
      mounted.findIndex((m) => m.hook === parts.hook),
      1,
    );

    await toggle(parts.el, "block");
    window.dispatchEvent(new Event("resize"));

    expect(parts.el.hasAttribute("data-pc-flip")).toBe(false);
    parts.wrap.remove();
  });
});
