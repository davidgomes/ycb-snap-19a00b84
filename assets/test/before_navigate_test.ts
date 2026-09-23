import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view/live_socket";
import View from "phoenix_live_view/view";
import { simulateJoinedView } from "./test_helpers";

// LiveSocket never removes its top-level window listeners, so a single
// LiveSocket is shared by all tests to avoid duplicate navigation handling.
let liveSocket: LiveSocket;
let view: View;
let preventNavigation: boolean;
let beforeNavigateEvents: CustomEvent[];
let navigateEvents: CustomEvent[];

const beforeNavigateDetails = () => beforeNavigateEvents.map((e) => e.detail);

const popstate = (path: string, state: object | null) => {
  history.replaceState(state, "", path);
  window.dispatchEvent(new PopStateEvent("popstate", { state }));
};

const nextPopState = () =>
  new Promise((resolve) =>
    window.addEventListener("popstate", resolve, { once: true }),
  );

beforeAll(() => {
  document.body.innerHTML = `
    <div id="container" data-phx-session="abc123" data-phx-main>
      <a
        id="redirect-link"
        href="/redirect-target"
        data-phx-link="redirect"
        data-phx-link-state="push"
      >Redirect</a>
      <a
        id="patch-link"
        href="/patch-target"
        data-phx-link="patch"
        data-phx-link-state="replace"
        phx-click='[["dispatch",{"event":"patch-link-clicked"}]]'
      >Patch</a>
    </div>
  `;
  liveSocket = new LiveSocket("/live", Socket);
  view = simulateJoinedView(document.getElementById("container"), liveSocket);
  liveSocket.main = view;
  liveSocket.bindTopLevelEvents();

  window.addEventListener("phx:before-navigate", (e) => {
    beforeNavigateEvents.push(e as CustomEvent);
    if (preventNavigation) {
      e.preventDefault();
    }
  });
  window.addEventListener("phx:navigate", (e) => {
    navigateEvents.push(e as CustomEvent);
  });
});

beforeEach(() => {
  jest.spyOn(liveSocket, "isConnected").mockReturnValue(true);
  history.replaceState(
    { type: "redirect", id: view.id, position: 1 },
    "",
    "/current",
  );
  liveSocket.registerNewLocation(window.location);
  liveSocket.currentHistoryPosition = 1;
  preventNavigation = false;
  beforeNavigateEvents = [];
  navigateEvents = [];
});

afterEach(() => {
  jest.restoreAllMocks();
});

afterAll(() => {
  liveSocket.destroyAllViews();
  document.body.innerHTML = "";
});

describe("phx:before-navigate for live links", () => {
  beforeEach(() => {
    jest.spyOn(liveSocket, "historyRedirect").mockImplementation(() => {});
    jest.spyOn(liveSocket, "pushHistoryPatch").mockImplementation(() => {});
  });

  test("navigates when not prevented", () => {
    const link = document.getElementById("redirect-link")!;
    link.click();

    expect(beforeNavigateDetails()).toEqual([
      {
        href: "http://localhost/redirect-target",
        patch: false,
        pop: false,
        direction: "forward",
      },
    ]);
    expect(beforeNavigateEvents[0].cancelable).toBe(true);
    expect(liveSocket.historyRedirect).toHaveBeenCalledWith(
      expect.any(MouseEvent),
      "http://localhost/redirect-target",
      "push",
      null,
      link,
    );
  });

  test("patches when not prevented", () => {
    const link = document.getElementById("patch-link")!;
    link.click();

    expect(beforeNavigateDetails()).toEqual([
      {
        href: "http://localhost/patch-target",
        patch: true,
        pop: false,
        direction: "forward",
      },
    ]);
    expect(liveSocket.pushHistoryPatch).toHaveBeenCalledWith(
      expect.any(MouseEvent),
      "http://localhost/patch-target",
      "replace",
      link,
    );
  });

  test("does not navigate when prevented", () => {
    preventNavigation = true;
    const link = document.getElementById("redirect-link")!;
    const click = new MouseEvent("click", { bubbles: true, cancelable: true });
    link.dispatchEvent(click);

    expect(beforeNavigateEvents).toHaveLength(1);
    // the browser must not perform a regular page navigation either
    expect(click.defaultPrevented).toBe(true);
    expect(liveSocket.historyRedirect).not.toHaveBeenCalled();
    expect(navigateEvents).toEqual([]);
    expect(window.location.pathname).toBe("/current");
  });

  test("still executes the phx-click of a prevented link", () => {
    preventNavigation = true;
    const execJS = jest
      .spyOn(liveSocket, "execJS")
      .mockImplementation(() => {});
    const link = document.getElementById("patch-link")!;
    link.click();

    expect(beforeNavigateEvents).toHaveLength(1);
    expect(liveSocket.pushHistoryPatch).not.toHaveBeenCalled();
    expect(execJS).toHaveBeenCalledWith(
      link,
      link.getAttribute("phx-click"),
      "click",
    );
  });
});

describe("phx:before-navigate for popstate", () => {
  beforeEach(() => {
    jest.spyOn(liveSocket, "replaceMain").mockImplementation(() => {});
  });

  test("navigates when not prevented", () => {
    const back = jest.spyOn(history, "back").mockImplementation(() => {});
    popstate("/next", { type: "redirect", id: view.id, position: 2 });

    const detail = {
      href: "http://localhost/next",
      patch: false,
      pop: true,
      direction: "forward",
    };
    expect(beforeNavigateDetails()).toEqual([detail]);
    expect(navigateEvents.map((e) => e.detail)).toEqual([detail]);
    expect(back).not.toHaveBeenCalled();
    expect(liveSocket.currentHistoryPosition).toBe(2);
    expect(liveSocket.replaceMain).toHaveBeenCalledWith(
      "http://localhost/next",
      null,
      expect.any(Function),
    );
  });

  test("moves back in history when a forward navigation is prevented", () => {
    const back = jest.spyOn(history, "back").mockImplementation(() => {});
    const forward = jest.spyOn(history, "forward").mockImplementation(() => {});
    preventNavigation = true;
    popstate("/next", { type: "redirect", id: view.id, position: 2 });

    expect(beforeNavigateDetails()).toEqual([
      {
        href: "http://localhost/next",
        patch: false,
        pop: true,
        direction: "forward",
      },
    ]);
    expect(back).toHaveBeenCalledTimes(1);
    expect(forward).not.toHaveBeenCalled();
    expect(navigateEvents).toEqual([]);
    expect(liveSocket.replaceMain).not.toHaveBeenCalled();
    expect(liveSocket.currentHistoryPosition).toBe(1);

    // the popstate caused by returning to the previous entry is ignored
    popstate("/current", { type: "redirect", id: view.id, position: 1 });
    expect(beforeNavigateEvents).toHaveLength(1);
    expect(navigateEvents).toEqual([]);
    expect(liveSocket.replaceMain).not.toHaveBeenCalled();
  });

  test("moves forward in history when a backward navigation is prevented", () => {
    const back = jest.spyOn(history, "back").mockImplementation(() => {});
    const forward = jest.spyOn(history, "forward").mockImplementation(() => {});
    preventNavigation = true;
    popstate("/previous", {
      type: "redirect",
      backType: "patch",
      id: view.id,
      position: 0,
    });

    expect(beforeNavigateDetails()).toEqual([
      {
        href: "http://localhost/previous",
        patch: true,
        pop: true,
        direction: "backward",
      },
    ]);
    expect(forward).toHaveBeenCalledTimes(1);
    expect(back).not.toHaveBeenCalled();
    expect(navigateEvents).toEqual([]);
    expect(liveSocket.replaceMain).not.toHaveBeenCalled();
    expect(liveSocket.currentHistoryPosition).toBe(1);
  });

  test("restores the current history entry when prevented", async () => {
    history.pushState(
      { type: "redirect", id: view.id, position: 2 },
      "",
      "/pushed",
    );
    liveSocket.registerNewLocation(window.location);
    liveSocket.currentHistoryPosition = 2;
    preventNavigation = true;

    history.back();
    await nextPopState();
    await nextPopState();

    expect(window.location.pathname).toBe("/pushed");
    expect(beforeNavigateDetails()).toEqual([
      {
        href: "http://localhost/current",
        patch: false,
        pop: true,
        direction: "backward",
      },
    ]);
    expect(navigateEvents).toEqual([]);
    expect(liveSocket.replaceMain).not.toHaveBeenCalled();
    expect(liveSocket.currentHistoryPosition).toBe(2);
  });
});

test("phx:before-navigate is not dispatched for server-side or programmatic navigation", () => {
  preventNavigation = true;
  jest.spyOn(liveSocket, "replaceMain").mockImplementation(() => {});
  jest.spyOn(view, "pushLinkPatch").mockImplementation(() => {});

  view.onLiveRedirect({ to: "/server-navigate", kind: "push", flash: null });
  view.onLivePatch({ to: "/server-patch", kind: "push" });
  liveSocket.js().navigate("/js-navigate");
  liveSocket.js().patch("/js-patch");

  expect(beforeNavigateEvents).toEqual([]);
  expect(liveSocket.replaceMain).toHaveBeenCalledTimes(2);
  expect(view.pushLinkPatch).toHaveBeenCalledTimes(1);
  expect(window.location.pathname).toBe("/server-patch");
});
