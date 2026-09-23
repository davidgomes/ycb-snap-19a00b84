// PetalDropdown hook: picks the side the panel opens on.
//
// The markup mirrors what PetalComponents.Dropdown renders. Open and close
// stay LiveView.JS's job, so these specs drive the panel the way JS.toggle
// and JS.hide do - by writing its inline display - and let the hook's
// observer pick that up.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mount({ display = "none", placement = "left" } = {}) {
  const root = document.createElement("div");
  root.className = "pc-dropdown";
  root.innerHTML = `
    <div>
      <button type="button" class="pc-dropdown__trigger-button--with-label" aria-haspopup="true">Account</button>
    </div>
    <div id="menu" phx-hook="PetalDropdown" role="menu" style="display: ${display};"
      class="pc-dropdown__menu-items-wrapper-placement--${placement} pc-dropdown__menu-items-wrapper">
      <div class="py-1" role="none">
        <button type="button" class="pc-dropdown__menu-item" role="menuitem">Sign out</button>
      </div>
    </div>
  `;
  document.body.appendChild(root);

  const panel = root.querySelector("#menu");
  const hook = Object.create(hooks.PetalDropdown);
  hook.el = panel;
  const d = { hook, root, panel, destroyed: false };
  mounted.push(d);
  return d;
}

function start(d) {
  d.hook.mounted();
  return d;
}

function destroy(d) {
  if (d.destroyed) return;
  d.destroyed = true;
  d.hook.destroyed();
}

// the .pc-dropdown root is the box the panel hangs from
function withRects(d, { rootTop, rootBottom, panelHeight, viewport = 800 }) {
  d.root.getBoundingClientRect = () => ({
    top: rootTop,
    bottom: rootBottom,
    left: 0,
    right: 120,
    width: 120,
    height: rootBottom - rootTop,
  });
  Object.defineProperty(d.panel, "offsetHeight", {
    configurable: true,
    value: panelHeight,
  });
  Object.defineProperty(window, "innerHeight", {
    configurable: true,
    value: viewport,
    writable: true,
  });
}

// mutation observers deliver on a microtask
const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

async function open(d) {
  d.panel.style.display = "block";
  await settle();
}

async function close(d) {
  d.panel.style.display = "none";
  await settle();
}

const flipped = (d) => d.panel.hasAttribute("data-flip");

afterEach(() => {
  mounted.splice(0).forEach((d) => {
    destroy(d);
    d.root.remove();
  });
});

describe("PetalDropdown", () => {
  it("opens downward when there is room below", async () => {
    const d = start(mount());
    withRects(d, { rootTop: 100, rootBottom: 140, panelHeight: 200 });
    await open(d);
    expect(flipped(d)).toBe(false);
  });

  it("flips upward when the viewport has no room below and more above", async () => {
    // the sidebar user menu: avatar pinned to the bottom of the screen
    const d = start(mount());
    withRects(d, { rootTop: 740, rootBottom: 780, panelHeight: 200 });
    await open(d);
    expect(flipped(d)).toBe(true);
  });

  it("stays downward when it doesn't fit below but above has no more room", async () => {
    // viewport 300: 122px below, 122px above, panel wants 200px
    const d = start(mount());
    withRects(d, {
      rootTop: 130,
      rootBottom: 170,
      panelHeight: 200,
      viewport: 300,
    });
    await open(d);
    expect(flipped(d)).toBe(false);
  });

  it("measures an already-open panel on mount", () => {
    const d = mount({ display: "block" });
    withRects(d, { rootTop: 740, rootBottom: 780, panelHeight: 200 });
    start(d);
    expect(flipped(d)).toBe(true);
  });

  it("leaves the panel alone while it is hidden", async () => {
    const d = start(mount());
    withRects(d, { rootTop: 740, rootBottom: 780, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    window.dispatchEvent(new Event("scroll"));
    await settle();
    expect(flipped(d)).toBe(false);
  });

  it("keeps the default side when nothing has been laid out", async () => {
    // jsdom's own zeros - no numbers, no case for flipping
    const d = start(mount());
    await open(d);
    expect(flipped(d)).toBe(false);
  });

  it("re-measures on resize while open and clears the flip when room returns", async () => {
    const d = start(mount());
    withRects(d, { rootTop: 740, rootBottom: 780, panelHeight: 200 });
    await open(d);
    expect(flipped(d)).toBe(true);

    withRects(d, { rootTop: 100, rootBottom: 140, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    expect(flipped(d)).toBe(false);
  });

  it("re-measures when a nested scroller moves the trigger", async () => {
    // scroll doesn't bubble - a scrolling sidebar only reaches a
    // capture-phase listener on window
    const scroller = document.createElement("div");
    document.body.appendChild(scroller);
    const d = start(mount());
    withRects(d, { rootTop: 100, rootBottom: 140, panelHeight: 200 });
    await open(d);
    expect(flipped(d)).toBe(false);

    withRects(d, { rootTop: 740, rootBottom: 780, panelHeight: 200 });
    scroller.dispatchEvent(new Event("scroll"));
    expect(flipped(d)).toBe(true);
    scroller.remove();
  });

  it("close clears the flip and stops re-measuring", async () => {
    const d = start(mount());
    withRects(d, { rootTop: 740, rootBottom: 780, panelHeight: 200 });
    await open(d);
    expect(flipped(d)).toBe(true);

    await close(d);
    expect(flipped(d)).toBe(false);

    window.dispatchEvent(new Event("resize"));
    expect(flipped(d)).toBe(false);
  });

  it("the next open measures fresh", async () => {
    const d = start(mount());
    withRects(d, { rootTop: 740, rootBottom: 780, panelHeight: 200 });
    await open(d);
    await close(d);

    withRects(d, { rootTop: 100, rootBottom: 140, panelHeight: 200 });
    await open(d);
    expect(flipped(d)).toBe(false);
  });

  it("re-asserts the flip after a patch strips it", async () => {
    const d = start(mount());
    withRects(d, { rootTop: 740, rootBottom: 780, panelHeight: 200 });
    await open(d);

    // what LiveView's attribute merge does to an attribute the server never rendered
    d.panel.removeAttribute("data-flip");
    d.hook.updated();
    expect(flipped(d)).toBe(true);
  });

  it("a patch while closed doesn't flip the hidden panel", () => {
    const d = start(mount());
    withRects(d, { rootTop: 740, rootBottom: 780, panelHeight: 200 });
    d.hook.updated();
    expect(flipped(d)).toBe(false);
  });

  it("destroyed() stops observing and listening", async () => {
    const d = start(mount());
    withRects(d, { rootTop: 100, rootBottom: 140, panelHeight: 200 });
    await open(d);
    destroy(d);

    withRects(d, { rootTop: 740, rootBottom: 780, panelHeight: 200 });
    window.dispatchEvent(new Event("resize"));
    await close(d);
    await open(d);
    expect(flipped(d)).toBe(false);
  });
});
