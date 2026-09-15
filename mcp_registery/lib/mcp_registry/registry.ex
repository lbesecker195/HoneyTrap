defmodule McpRegistry.Registry do
  @moduledoc "The registry: listing, searching, publishing and approving MCP servers."
  import Ecto.Query, warn: false

  alias McpRegistry.Analytics
  alias McpRegistry.Repo
  alias McpRegistry.Registry.Server

  @default_limit 30
  @max_limit 100

  @doc """
  Lists servers. Options: `:q` (free text), `:transport`, `:tag`, `:status`
  (default `"active"`), `:limit` (max #{@max_limit}) and `:offset`.
  """
  def list_servers(opts \\ []) do
    opts
    |> base_query()
    # Hand-curated and locally submitted listings first, then the official
    # catalogue with the most recently updated servers first.
    |> order_by([s],
      asc: fragment("CASE WHEN ? = 'official' THEN 1 ELSE 0 END", s.origin),
      desc_nulls_last: s.source_updated_at,
      asc: s.title,
      asc: s.id
    )
    |> limit(^limit(opts))
    |> offset(^Keyword.get(opts, :offset, 0))
    |> Repo.all()
  end

  def count_servers(opts \\ []), do: opts |> base_query() |> Repo.aggregate(:count)

  # Names are stored lowercase; the official registry allows mixed case.
  def get_server!(name), do: Repo.get_by!(Server, name: String.downcase(name))

  def fetch_server(name) when is_binary(name) do
    case Repo.get_by(Server, name: String.downcase(name)) do
      nil -> {:error, :not_found}
      server -> {:ok, server}
    end
  end

  @doc """
  Publishes a listing. `:status` (default `"pending"`) is decided by the caller,
  never by the submitted attributes; `:source` is only used for analytics, and
  `:origin` (default `"local"`) records where the listing came from.

  Returns `{:error, :queue_full}` when a pending listing would exceed the
  configured `:max_pending`.
  """
  def create_server(attrs, opts \\ []) do
    status = Keyword.get(opts, :status, "pending")

    with :ok <- check_queue_capacity(status) do
      attrs = attrs |> Map.new(fn {k, v} -> {to_string(k), v} end) |> Map.put("status", status)

      %Server{}
      |> Server.changeset(attrs)
      |> Ecto.Changeset.put_change(:origin, Keyword.get(opts, :origin, "local"))
      |> Repo.insert()
      |> tap(fn
        {:ok, server} ->
          Analytics.track(:server_submitted, %{
            status: server.status,
            transport: server.transport,
            source: Keyword.get(opts, :source, "web")
          })

        _ ->
          :ok
      end)
    end
  end

  def update_server(%Server{} = server, attrs) do
    server |> Server.changeset(attrs) |> Repo.update()
  end

  def approve_server(name) when is_binary(name) do
    with {:ok, server} <- fetch_server(name) do
      server |> Ecto.Changeset.change(status: "active") |> Repo.update()
    end
  end

  def change_server(%Server{} = server, attrs \\ %{}), do: Server.changeset(server, attrs)

  @doc "Deletes a pending listing. Active listings cannot be rejected."
  def reject_server(name) when is_binary(name) do
    with {:ok, server} <- fetch_server(name) do
      if server.status == "pending", do: Repo.delete(server), else: {:error, :not_pending}
    end
  end

  defp check_queue_capacity("pending") do
    max = Application.get_env(:mcp_registry, :submissions, [])[:max_pending] || 500
    if count_servers(status: "pending") >= max, do: {:error, :queue_full}, else: :ok
  end

  defp check_queue_capacity(_status), do: :ok

  @doc "The most-used tags among active servers, as `{tag, count}` pairs."
  def top_tags(n \\ 12) do
    Server
    |> where([s], s.status == "active")
    |> select([s], fragment("unnest(?)", s.tags))
    |> Repo.all()
    |> Enum.frequencies()
    |> Enum.sort_by(fn {tag, count} -> {-count, tag} end)
    |> Enum.take(n)
  end

  def stats do
    active = where(Server, [s], s.status == "active")

    %{
      servers: Repo.aggregate(active, :count),
      tools: active |> select([s], sum(fragment("cardinality(?)", s.tools))) |> Repo.one() || 0,
      remote: active |> where([s], s.transport != "stdio") |> Repo.aggregate(:count),
      official: active |> where([s], s.origin == "official") |> Repo.aggregate(:count)
    }
  end

  defp base_query(opts) do
    Server
    |> where([s], s.status == ^Keyword.get(opts, :status, "active"))
    |> filter_q(opts[:q])
    |> filter_eq(:transport, opts[:transport])
    |> filter_tag(opts[:tag])
  end

  defp filter_q(query, q) when is_binary(q) do
    case String.trim(q) do
      "" ->
        query

      q ->
        pattern = "%" <> escape_like(q) <> "%"

        where(
          query,
          [s],
          ilike(s.name, ^pattern) or ilike(s.title, ^pattern) or
            ilike(s.description, ^pattern) or
            fragment("array_to_string(?, ' ') ILIKE ?", s.tags, ^pattern) or
            fragment("array_to_string(?, ' ') ILIKE ?", s.tools, ^pattern)
        )
    end
  end

  defp filter_q(query, _), do: query

  defp filter_eq(query, _field, value) when value in [nil, ""], do: query
  defp filter_eq(query, field, value), do: where(query, [s], field(s, ^field) == ^value)

  defp filter_tag(query, tag) when tag in [nil, ""], do: query

  defp filter_tag(query, tag),
    do: where(query, [s], fragment("? = ANY(?)", ^String.downcase(tag), s.tags))

  defp limit(opts) do
    opts |> Keyword.get(:limit, @default_limit) |> min(@max_limit) |> max(1)
  end

  defp escape_like(text), do: String.replace(text, ~r/[\\%_]/, "\\\\\\0")
end
