import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view/live_socket";
import { clone } from "phoenix_live_view/utils";
import { liveViewDOM, simulateJoinedView } from "./test_helpers";

const content = `
  <a id="redirect" href="/redirect" data-phx-link="redirect" data-phx-link-state="push">Redirect</a>
  <a id="patch" href="/patch?page=2" data-phx-link="patch" data-phx-link-state="push">Patch</a>
  <a id="with-click" href="/redirect" data-phx-link="redirect" data-phx-link-state="push" phx-click='[["push",{"event":"clicked"}]]'>With click</a>
`;

describe("phx:before-navigate", () => {
  let liveSocket;
  let view;
  let beforeNavigateEvents: CustomEvent[];
  let navigateEvents: CustomEvent[];
  let cancel: boolean;

  const onBeforeNavigate = (e: Event) => {
    beforeNavigateEvents.push(e as CustomEvent);
    if (cancel) {
      e.preventDefault();
    }
  };
  const onNavigate = (e: Event) => navigateEvents.push(e as CustomEvent);

  const pop = (href: string, state: object | null) => {
    window.history.pushState(state, "", href);
    window.dispatchEvent(new PopStateEvent("popstate", { state }));
  };

  beforeAll(() => {
    // a single socket for all tests, as the bound window listeners are never removed
    liveSocket = new LiveSocket("/live", Socket);
    liveSocket.bindNav();
  });

  beforeEach(() => {
    window.history.replaceState(null, "", "/");
    liveSocket.currentLocation = clone(window.location);
    liveSocket.currentHistoryPosition = 1;
    view = simulateJoinedView(liveViewDOM(content), liveSocket);
    liveSocket.main = view;

    jest.spyOn(liveSocket, "isConnected").mockReturnValue(true);
    jest.spyOn(liveSocket, "historyRedirect").mockImplementation(() => {});
    jest.spyOn(liveSocket, "pushHistoryPatch").mockImplementation(() => {});
    jest.spyOn(liveSocket, "replaceMain").mockImplementation(() => {});
    jest.spyOn(liveSocket, "execJS").mockImplementation(() => {});
    jest.spyOn(view, "pushLinkPatch").mockImplementation(() => {});
    jest.spyOn(window.history, "go").mockImplementation(() => {});

    beforeNavigateEvents = [];
    navigateEvents = [];
    cancel = false;
    window.addEventListener("phx:before-navigate", onBeforeNavigate);
    window.addEventListener("phx:navigate", onNavigate);
  });

  afterEach(() => {
    window.removeEventListener("phx:before-navigate", onBeforeNavigate);
    window.removeEventListener("phx:navigate", onNavigate);
    jest.restoreAllMocks();
    liveSocket.destroyAllViews();
  });

  describe("live links", () => {
    test("is dispatched before navigating", () => {
      document.getElementById("redirect")!.click();

      expect(beforeNavigateEvents).toHaveLength(1);
      expect(beforeNavigateEvents[0].cancelable).toBe(true);
      expect(beforeNavigateEvents[0].detail).toEqual({
        href: "http://localhost/redirect",
        patch: false,
        pop: false,
        direction: "forward",
      });
      expect(liveSocket.historyRedirect).toHaveBeenCalledTimes(1);
    });

    test("is dispatched before patching", () => {
      document.getElementById("patch")!.click();

      expect(beforeNavigateEvents).toHaveLength(1);
      expect(beforeNavigateEvents[0].detail).toEqual({
        href: "http://localhost/patch?page=2",
        patch: true,
        pop: false,
        direction: "forward",
      });
      expect(liveSocket.pushHistoryPatch).toHaveBeenCalledTimes(1);
    });

    test("cancels navigation and patching when prevented", () => {
      cancel = true;
      const clicks: MouseEvent[] = [];
      document.addEventListener("click", (e) => clicks.push(e), {
        capture: true,
        once: true,
      });

      document.getElementById("redirect")!.click();
      document.getElementById("patch")!.click();

      expect(beforeNavigateEvents).toHaveLength(2);
      expect(liveSocket.historyRedirect).not.toHaveBeenCalled();
      expect(liveSocket.pushHistoryPatch).not.toHaveBeenCalled();
      // the browser must not follow the link either
      expect(clicks[0].defaultPrevented).toBe(true);
    });

    test("does not execute the link's phx-click when prevented", () => {
      cancel = true;
      document.getElementById("with-click")!.click();
      expect(liveSocket.execJS).not.toHaveBeenCalled();

      cancel = false;
      document.getElementById("with-click")!.click();
      expect(liveSocket.historyRedirect).toHaveBeenCalledTimes(1);
      expect(liveSocket.execJS).toHaveBeenCalledTimes(1);
    });

    test("is not dispatched for regular links", () => {
      const link = document.createElement("a");
      link.href = "#regular";
      view.el.appendChild(link);
      link.click();

      expect(beforeNavigateEvents).toHaveLength(0);
    });
  });

  describe("popstate", () => {
    test("is dispatched before navigating back", () => {
      pop("/previous", { type: "redirect", id: view.id, position: 0 });

      expect(beforeNavigateEvents).toHaveLength(1);
      expect(beforeNavigateEvents[0].cancelable).toBe(true);
      expect(beforeNavigateEvents[0].detail).toEqual({
        href: "http://localhost/previous",
        patch: false,
        pop: true,
        direction: "backward",
      });
      expect(navigateEvents.map((e) => e.detail)).toEqual([
        beforeNavigateEvents[0].detail,
      ]);
      expect(liveSocket.replaceMain).toHaveBeenCalledTimes(1);
      expect(liveSocket.currentHistoryPosition).toBe(0);
      expect(window.history.go).not.toHaveBeenCalled();
    });

    test("is dispatched before patching forward", () => {
      pop("/next?page=2", { type: "patch", id: view.id, position: 2 });

      expect(beforeNavigateEvents).toHaveLength(1);
      expect(beforeNavigateEvents[0].detail).toEqual({
        href: "http://localhost/next?page=2",
        patch: true,
        pop: true,
        direction: "forward",
      });
      expect(view.pushLinkPatch).toHaveBeenCalledTimes(1);
      expect(liveSocket.currentHistoryPosition).toBe(2);
    });

    test("goes back to the previous entry when a backward navigation is prevented", () => {
      cancel = true;
      pop("/previous", { type: "redirect", id: view.id, position: 0 });

      expect(beforeNavigateEvents).toHaveLength(1);
      expect(window.history.go).toHaveBeenCalledWith(1);
      expect(navigateEvents).toHaveLength(0);
      expect(liveSocket.replaceMain).not.toHaveBeenCalled();
      expect(view.pushLinkPatch).not.toHaveBeenCalled();
      expect(liveSocket.currentHistoryPosition).toBe(1);

      // the popstate caused by restoring the previous entry is ignored
      pop("/", { type: "patch", id: view.id, position: 1 });
      expect(beforeNavigateEvents).toHaveLength(1);
      expect(navigateEvents).toHaveLength(0);
      expect(liveSocket.replaceMain).not.toHaveBeenCalled();
      expect(view.pushLinkPatch).not.toHaveBeenCalled();
    });

    test("goes back to the previous entry when a forward navigation is prevented", () => {
      cancel = true;
      pop("/next?page=2", { type: "patch", id: view.id, position: 2 });

      expect(window.history.go).toHaveBeenCalledWith(-1);
      expect(navigateEvents).toHaveLength(0);
      expect(view.pushLinkPatch).not.toHaveBeenCalled();
      expect(liveSocket.currentHistoryPosition).toBe(1);
    });

    test("is not dispatched when the location does not change", () => {
      pop("/#hash", null);

      expect(beforeNavigateEvents).toHaveLength(0);
      expect(navigateEvents).toHaveLength(0);
    });
  });

  test("is not dispatched for server-side navigation", () => {
    liveSocket.historyRedirect.mockRestore();
    view.onLiveRedirect({ to: "/redirect", kind: "push", flash: null });
    expect(liveSocket.replaceMain).toHaveBeenCalledTimes(1);
    view.onLivePatch({ to: "/patch?page=2", kind: "push" });

    expect(beforeNavigateEvents).toHaveLength(0);
  });
});
