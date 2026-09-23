// PetalDropdown hook: the panel flips above its trigger when the viewport
// has no room below. LiveView.JS toggles display; the hook only places.
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mount() {
  const wrap = document.createElement("div");
  wrap.className = "pc-dropdown";
  wrap.innerHTML = `
    <div><button type="button">Menu</button></div>
    <div id="menu" class="pc-dropdown__menu-items-wrapper" style="display: none;"></div>
  `;
  document.body.appendChild(wrap);

  const el = wrap.querySelector("#menu");
  const hook = Object.create(hooks.PetalDropdown);
  hook.el = el;
  hook.mounted();
  const ctx = { hook, el, wrap, button: wrap.querySelector("button") };
  mounted.push(ctx);
  return ctx;
}

function withRects(
  ctx,
  { controlTop, controlBottom, panelHeight, viewport = 800 },
) {
  ctx.button.getBoundingClientRect = () => ({
    top: controlTop,
    bottom: controlBottom,
    left: 0,
    right: 120,
    width: 120,
    height: controlBottom - controlTop,
  });
  Object.defineProperty(ctx.el, "offsetHeight", {
    configurable: true,
    value: panelHeight,
  });
  Object.defineProperty(window, "innerHeight", {
    configurable: true,
    value: viewport,
    writable: true,
  });
}

// Geometry specs show the panel the way LiveView.JS does, then sync — the
// observer specs cover the case where nobody calls sync by hand.
function show(ctx) {
  ctx.el.style.display = "block";
  ctx.hook.sync();
}

describe("dropdown panel flip", () => {
  beforeEach(() => {
    Object.defineProperty(window, "visualViewport", {
      configurable: true,
      value: undefined,
    });
  });

  afterEach(() => {
    mounted.splice(0).forEach(({ hook, wrap }) => {
      hook.destroyed();
      wrap.remove();
    });
    Object.defineProperty(window, "visualViewport", {
      configurable: true,
      value: undefined,
    });
  });

  it("stays below when there is room", () => {
    const ctx = mount();
    withRects(ctx, { controlTop: 100, controlBottom: 140, panelHeight: 200 });
    show(ctx);
    expect(ctx.el.hasAttribute("data-flip")).toBe(false);
    expect(ctx.el.style.maxHeight).toBe("");
  });

  it("flips above when the viewport has no room below and more above", () => {
    const ctx = mount();
    withRects(ctx, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    show(ctx);
    expect(ctx.el.hasAttribute("data-flip")).toBe(true);
  });

  it("stays below when both sides are equal", () => {
    const ctx = mount();
    // above = 180-8 = 172, below = 400-220-8 = 172
    withRects(ctx, {
      controlTop: 180,
      controlBottom: 220,
      panelHeight: 200,
      viewport: 400,
    });
    show(ctx);
    expect(ctx.el.hasAttribute("data-flip")).toBe(false);
    expect(ctx.el.style.maxHeight).toBe("172px");
    expect(ctx.el.style.overflowY).toBe("auto");
  });

  it("caps the panel on the winning side when neither side fits", () => {
    const ctx = mount();
    // above = 180-8 = 172, below = 300-220-8 = 72, panel wants 200
    withRects(ctx, {
      controlTop: 180,
      controlBottom: 220,
      panelHeight: 200,
      viewport: 300,
    });
    show(ctx);
    expect(ctx.el.hasAttribute("data-flip")).toBe(true);
    expect(ctx.el.style.maxHeight).toBe("172px");
    expect(ctx.el.style.overflowY).toBe("auto");
  });

  it("caps below when that side is larger, even if less than a row fits", () => {
    const ctx = mount();
    // above = 40-8 = 32, below = 100-80-8 = 12 — above wins, cap is a sliver
    withRects(ctx, {
      controlTop: 40,
      controlBottom: 80,
      panelHeight: 200,
      viewport: 100,
    });
    show(ctx);
    expect(ctx.el.hasAttribute("data-flip")).toBe(true);
    expect(ctx.el.style.maxHeight).toBe("32px");
  });

  it("re-measures on scroll and resize while open and clears the flip when room returns", () => {
    const ctx = mount();
    withRects(ctx, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    show(ctx);
    expect(ctx.el.hasAttribute("data-flip")).toBe(true);

    withRects(ctx, { controlTop: 100, controlBottom: 140, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    expect(ctx.el.hasAttribute("data-flip")).toBe(false);
    expect(ctx.el.style.maxHeight).toBe("");
    expect(ctx.el.style.overflowY).toBe("");

    withRects(ctx, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    window.dispatchEvent(new Event("scroll"));
    expect(ctx.el.hasAttribute("data-flip")).toBe(true);
  });

  it("uses the visual viewport when a keyboard shrinks it", () => {
    Object.defineProperty(window, "visualViewport", {
      configurable: true,
      value: {
        offsetTop: 0,
        offsetLeft: 0,
        width: 375,
        height: 380,
        addEventListener() {},
        removeEventListener() {},
      },
    });
    const ctx = mount();
    withRects(ctx, { controlTop: 300, controlBottom: 330, panelHeight: 200 });
    show(ctx);
    // below = 380-330-8 = 42, above = 300-8 = 292
    expect(ctx.el.hasAttribute("data-flip")).toBe(true);
  });

  it("close clears the flip so the next open measures fresh", () => {
    const ctx = mount();
    withRects(ctx, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    show(ctx);
    ctx.el.style.display = "none";
    ctx.hook.sync();
    expect(ctx.el.hasAttribute("data-flip")).toBe(false);
    expect(ctx.el.style.maxHeight).toBe("");

    withRects(ctx, { controlTop: 100, controlBottom: 140, panelHeight: 200 });
    show(ctx);
    expect(ctx.el.hasAttribute("data-flip")).toBe(false);
  });

  it("updated() re-places an open menu after a patch drops data-flip", () => {
    const ctx = mount();
    withRects(ctx, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    show(ctx);
    ctx.el.removeAttribute("data-flip");
    ctx.hook.updated();
    expect(ctx.el.hasAttribute("data-flip")).toBe(true);
  });

  it("places itself when the panel's display changes", async () => {
    const ctx = mount();
    withRects(ctx, { controlTop: 700, controlBottom: 740, panelHeight: 200 });
    ctx.el.style.display = "block";
    await vi.waitFor(() => {
      expect(ctx.el.hasAttribute("data-flip")).toBe(true);
    });

    ctx.el.style.display = "none";
    await vi.waitFor(() => {
      expect(ctx.el.hasAttribute("data-flip")).toBe(false);
    });
  });

  it("ignores a hidden panel, including one with no box yet", () => {
    const ctx = mount();
    ctx.hook.position();
    expect(ctx.el.hasAttribute("data-flip")).toBe(false);
    window.dispatchEvent(new Event("resize"));
    expect(ctx.el.hasAttribute("data-flip")).toBe(false);
  });
});
