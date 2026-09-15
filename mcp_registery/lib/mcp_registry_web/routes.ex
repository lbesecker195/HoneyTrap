defmodule McpRegistryWeb.Routes do
  @moduledoc """
  Path helpers for routes whose parameter is a server name. Names contain a
  slash (`io.github.acme/weather`), which the router matches with a glob, so
  these are built as plain strings rather than through `~p`.
  """
  alias McpRegistry.Registry.Server

  def server_path(%Server{name: name}), do: server_path(name)
  def server_path(name) when is_binary(name), do: "/servers/" <> name

  def api_server_path(%Server{name: name}), do: api_server_path(name)
  def api_server_path(name) when is_binary(name), do: "/api/v0/servers/" <> name
end
