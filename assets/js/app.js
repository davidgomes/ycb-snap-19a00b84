// Phoenix assets are imported from dependencies.
import topbar from "topbar";

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let livePath = document.querySelector("meta[name='live-path']").getAttribute("content");
let liveTransport = document .querySelector("meta[name='live-transport']") .getAttribute("content");

const Theme = {
  STORAGE_KEY: "error-tracker-theme",
  CLASS_NAME: "light-theme",

  init() {
    document.documentElement.classList.toggle(this.CLASS_NAME, this.load() === "light");
  },

  toggle() {
    const isLight = document.documentElement.classList.toggle(this.CLASS_NAME);
    this.save(isLight ? "light" : "dark");
  },

  load() {
    try {
      return localStorage.getItem(this.STORAGE_KEY);
    } catch (_error) {
      return null;
    }
  },

  save(theme) {
    try {
      localStorage.setItem(this.STORAGE_KEY, theme);
    } catch (_error) {
      // Storage may be unavailable (e.g. private browsing); the theme still applies for this page.
    }
  }
};

// The script runs in <head>, so applying the theme here avoids a flash of the dark theme.
Theme.init();

// Event delegation keeps the toggle working without inline handlers, which CSP may forbid.
document.addEventListener("click", (event) => {
  if (event.target.closest("[data-theme-toggle]")) Theme.toggle();
});

const Hooks = {
  JsonPrettyPrint: {
    mounted() {
      this.formatJson();
    },
    updated() {
      this.formatJson();
    },
    formatJson() {
      try {
        // Get the raw JSON content
        const rawJson = this.el.textContent.trim();
        // Parse and stringify with indentation
        const formattedJson = JSON.stringify(JSON.parse(rawJson), null, 2);
        // Update the element content
        this.el.textContent = formattedJson;
      } catch (error) {
        console.error("Error formatting JSON:", error);
        // Keep the original content if there's an error
      }
    }
  }
};

let liveSocket = new LiveView.LiveSocket(livePath, Phoenix.Socket, {
  transport: liveTransport === "longpoll" ? Phoenix.LongPoll : WebSocket,
  params: { _csrf_token: csrfToken },
  hooks: Hooks

});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();
window.liveSocket = liveSocket;
