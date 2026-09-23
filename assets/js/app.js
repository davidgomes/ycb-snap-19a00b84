// Phoenix assets are imported from dependencies.
import topbar from "topbar";

const THEME_STORAGE_KEY = "error-tracker-theme";
const systemDarkTheme = window.matchMedia("(prefers-color-scheme: dark)");

function storedTheme() {
  try {
    const theme = localStorage.getItem(THEME_STORAGE_KEY);
    return theme === "light" || theme === "dark" ? theme : null;
  } catch (_error) {
    return null;
  }
}

function applyTheme(theme) {
  document.documentElement.classList.toggle("dark", theme === "dark");
}

applyTheme(storedTheme() || (systemDarkTheme.matches ? "dark" : "light"));

systemDarkTheme.addEventListener("change", (event) => {
  if (!storedTheme()) applyTheme(event.matches ? "dark" : "light");
});

window.addEventListener("toggle-theme", () => {
  const theme = document.documentElement.classList.contains("dark") ? "light" : "dark";
  applyTheme(theme);

  try {
    localStorage.setItem(THEME_STORAGE_KEY, theme);
  } catch (_error) {
    // Storage may be unavailable (e.g. private browsing).
  }
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
