defmodule McpRegistry.RegistryFixtures do
  @moduledoc "Test helpers for creating registry entities."

  def valid_server_attrs(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "io.github.acme/weather-#{unique}",
      title: "Weather #{unique}",
      description: "Forecasts and severe-weather alerts by location.",
      version: "1.2.3",
      transport: "stdio",
      package_registry: "npm",
      package_identifier: "@acme/weather-mcp",
      env_vars: ["WEATHER_API_KEY"],
      tags: ["weather", "data"],
      tools: ["get_forecast", "get_alerts"],
      repository_url: "https://github.com/acme/weather-mcp",
      license: "MIT"
    })
  end

  def server_fixture(attrs \\ %{}) do
    status = Map.get(attrs, :status, "active")
    {:ok, server} = McpRegistry.Registry.create_server(valid_server_attrs(attrs), status: status)
    server
  end
end
