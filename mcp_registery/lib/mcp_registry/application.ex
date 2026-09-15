defmodule McpRegistry.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      McpRegistryWeb.Telemetry,
      McpRegistry.Repo,
      {DNSCluster, query: Application.get_env(:mcp_registry, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: McpRegistry.PubSub},
      {Task.Supervisor, name: McpRegistry.AnalyticsSupervisor},
      McpRegistry.RateLimiter,
      McpRegistry.OfficialRegistry.Scheduler,
      # Start a worker by calling: McpRegistry.Worker.start_link(arg)
      # {McpRegistry.Worker, arg},
      # Start to serve requests, typically the last entry
      McpRegistryWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: McpRegistry.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    McpRegistryWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
