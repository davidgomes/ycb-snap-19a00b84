// PetalDropdown hook: flip the panel above its trigger when the viewport
// leaves no room below.
//
// The markup mirrors what PetalComponents.Dropdown renders - the panel
// carries the hook and starts at display: none, and a JS.toggle reveals
// it by writing style.display. jsdom does no layout, so each spec pins the
// geometry the hook reads.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mount({ triggerTop, triggerHeight = 36, panelHeight = 200 } = {}) {
  const root = document.createElement("div");
  root.className = "pc-dropdown";
  root.innerHTML = `
    <div><button type="button">Options</button></div>
    <div id="menu" class="pc-dropdown__menu-items-wrapper-placement--left pc-dropdown__menu-items-wrapper"
      role="menu" phx-hook="PetalDropdown" style="display: none;"></div>
  `;
  document.body.appendChild(root);

  root.getBoundingClientRect = () => ({
    top: triggerTop,
    bottom: triggerTop + triggerHeight,
    left: 0,
    right: 100,
    width: 100,
    height: triggerHeight,
  });

  const el = root.querySelector("#menu");
  Object.defineProperty(el, "offsetHeight", {
    configurable: true,
    get: () => (el.style.display === "none" ? 0 : panelHeight),
  });

  const hook = Object.create(hooks.PetalDropdown);
  hook.el = el;
  hook.mounted();
  mounted.push({ hook, root });
  return { hook, el };
}

// MutationObserver callbacks run as microtasks
const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

async function open(el) {
  el.style.display = "block";
  await settle();
}

async function close(el) {
  el.style.display = "none";
  await settle();
}

afterEach(() => {
  mounted.splice(0).forEach(({ hook, root }) => {
    hook.destroyed();
    root.remove();
  });
});

describe("PetalDropdown", () => {
  it("opens downward when there is room below", async () => {
    const { el } = mount({ triggerTop: 100 });
    await open(el);
    expect(el.hasAttribute("data-pc-flip")).toBe(false);
  });

  it("flips above when the viewport leaves no room below", async () => {
    const { el } = mount({ triggerTop: window.innerHeight - 60 });
    await open(el);
    expect(el.getAttribute("data-pc-flip")).toBe("top");
  });

  it("stays below when neither side fits and below has more room", async () => {
    const { el } = mount({
      triggerTop: 200,
      panelHeight: window.innerHeight * 2,
    });
    await open(el);
    expect(el.hasAttribute("data-pc-flip")).toBe(false);
  });

  it("re-measures on every open, not just the first", async () => {
    const { el, hook } = mount({ triggerTop: window.innerHeight - 60 });
    await open(el);
    expect(el.getAttribute("data-pc-flip")).toBe("top");
    await close(el);

    el.parentElement.getBoundingClientRect = () => ({
      top: 100,
      bottom: 136,
      left: 0,
      right: 100,
      width: 100,
      height: 36,
    });
    await open(el);
    expect(el.hasAttribute("data-pc-flip")).toBe(false);
    expect(hook.wasOpen).toBe(true);
  });

  it("does not re-measure on style writes while already open", async () => {
    const { el } = mount({ triggerTop: window.innerHeight - 60 });
    await open(el);
    el.removeAttribute("data-pc-flip");
    el.style.opacity = "0.5";
    await settle();
    expect(el.hasAttribute("data-pc-flip")).toBe(false);
  });

  it("re-applies the flip after a patch drops it", async () => {
    const { el, hook } = mount({ triggerTop: window.innerHeight - 60 });
    await open(el);
    el.removeAttribute("data-pc-flip");
    hook.updated();
    expect(el.getAttribute("data-pc-flip")).toBe("top");
  });

  it("leaves a closed panel alone on patch", () => {
    const { el, hook } = mount({ triggerTop: window.innerHeight - 60 });
    hook.updated();
    expect(el.hasAttribute("data-pc-flip")).toBe(false);
  });
});
