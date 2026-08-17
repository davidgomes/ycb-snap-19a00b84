// PetalCheckboxIndeterminate hook: sets the DOM-only `indeterminate`
// property from the data-indeterminate attribute the data_table tri-state
// "select all" header checkbox renders (there is no HTML attribute for
// indeterminate, only a JS property).
import { afterEach, describe, expect, it } from "vitest";

import hooks from "../../assets/js/petal_components.js";

const mounted = [];

function mount(indeterminate) {
  const el = document.createElement("input");
  el.type = "checkbox";
  if (indeterminate !== undefined) el.dataset.indeterminate = indeterminate;
  document.body.appendChild(el);

  const hook = Object.create(hooks.PetalCheckboxIndeterminate);
  hook.el = el;
  hook.mounted();
  mounted.push({ hook, el });

  return { hook, el };
}

describe("PetalCheckboxIndeterminate", () => {
  afterEach(() => {
    mounted.splice(0).forEach(({ el }) => el.remove());
  });

  it("sets indeterminate true when the data attribute reads \"true\"", () => {
    const { el } = mount("true");
    expect(el.indeterminate).toBe(true);
  });

  it("leaves indeterminate false when the data attribute reads \"false\"", () => {
    const { el } = mount("false");
    expect(el.indeterminate).toBe(false);
  });

  it("defaults to false when the data attribute is absent", () => {
    const { el } = mount();
    expect(el.indeterminate).toBe(false);
  });

  it("re-syncs on updated() - a re-rendered header keeps its tri-state", () => {
    const { hook, el } = mount("false");
    expect(el.indeterminate).toBe(false);

    el.dataset.indeterminate = "true";
    hook.updated();
    expect(el.indeterminate).toBe(true);

    el.dataset.indeterminate = "false";
    hook.updated();
    expect(el.indeterminate).toBe(false);
  });
});
