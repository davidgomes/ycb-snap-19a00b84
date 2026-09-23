import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view/live_socket";
import { liveViewDOM, simulateJoinedView } from "./test_helpers";

// LiveSocket binds window listeners that cannot be removed, therefore
// all tests in this file share a single LiveSocket instance
describe("phx:before-navigate", () => {
  let liveSocket, view;
  let events: CustomEvent[] = [];
  let cancel = false;
  const onBeforeNavigate = (e: Event) => {
    events.push(e as CustomEvent);
    if (cancel) {
      e.preventDefault();
    }
  };

  beforeAll(() => {
    liveSocket = new LiveSocket("/live", Socket);
    view = simulateJoinedView(liveViewDOM(), liveSocket);
    liveSocket.main = view;
    liveSocket.isConnected = () => true;
    liveSocket.bindTopLevelEvents();
    window.addEventListener("phx:before-navigate", onBeforeNavigate);
  });

  beforeEach(() => {
    events = [];
    cancel = false;
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  afterAll(() => {
    window.removeEventListener("phx:before-navigate", onBeforeNavigate);
    liveSocket.destroyAllViews();
    document.body.innerHTML = "";
  });

  test("cancels live patches", () => {
    const pushLinkPatch = jest
      .spyOn(view, "pushLinkPatch")
      .mockImplementation(() => {});
    const e = new CustomEvent("phx:exec");

    cancel = true;
    expect(liveSocket.pushHistoryPatch(e, "/patched", "push", null)).toBe(
      false,
    );
    expect(pushLinkPatch).not.toHaveBeenCalled();
    expect(events.map((e) => e.detail)).toEqual([
      { href: "/patched", patch: true, pop: false, direction: "forward" },
    ]);

    cancel = false;
    expect(liveSocket.pushHistoryPatch(e, "/patched", "push", null)).toBe(true);
    expect(pushLinkPatch).toHaveBeenCalledTimes(1);
  });

  test("cancels live redirects", () => {
    const replaceMain = jest
      .spyOn(liveSocket, "replaceMain")
      .mockImplementation(() => {});
    const e = new CustomEvent("phx:exec");

    cancel = true;
    expect(liveSocket.historyRedirect(e, "/other", "push", null, null)).toBe(
      false,
    );
    expect(replaceMain).not.toHaveBeenCalled();
    expect(events.map((e) => e.detail)).toEqual([
      {
        href: `${window.location.origin}/other`,
        patch: false,
        pop: false,
        direction: "forward",
      },
    ]);

    cancel = false;
    expect(liveSocket.historyRedirect(e, "/other", "push", null, null)).toBe(
      true,
    );
    expect(replaceMain).toHaveBeenCalledTimes(1);
  });

  test("is not dispatched for navigation pushed by the server", () => {
    const replaceMain = jest
      .spyOn(liveSocket, "replaceMain")
      .mockImplementation(() => {});
    const historyPatch = jest
      .spyOn(liveSocket, "historyPatch")
      .mockImplementation(() => {});

    cancel = true;
    view.onLiveRedirect({ to: "/other", kind: "push", flash: null });
    view.onLivePatch({ to: "/patched", kind: "push" });

    expect(events).toEqual([]);
    expect(replaceMain).toHaveBeenCalledTimes(1);
    expect(historyPatch).toHaveBeenCalledTimes(1);
  });

  test("cancelling a live link click skips its phx-click", () => {
    const pushLinkPatch = jest
      .spyOn(view, "pushLinkPatch")
      .mockImplementation(() => {});
    const execJS = jest
      .spyOn(liveSocket, "execJS")
      .mockImplementation(() => {});
    const link = document.createElement("a");
    link.href = "/patched";
    link.setAttribute("data-phx-link", "patch");
    link.setAttribute("data-phx-link-state", "push");
    link.setAttribute("phx-click", "clicked");
    view.el.appendChild(link);

    cancel = true;
    link.click();
    expect(events.map((e) => e.detail)).toEqual([
      {
        href: `${window.location.origin}/patched`,
        patch: true,
        pop: false,
        direction: "forward",
      },
    ]);
    expect(pushLinkPatch).not.toHaveBeenCalled();
    expect(execJS).not.toHaveBeenCalled();

    cancel = false;
    link.click();
    expect(pushLinkPatch).toHaveBeenCalledTimes(1);
    expect(execJS).toHaveBeenCalledWith(link, "clicked", "click");

    link.remove();
  });

  describe("popstate", () => {
    // simulates the browser moving to another history entry
    const pop = (path: string, state: object | null) => {
      history.pushState(state, "", path);
      window.dispatchEvent(new PopStateEvent("popstate", { state }));
    };

    beforeEach(() => {
      history.replaceState(null, "", "/current");
      liveSocket.registerNewLocation(window.location);
      liveSocket.currentHistoryPosition = 2;
    });

    test("restores the previous history entry when cancelled", () => {
      const replaceMain = jest
        .spyOn(liveSocket, "replaceMain")
        .mockImplementation(() => {});
      const go = jest.spyOn(history, "go").mockImplementation(() => {});
      const onNavigate = jest.fn();
      window.addEventListener("phx:navigate", onNavigate);

      cancel = true;
      pop("/previous", { type: "redirect", position: 1 });
      window.removeEventListener("phx:navigate", onNavigate);

      expect(events.map((e) => e.detail)).toEqual([
        {
          href: `${window.location.origin}/previous`,
          patch: false,
          pop: true,
          direction: "backward",
        },
      ]);
      expect(go).toHaveBeenCalledWith(1);
      expect(onNavigate).not.toHaveBeenCalled();
      expect(replaceMain).not.toHaveBeenCalled();
      expect(liveSocket.currentHistoryPosition).toBe(2);

      // arriving back at the current entry is not a navigation
      pop("/current", { type: "redirect", position: 2 });
      expect(events).toHaveLength(1);
      expect(replaceMain).not.toHaveBeenCalled();
    });

    test("traverses back by the number of entries that were skipped", () => {
      const go = jest.spyOn(history, "go").mockImplementation(() => {});

      cancel = true;
      pop("/next", { type: "patch", position: 5 });

      expect(events.map((e) => e.detail)).toEqual([
        {
          href: `${window.location.origin}/next`,
          patch: true,
          pop: true,
          direction: "forward",
        },
      ]);
      expect(go).toHaveBeenCalledWith(-3);
    });

    test("traverses a single step when the position is unknown", () => {
      const go = jest.spyOn(history, "go").mockImplementation(() => {});

      cancel = true;
      pop("/unknown", null);

      expect(events).toHaveLength(1);
      expect(go).toHaveBeenCalledWith(1);
    });

    test("navigates when not cancelled", () => {
      const replaceMain = jest
        .spyOn(liveSocket, "replaceMain")
        .mockImplementation(() => {});
      const go = jest.spyOn(history, "go").mockImplementation(() => {});
      const onNavigate = jest.fn();
      window.addEventListener("phx:navigate", onNavigate);

      pop("/previous", { type: "redirect", position: 1 });
      window.removeEventListener("phx:navigate", onNavigate);

      expect(events).toHaveLength(1);
      expect(onNavigate).toHaveBeenCalledTimes(1);
      expect(onNavigate.mock.calls[0][0].detail).toEqual(events[0].detail);
      expect(go).not.toHaveBeenCalled();
      expect(replaceMain).toHaveBeenCalledTimes(1);
      expect(liveSocket.currentHistoryPosition).toBe(1);
    });
  });
});
