// Phoenix assets are imported from dependencies.
import topbar from "topbar";

const THEME_STORAGE_KEY = "error-tracker-theme";
const prefersDarkScheme = window.matchMedia("(prefers-color-scheme: dark)");

function getStoredTheme() {
  try {
    return localStorage.getItem(THEME_STORAGE_KEY);
  } catch (_error) {
    return null;
  }
}

function getPreferredTheme() {
  return getStoredTheme() || (prefersDarkScheme.matches ? "dark" : "light");
}

function applyTheme(theme) {
  document.documentElement.classList.toggle("dark", theme === "dark");
}

// Runs while the <head> is being parsed so the page never renders with the wrong theme
applyTheme(getPreferredTheme());

prefersDarkScheme.addEventListener("change", () => applyTheme(getPreferredTheme()));

window.addEventListener("error-tracker:toggle-theme", () => {
  const theme = document.documentElement.classList.contains("dark") ? "light" : "dark";

  try {
    localStorage.setItem(THEME_STORAGE_KEY, theme);
  } catch (_error) {
    // Storage may be unavailable (e.g. privacy mode); the theme still applies to this page
  }

  applyTheme(theme);
});

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let livePath = document.querySelector("meta[name='live-path']").getAttribute("content");
let liveTransport = document .querySelector("meta[name='live-transport']") .getAttribute("content");

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
