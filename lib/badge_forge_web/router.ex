defmodule BadgeForgeWeb.Router do
  use BadgeForgeWeb, :router

  import Oban.Web.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/" do
    pipe_through :browser

    oban_dashboard "/oban"
  end

  scope "/api", BadgeForgeWeb do
    pipe_through :api
  end
end
