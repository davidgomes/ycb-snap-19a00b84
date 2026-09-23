// PetalDropdown hook: which side of the trigger the panel opens on.
//
// LiveView.JS owns open and close. The hook settles the side on
// phx:show-start, while the panel is still display:none, so no frame
// ever paints it below a trigger that has no room beneath it.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mount({ panelHeight = 200 } = {}) {
  const wrap = document.createElement("div");
  wrap.className = "pc-dropdown";
  wrap.innerHTML = `
    <div><button type="button">Options</button></div>
    <div id="menu" class="pc-dropdown__menu-items-wrapper" role="menu" style="display: none;"></div>
  `;
  document.body.appendChild(wrap);

  const el = wrap.querySelector("#menu");
  // jsdom has no layout: report the panel's height only while it is laid
  // out, the way a browser reports 0 for a display:none element
  Object.defineProperty(el, "offsetHeight", {
    get: () => (el.style.display === "none" ? 0 : panelHeight),
  });

  const hook = Object.create(hooks.PetalDropdown);
  hook.el = el;
  hook.mounted();
  mounted.push({ hook, wrap });

  return { hook, el, wrap };
}

function stubTrigger(wrap, { top, height = 36 }) {
  wrap.getBoundingClientRect = () => ({
    top,
    bottom: top + height,
    left: 0,
    right: 120,
    width: 120,
    height,
  });
}

function stubViewport({ offsetTop = 0, height = 800 } = {}) {
  Object.defineProperty(window, "visualViewport", {
    value: { offsetTop, offsetLeft: 0, width: 375, height },
    configurable: true,
  });
}

// what JS.toggle dispatches on the panel before it reveals it
const open = (el) => el.dispatchEvent(new Event("phx:show-start"));

describe("PetalDropdown", () => {
  afterEach(() => {
    mounted.splice(0).forEach(({ hook, wrap }) => {
      hook.destroyed();
      wrap.remove();
    });
    delete window.visualViewport;
  });

  it("opens below the trigger when there is room", () => {
    stubViewport({ height: 800 });
    const { el, wrap } = mount({ panelHeight: 200 });
    stubTrigger(wrap, { top: 100 });

    open(el);

    expect(el.hasAttribute("data-pc-flip")).toBe(false);
  });

  it("flips above the trigger when the viewport leaves no room below", () => {
    stubViewport({ height: 800 });
    const { el, wrap } = mount({ panelHeight: 200 });
    // 64px under the trigger, 700px over it
    stubTrigger(wrap, { top: 700 });

    open(el);

    expect(el.getAttribute("data-pc-flip")).toBe("top");
  });

  it("counts the gap: a panel that only fits flush against the edge flips", () => {
    stubViewport({ height: 800 });
    const { el, wrap } = mount({ panelHeight: 200 });

    // exactly panel + gap below: fits
    stubTrigger(wrap, { top: 800 - 36 - 208 });
    open(el);
    expect(el.hasAttribute("data-pc-flip")).toBe(false);

    // one pixel less and the gap would push it past the viewport edge
    stubTrigger(wrap, { top: 800 - 36 - 207 });
    open(el);
    expect(el.getAttribute("data-pc-flip")).toBe("top");
  });

  it("stays below when the space above is even tighter", () => {
    // neither side fits the panel; flipping would only trade a clipped
    // bottom for a more clipped top
    stubViewport({ height: 300 });
    const { el, wrap } = mount({ panelHeight: 200 });
    stubTrigger(wrap, { top: 100 });

    open(el);

    expect(el.hasAttribute("data-pc-flip")).toBe(false);
  });

  it("measures the laid-out panel, then hands it back hidden", () => {
    stubViewport({ height: 800 });
    const { el, wrap } = mount({ panelHeight: 200 });
    stubTrigger(wrap, { top: 700 });

    open(el);

    // the flip needed the panel's real height (0 while display:none)...
    expect(el.getAttribute("data-pc-flip")).toBe("top");
    // ...but revealing it stays JS.toggle's job, transition and all
    expect(el.style.display).toBe("none");
    expect(el.style.visibility).toBe("");
  });

  it("decides afresh on every open", () => {
    stubViewport({ height: 800 });
    const { el, wrap } = mount({ panelHeight: 200 });

    stubTrigger(wrap, { top: 700 });
    open(el);
    expect(el.getAttribute("data-pc-flip")).toBe("top");

    // the page scrolled the trigger back up before the next open
    stubTrigger(wrap, { top: 100 });
    open(el);
    expect(el.hasAttribute("data-pc-flip")).toBe(false);
  });

  it("treats the space a mobile keyboard covers as no room", () => {
    // 812px screen with the keyboard up: only 380px is visible
    stubViewport({ height: 380 });
    const { el, wrap } = mount({ panelHeight: 200 });
    stubTrigger(wrap, { top: 300 });

    open(el);

    expect(el.getAttribute("data-pc-flip")).toBe("top");
  });

  it("falls back to the window height without a visual viewport", () => {
    const { el, wrap } = mount({ panelHeight: 200 });
    stubTrigger(wrap, { top: window.innerHeight - 100 });

    open(el);

    expect(el.getAttribute("data-pc-flip")).toBe("top");
  });

  it("re-asserts the flip after a patch strips it", () => {
    stubViewport({ height: 800 });
    const { hook, el, wrap } = mount({ panelHeight: 200 });
    stubTrigger(wrap, { top: 700 });
    open(el);

    // what LiveView's attribute merge does to attributes the server never rendered
    el.removeAttribute("data-pc-flip");

    hook.updated();
    expect(el.getAttribute("data-pc-flip")).toBe("top");
  });

  it("leaves a downward panel alone through a patch", () => {
    stubViewport({ height: 800 });
    const { hook, el, wrap } = mount({ panelHeight: 200 });
    stubTrigger(wrap, { top: 100 });
    open(el);

    hook.updated();
    expect(el.hasAttribute("data-pc-flip")).toBe(false);
  });

  it("stops listening once destroyed", () => {
    stubViewport({ height: 800 });
    const { hook, el, wrap } = mount({ panelHeight: 200 });
    stubTrigger(wrap, { top: 700 });

    hook.destroyed();
    open(el);

    expect(el.hasAttribute("data-pc-flip")).toBe(false);
  });
});
