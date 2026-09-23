// PetalDropdown hook: picks the side the dropdown panel opens on.
//
// LiveView's JS.toggle owns showing and hiding; it dispatches
// phx:show-start while the panel is still display:none and phx:hide-end
// once it is hidden again. These specs drive those two events directly.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];
const innerHeight = Object.getOwnPropertyDescriptor(window, "innerHeight");

function mount({ placement = "left" } = {}) {
  const wrap = document.createElement("div");
  wrap.className = "pc-dropdown";
  wrap.innerHTML = `
    <div><button type="button">Actions</button></div>
    <div
      id="menu"
      role="menu"
      style="display: none;"
      class="pc-dropdown__menu-items-wrapper-placement--${placement} pc-dropdown__menu-items-wrapper"
    ></div>
  `;
  document.body.appendChild(wrap);

  const el = wrap.querySelector("#menu");
  const hook = Object.create(hooks.PetalDropdown);
  hook.el = el;
  hook.mounted();
  mounted.push({ hook, wrap });

  return { hook, el, wrap };
}

// jsdom has no layout. The panel only reports a height while it is laid
// out, the way a real display:none box reports 0.
function withRects(
  { el, wrap },
  { triggerTop, triggerBottom, panelHeight, viewport = 800 },
) {
  wrap.getBoundingClientRect = () => ({
    top: triggerTop,
    bottom: triggerBottom,
    left: 0,
    right: 120,
    width: 120,
    height: triggerBottom - triggerTop,
  });
  Object.defineProperty(el, "offsetHeight", {
    configurable: true,
    get: () => (el.style.display === "none" ? 0 : panelHeight),
  });
  Object.defineProperty(window, "innerHeight", {
    configurable: true,
    value: viewport,
    writable: true,
  });
}

const open = (el) => el.dispatchEvent(new Event("phx:show-start"));
const closed = (el) => el.dispatchEvent(new Event("phx:hide-end"));

describe("PetalDropdown", () => {
  afterEach(() => {
    mounted.splice(0).forEach(({ hook, wrap }) => {
      hook.destroyed();
      wrap.remove();
    });
    Object.defineProperty(window, "innerHeight", innerHeight);
    delete window.visualViewport;
  });

  it("stays below the trigger when there is room", () => {
    const d = mount();
    withRects(d, { triggerTop: 100, triggerBottom: 140, panelHeight: 200 });
    open(d.el);
    expect(d.el.hasAttribute("data-flip")).toBe(false);
  });

  it("flips above when the viewport has no room below and more above", () => {
    const d = mount();
    withRects(d, { triggerTop: 700, triggerBottom: 740, panelHeight: 200 });
    open(d.el);
    expect(d.el.hasAttribute("data-flip")).toBe(true);
  });

  it("counts the panel's gap against the room below", () => {
    const d = mount();
    // 204px below: the 200px panel fits, its 8px margin does not
    withRects(d, { triggerTop: 556, triggerBottom: 596, panelHeight: 200 });
    open(d.el);
    expect(d.el.hasAttribute("data-flip")).toBe(true);
  });

  it("stays below when it overflows there but above has even less room", () => {
    const d = mount();
    // viewport 300: 120px above the trigger, 140px below, panel wants 200px
    withRects(d, {
      triggerTop: 120,
      triggerBottom: 160,
      panelHeight: 200,
      viewport: 300,
    });
    open(d.el);
    expect(d.el.hasAttribute("data-flip")).toBe(false);
  });

  it("measures the panel while it is still hidden and leaves it hidden", () => {
    const d = mount();
    withRects(d, { triggerTop: 700, triggerBottom: 740, panelHeight: 200 });
    expect(d.el.style.display).toBe("none");
    open(d.el);
    expect(d.el.hasAttribute("data-flip")).toBe(true);
    // JS.toggle sets the real display value itself, a frame later
    expect(d.el.style.display).toBe("none");
  });

  it("works for both placements", () => {
    const d = mount({ placement: "right" });
    withRects(d, { triggerTop: 700, triggerBottom: 740, panelHeight: 200 });
    open(d.el);
    expect(d.el.hasAttribute("data-flip")).toBe(true);
  });

  it("measures against the visible viewport when a keyboard shrinks it", () => {
    const d = mount();
    // fits in the 800px layout viewport, not in the 400px visible one
    withRects(d, { triggerTop: 300, triggerBottom: 340, panelHeight: 200 });
    window.visualViewport = { offsetTop: 0, height: 400 };
    open(d.el);
    expect(d.el.hasAttribute("data-flip")).toBe(true);
  });

  it("clears the flip once hidden and re-measures on the next open", () => {
    const d = mount();
    withRects(d, { triggerTop: 700, triggerBottom: 740, panelHeight: 200 });
    open(d.el);
    expect(d.el.hasAttribute("data-flip")).toBe(true);

    closed(d.el);
    expect(d.el.hasAttribute("data-flip")).toBe(false);

    // the page scrolled: the trigger now has room below
    withRects(d, { triggerTop: 100, triggerBottom: 140, panelHeight: 200 });
    open(d.el);
    expect(d.el.hasAttribute("data-flip")).toBe(false);
  });

  it("re-asserts the flip after a patch strips it", () => {
    const d = mount();
    withRects(d, { triggerTop: 700, triggerBottom: 740, panelHeight: 200 });
    open(d.el);

    // what LiveView's attribute merge does to one the server never rendered
    d.el.removeAttribute("data-flip");
    d.hook.updated();
    expect(d.el.hasAttribute("data-flip")).toBe(true);
  });

  it("does not move a panel that opened below when a patch lands", () => {
    const d = mount();
    withRects(d, { triggerTop: 100, triggerBottom: 140, panelHeight: 200 });
    open(d.el);
    // the page scrolled while open, then a patch arrived
    withRects(d, { triggerTop: 700, triggerBottom: 740, panelHeight: 200 });
    d.hook.updated();
    expect(d.el.hasAttribute("data-flip")).toBe(false);
  });

  it("stops listening once destroyed", () => {
    const d = mount();
    withRects(d, { triggerTop: 700, triggerBottom: 740, panelHeight: 200 });
    d.hook.destroyed();
    open(d.el);
    expect(d.el.hasAttribute("data-flip")).toBe(false);
  });
});
