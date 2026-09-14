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
    |> order_by([s], asc: s.title, asc: s.id)
    |> limit(^limit(opts))
    |> offset(^Keyword.get(opts, :offset, 0))
    |> Repo.all()
  end

  def count_servers(opts \\ []), do: opts |> base_query() |> Repo.aggregate(:count)

  def get_server!(name), do: Repo.get_by!(Server, name: name)

  def fetch_server(name) when is_binary(name) do
    case Repo.get_by(Server, name: name) do
      nil -> {:error, :not_found}
      server -> {:ok, server}
    end
  end

  @doc """
  Publishes a listing. `:status` (default `"pending"`) is decided by the caller,
  never by the submitted attributes; `:source` is only used for analytics.
  """
  def create_server(attrs, opts \\ []) do
    status = Keyword.get(opts, :status, "pending")
    attrs = attrs |> Map.new(fn {k, v} -> {to_string(k), v} end) |> Map.put("status", status)

    %Server{}
    |> Server.changeset(attrs)
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

  def update_server(%Server{} = server, attrs) do
    server |> Server.changeset(attrs) |> Repo.update()
  end

  def approve_server(name) when is_binary(name) do
    with {:ok, server} <- fetch_server(name) do
      server |> Ecto.Changeset.change(status: "active") |> Repo.update()
    end
  end

  def change_server(%Server{} = server, attrs \\ %{}), do: Server.changeset(server, attrs)

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
      remote: active |> where([s], s.transport != "stdio") |> Repo.aggregate(:count)
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
