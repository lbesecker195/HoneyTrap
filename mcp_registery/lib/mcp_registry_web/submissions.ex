defmodule McpRegistryWeb.Submissions do
  @moduledoc """
  The single path for programmatic submissions, shared by the JSON API and the
  MCP endpoint.

    * No `Authorization` header: anyone, including any AI agent, may submit.
      The listing is `pending` until reviewed, and each client address is rate
      limited.
    * `Authorization: Bearer <REGISTRY_PUBLISH_TOKEN>`: published immediately.
    * Any other `Authorization` header is rejected rather than silently
      downgraded to a pending submission.
  """
  alias McpRegistry.RateLimiter
  alias McpRegistry.Registry
  alias McpRegistry.Registry.Manifest

  @doc """
  Submits a `server.json` manifest or a map of this registry's flat fields.
  Returns `{:ok, server}` or `{:error, reason}`, where reason is a changeset,
  `:unauthorized`, `:queue_full` or `{:rate_limited, retry_after_seconds}`.
  """
  def submit(%Plug.Conn{} = conn, params, source) when is_map(params) do
    with {:ok, access} <- access(conn),
         :ok <- rate_limit(conn, access) do
      status = if access == :admin, do: "active", else: "pending"
      Registry.create_server(attrs_from(params), status: status, source: source)
    end
  end

  @doc "Classifies the caller as `{:ok, :admin}`, `{:ok, :anonymous}` or `{:error, :unauthorized}`."
  def access(%Plug.Conn{} = conn) do
    token = Application.get_env(:mcp_registry, :registry, [])[:publish_token]

    case Plug.Conn.get_req_header(conn, "authorization") do
      [] ->
        {:ok, :anonymous}

      ["Bearer " <> given] when is_binary(token) and token != "" ->
        if Plug.Crypto.secure_compare(String.trim(given), token),
          do: {:ok, :admin},
          else: {:error, :unauthorized}

      _ ->
        {:error, :unauthorized}
    end
  end

  @doc "Like `access/1`, but anonymous callers are refused."
  def require_admin(%Plug.Conn{} = conn) do
    case access(conn) do
      {:ok, :admin} -> :ok
      _ -> {:error, :unauthorized}
    end
  end

  @doc "Changeset errors as `%{field => [message]}`."
  def error_details(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, &McpRegistryWeb.CoreComponents.translate_error/1)
  end

  defp rate_limit(_conn, :admin), do: :ok

  defp rate_limit(conn, :anonymous) do
    limit = Application.get_env(:mcp_registry, :submissions, [])[:per_client_per_hour] || 10
    client = conn.remote_ip |> :inet.ntoa() |> to_string()

    case RateLimiter.hit({:submission, client}, limit, 3600) do
      :ok -> :ok
      {:error, retry_after} -> {:error, {:rate_limited, retry_after}}
    end
  end

  # Accept either a server.json manifest or flat field names.
  defp attrs_from(params) do
    params = Map.drop(params, ["status", :status])

    if Enum.any?(["packages", "remotes", "$schema"], &Map.has_key?(params, &1)),
      do: Manifest.from_map(params),
      else: params
  end
end
