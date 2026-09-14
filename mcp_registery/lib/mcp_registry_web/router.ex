defmodule McpRegistryWeb.Router do
  use McpRegistryWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {McpRegistryWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug McpRegistryWeb.Plugs.APIAnalytics
  end

  scope "/", McpRegistryWeb do
    pipe_through :browser

    live "/", ServerLive.Index, :index
    live "/submit", ServerLive.New, :new
    live "/servers/*name", ServerLive.Show, :show
    get "/llms.txt", LlmsController, :show
  end

  # JSON API, shaped after the official MCP registry's /v0 endpoints.
  scope "/api/v0", McpRegistryWeb.API, as: :api do
    pipe_through :api

    get "/servers", ServerController, :index
    post "/servers", ServerController, :create
    get "/servers/*name", ServerController, :show
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:mcp_registry, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: McpRegistryWeb.Telemetry
    end
  end
end
