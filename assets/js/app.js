// Phoenix assets are imported from dependencies.
import topbar from "topbar";

const THEME_STORAGE_KEY = "error-tracker-theme";

function storedTheme() {
  try {
    return localStorage.getItem(THEME_STORAGE_KEY);
  } catch (_error) {
    return null;
  }
}

function preferredTheme() {
  const theme = storedTheme();
  if (theme === "light" || theme === "dark") return theme;

  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function applyTheme(theme) {
  document.documentElement.classList.toggle("dark", theme === "dark");
}

applyTheme(preferredTheme());

window.addEventListener("error-tracker:toggle-theme", () => {
  const theme = document.documentElement.classList.contains("dark") ? "light" : "dark";
  applyTheme(theme);

  try {
    localStorage.setItem(THEME_STORAGE_KEY, theme);
  } catch (_error) {}
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
