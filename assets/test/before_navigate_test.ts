import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view/live_socket";

describe("phx:before-navigate", () => {
  let liveSocket;

  beforeAll(() => {
    liveSocket = new LiveSocket("/live", Socket);
    liveSocket.bindNav();
    liveSocket.isConnected = () => true;
    liveSocket.main = {
      id: "container1",
      isMain: () => true,
      isConnected: () => true,
    };
  });

  beforeEach(() => {
    document.body.innerHTML = `
      <div id="container1">
        <a id="nav" href="/other" data-phx-link="redirect" data-phx-link-state="push">Go</a>
        <a id="patch" href="/container?x=1" data-phx-link="patch" data-phx-link-state="push">Patch</a>
        <a id="both" href="/clicked" data-phx-link="redirect" data-phx-link-state="push" phx-click="mark">Both</a>
      </div>
    `;
    liveSocket.historyRedirect = jest.fn();
    liveSocket.pushHistoryPatch = jest.fn();
    liveSocket.execJS = jest.fn();
    liveSocket.currentLocation = new URL(window.location.href);
    liveSocket.currentHistoryPosition = 0;
  });

  afterEach(() => {
    document.body.innerHTML = "";
  });

  test("preventDefault cancels a live link click", () => {
    const before = [];
    const navigated = [];
    const onBefore = (event) => {
      before.push(event.detail);
      event.preventDefault();
    };
    const onNavigate = (event) => navigated.push(event.detail);
    window.addEventListener("phx:before-navigate", onBefore);
    window.addEventListener("phx:navigate", onNavigate);

    document.getElementById("nav").click();

    window.removeEventListener("phx:before-navigate", onBefore);
    window.removeEventListener("phx:navigate", onNavigate);

    expect(before).toEqual([
      {
        href: "http://localhost/other",
        patch: false,
        pop: false,
        direction: "forward",
      },
    ]);
    expect(navigated).toEqual([]);
    expect(liveSocket.historyRedirect).not.toHaveBeenCalled();
    expect(liveSocket.pushHistoryPatch).not.toHaveBeenCalled();
  });

  test("a live link click continues when not prevented", () => {
    const before = [];
    const onBefore = (event) => before.push(event.detail);
    window.addEventListener("phx:before-navigate", onBefore);

    document.getElementById("patch").click();

    window.removeEventListener("phx:before-navigate", onBefore);

    expect(before).toEqual([
      {
        href: "http://localhost/container?x=1",
        patch: true,
        pop: false,
        direction: "forward",
      },
    ]);
    expect(liveSocket.pushHistoryPatch).toHaveBeenCalled();
    expect(liveSocket.historyRedirect).not.toHaveBeenCalled();
  });

  test("phx-click still runs when navigation is cancelled", () => {
    const onBefore = (event) => event.preventDefault();
    window.addEventListener("phx:before-navigate", onBefore);

    document.getElementById("both").click();

    window.removeEventListener("phx:before-navigate", onBefore);

    expect(liveSocket.execJS).toHaveBeenCalled();
    expect(liveSocket.historyRedirect).not.toHaveBeenCalled();
  });

  test("preventDefault cancels popstate and restores history", () => {
    liveSocket.currentLocation = new URL("http://localhost/stay");
    liveSocket.currentHistoryPosition = 3;
    const forward = jest
      .spyOn(window.history, "forward")
      .mockImplementation(() => {});
    const before = [];
    const onBefore = (event) => {
      before.push(event.detail);
      event.preventDefault();
    };
    window.addEventListener("phx:before-navigate", onBefore);

    window.history.pushState({ type: "redirect", position: 1 }, "", "/away");
    window.dispatchEvent(
      new PopStateEvent("popstate", {
        state: { type: "redirect", position: 1 },
      }),
    );

    window.removeEventListener("phx:before-navigate", onBefore);

    expect(before).toEqual([
      {
        href: "http://localhost/away",
        patch: false,
        pop: true,
        direction: "backward",
      },
    ]);
    expect(forward).toHaveBeenCalled();
    expect(liveSocket.historyRedirect).not.toHaveBeenCalled();
    expect(liveSocket.currentLocation.pathname).toBe("/stay");
    forward.mockRestore();
  });
});
