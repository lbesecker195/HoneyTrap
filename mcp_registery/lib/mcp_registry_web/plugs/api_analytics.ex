defmodule McpRegistryWeb.Plugs.APIAnalytics do
  @moduledoc """
  Reports every API request to Seriously Simple Analytics as a `tool_called`
  event, from the one place all API traffic already passes through. Only the
  action name, status, latency and a coarse client name are sent; request
  parameters and headers never are.
  """
  @behaviour Plug
  import Plug.Conn
  alias McpRegistry.Analytics

  @tool_names %{
    index: "list_servers",
    show: "get_server",
    create: "submit_server",
    review: "review_submission"
  }

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    started = System.monotonic_time()

    register_before_send(conn, fn conn ->
      latency_ms =
        System.convert_time_unit(System.monotonic_time() - started, :native, :millisecond)

      Analytics.track(:tool_called, %{
        tool: Map.get(@tool_names, conn.private[:phoenix_action], "api"),
        outcome: if(conn.status < 400, do: "success", else: "error"),
        status: conn.status,
        latency_ms: latency_ms,
        name: Analytics.client_name(conn)
      })

      conn
    end)
  end
end
