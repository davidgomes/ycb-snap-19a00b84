// PetalDropdown hook: the panel opens below its trigger and flips above
// when the viewport leaves no room below.
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mount({ triggerTop, triggerBottom, panelHeight = 200 }) {
  const wrap = document.createElement("div");
  wrap.className = "pc-dropdown";
  wrap.innerHTML = `
    <div><button type="button">Open</button></div>
    <div id="dd" class="pc-dropdown__menu-items-wrapper" style="display: none;"></div>
  `;
  document.body.appendChild(wrap);

  const el = wrap.querySelector("#dd");
  el.previousElementSibling.getBoundingClientRect = () => ({
    top: triggerTop,
    bottom: triggerBottom,
  });
  Object.defineProperty(el, "offsetHeight", { get: () => panelHeight });

  const hook = Object.create(hooks.PetalDropdown);
  hook.el = el;
  hook.mounted();
  mounted.push({ hook, wrap });
  return { hook, el };
}

// what JS.toggle does to open the panel
async function open(el) {
  el.style.display = "block";
  await Promise.resolve();
}

describe("PetalDropdown", () => {
  afterEach(() => {
    mounted.splice(0).forEach(({ hook, wrap }) => {
      hook.destroyed();
      wrap.remove();
    });
  });

  it("opens downward when there is room below", async () => {
    window.innerHeight = 800;
    const { el } = mount({ triggerTop: 100, triggerBottom: 140 });
    await open(el);
    expect(el.hasAttribute("data-flip")).toBe(false);
  });

  it("flips upward when the viewport leaves no room below", async () => {
    window.innerHeight = 800;
    const { el } = mount({ triggerTop: 700, triggerBottom: 740 });
    await open(el);
    expect(el.hasAttribute("data-flip")).toBe(true);
  });

  it("stays down when neither side fits but below has more room", async () => {
    window.innerHeight = 300;
    const { el } = mount({ triggerTop: 100, triggerBottom: 140, panelHeight: 400 });
    await open(el);
    expect(el.hasAttribute("data-flip")).toBe(false);
  });

  it("clears the flip once the panel is hidden", async () => {
    window.innerHeight = 800;
    const { el } = mount({ triggerTop: 700, triggerBottom: 740 });
    await open(el);
    el.style.display = "none";
    await Promise.resolve();
    expect(el.hasAttribute("data-flip")).toBe(false);
  });

  it("restores the flip a patch dropped", async () => {
    window.innerHeight = 800;
    const { hook, el } = mount({ triggerTop: 700, triggerBottom: 740 });
    await open(el);
    el.removeAttribute("data-flip");
    hook.updated();
    expect(el.hasAttribute("data-flip")).toBe(true);
  });
});
