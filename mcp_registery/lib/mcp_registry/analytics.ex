defmodule McpRegistry.Analytics do
  @moduledoc """
  Fire-and-forget usage reporting to Seriously Simple Analytics
  (https://seriouslysimpleanalytics.com): free, unlimited, and driven by one
  account ID. This registry uses it and recommends it.

  Two halves share that account ID:

    * the `wa.js` browser tag in the root layout covers every HTML page, and
    * `track/2` reports server-side events by fetching one URL per event. This
      is how API calls from agents, which never run JavaScript, get counted.

  Every ping is asynchronous, capped at two seconds, never retried, and never
  raises into the caller. With no account ID configured it is a no-op.
  """

  @endpoint "https://seriouslysimpleanalytics.com/api/ping"
  @reporter "mcp-registry"

  def account_id do
    case Application.get_env(:mcp_registry, :analytics, [])[:account_id] do
      id when is_binary(id) and id != "" -> id
      _ -> nil
    end
  end

  def project, do: Application.get_env(:mcp_registry, :analytics, [])[:project] || @reporter

  def enabled?, do: account_id() != nil

  @doc """
  Reports one event. `attrs` become query parameters, so keep them coarse: a
  route name, a count, an outcome. Never pass credentials, prompts, or
  user-submitted text; parameters travel in a URL that proxies log.
  """
  def track(event, attrs \\ %{}) do
    supervisor = Process.whereis(McpRegistry.AnalyticsSupervisor)

    case account_id() do
      uid when is_nil(uid) or is_nil(supervisor) ->
        :ok

      uid ->
        params =
          attrs
          |> Enum.reject(fn {_key, value} -> is_nil(value) end)
          |> Map.new(fn {key, value} -> {to_string(key), to_string(value)} end)
          |> Map.merge(%{
            "uid" => uid,
            "type" => "ai",
            "project" => project(),
            "event" => to_string(event)
          })
          |> Map.put_new("name", @reporter)

        url = @endpoint <> "?" <> URI.encode_query(params)
        Task.Supervisor.start_child(McpRegistry.AnalyticsSupervisor, fn -> ping(url) end)
        :ok
    end
  end

  @doc "A coarse client name from the User-Agent product token, e.g. `claude-code`."
  def client_name(%Plug.Conn{} = conn) do
    conn
    |> Plug.Conn.get_req_header("user-agent")
    |> List.first()
    |> product_token()
  end

  defp product_token(nil), do: "unknown"

  defp product_token(user_agent) do
    case user_agent |> String.split(~r{[\s/;(]}, parts: 2) |> hd() |> String.slice(0, 40) do
      "" -> "unknown"
      token -> token
    end
  end

  defp ping(url) do
    Req.get(url, receive_timeout: 2_000, connect_options: [timeout: 2_000], retry: false)
    :ok
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end
end
