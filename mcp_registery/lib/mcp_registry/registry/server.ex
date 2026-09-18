defmodule McpRegistry.Registry.Server do
  @moduledoc """
  One MCP server listing.

  Names follow the reverse-DNS convention used by the official MCP registry:
  `io.github.acme/weather` is a namespace the publisher controls, a slash, then
  the server's short name. A listing describes one primary transport (`stdio`
  for locally-run packages, `streamable-http` or `sse` for hosted endpoints)
  and may carry both a package and a remote URL when a server ships both.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @transports ~w(stdio streamable-http sse)
  @registries ~w(npm pypi oci nuget mcpb cargo)
  @statuses ~w(active pending deprecated)
  @origins ~w(local seed official)
  @list_fields [:env_vars, :tags, :tools]
  @name_format ~r/^[a-z0-9][a-z0-9.\-]*\/[a-z0-9][a-z0-9._\-]*$/

  schema "servers" do
    field :name, :string
    field :title, :string
    field :description, :string
    field :version, :string, default: "0.1.0"
    field :status, :string, default: "active"
    field :transport, :string, default: "stdio"
    field :remote_url, :string
    field :package_registry, :string
    field :package_identifier, :string
    field :repository_url, :string
    field :website_url, :string
    field :license, :string
    field :env_vars, {:array, :string}, default: []
    field :tags, {:array, :string}, default: []
    field :tools, {:array, :string}, default: []
    field :origin, :string, default: "local"
    field :source_updated_at, :utc_datetime_usec
    field :synced_at, :utc_datetime_usec

    timestamps(type: :utc_datetime)
  end

  def transports, do: @transports
  def registries, do: @registries
  def statuses, do: @statuses
  def origins, do: @origins

  @doc "Everything after the slash: `io.github.acme/weather` becomes `weather`."
  def short_name(%__MODULE__{name: name}), do: short_name(name)
  def short_name(name) when is_binary(name), do: name |> String.split("/") |> List.last()

  @doc """
  Best-effort publisher name for SEO copy, derived from the reverse-DNS
  namespace: `io.github.acme/weather` becomes `Acme`, `com.brave/brave-search`
  becomes `Brave`. There is no dedicated company field, so this is a guess,
  not an authoritative vendor name.
  """
  def company_name(%__MODULE__{name: name}), do: company_name(name)

  def company_name(name) when is_binary(name) do
    namespace = name |> String.split("/") |> List.first() || ""
    segment = namespace |> String.split(".") |> List.last() || namespace

    case segment |> String.split(~r/[-_]/, trim: true) |> Enum.map(&String.capitalize/1) do
      [] -> "MCP"
      words -> Enum.join(words, " ")
    end
  end

  def company_name(_), do: "MCP"

  def remote?(%__MODULE__{transport: transport}), do: transport in ["streamable-http", "sse"]

  @doc """
  Validates a listing. `origin` is never cast from attributes; callers set it.

  Pass `imported: true` for listings copied from the official registry, whose
  own rules allow shorter descriptions and longer version strings.
  """
  def changeset(server, attrs, opts \\ []) do
    imported? = Keyword.get(opts, :imported, false)
    attrs = normalize_attrs(attrs)

    server
    |> cast(attrs, [
      :name,
      :title,
      :description,
      :version,
      :status,
      :transport,
      :remote_url,
      :package_registry,
      :package_identifier,
      :repository_url,
      :website_url,
      :license | @list_fields
    ])
    |> update_change(:name, &normalize_name/1)
    |> validate_required([:name, :title, :description, :version, :transport, :status])
    |> validate_format(:name, @name_format,
      message: "must look like namespace/server-name, e.g. io.github.acme/weather"
    )
    |> validate_length(:name, max: 200)
    |> validate_length(:title, max: 120)
    |> validate_length(:description, min: if(imported?, do: 1, else: 10), max: 1000)
    |> validate_length(:version, max: if(imported?, do: 255, else: 40))
    |> validate_inclusion(:transport, @transports)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:package_registry, @registries)
    |> validate_url(:remote_url, imported?)
    |> validate_url(:repository_url, imported?)
    |> validate_url(:website_url, imported?)
    |> validate_length(:remote_url, max: 4096)
    |> validate_length(:repository_url, max: 4096)
    |> validate_length(:website_url, max: 4096)
    |> validate_length(:package_identifier, max: 1024)
    |> validate_distribution()
    |> validate_length(:tags, max: 12)
    |> unique_constraint(:name, message: "is already published")
  end

  defp normalize_name(nil), do: nil
  defp normalize_name(name), do: name |> String.trim() |> String.downcase()

  # Accept atom or string keys, and comma/newline-separated strings for list
  # fields so the same changeset serves HTML forms, the JSON API and seeds.
  defp normalize_attrs(attrs) do
    Map.new(attrs, fn {key, value} ->
      key = to_string(key)

      case key do
        "tags" -> {key, value |> to_list() |> Enum.map(&String.downcase/1) |> Enum.uniq()}
        k when k in ~w(env_vars tools) -> {key, to_list(value)}
        _ -> {key, value}
      end
    end)
  end

  defp to_list(value) when is_binary(value),
    do: value |> String.split([",", "\n"]) |> clean_list()

  defp to_list(value) when is_list(value), do: value |> Enum.map(&to_string/1) |> clean_list()
  defp to_list(_), do: []

  defp clean_list(items) do
    items |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")) |> Enum.uniq()
  end

  # Submissions here must be strictly valid URLs. Imported listings may carry
  # placeholders the publisher expects users to fill in, such as
  # https://{HOST}:{PORT}/mcp or https://example.com/mcp/[TOKEN].
  defp validate_url(changeset, field, lenient?) do
    validate_change(changeset, field, fn ^field, value ->
      candidate = String.replace(value, ~r/\{[^{}]*\}/, "1")

      if http_url?(candidate, lenient?), do: [], else: [{field, "must be an http(s) URL"}]
    end)
  end

  defp http_url?(value, lenient?) do
    uri =
      case URI.new(value) do
        {:ok, uri} -> uri
        {:error, _} when lenient? -> URI.parse(value)
        {:error, _} -> nil
      end

    match?(
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and host not in [nil, ""],
      uri
    )
  end

  # A remote transport needs an endpoint; a stdio server needs a package; and a
  # package registry and identifier only make sense together.
  defp validate_distribution(changeset) do
    transport = get_field(changeset, :transport)
    remote_url = get_field(changeset, :remote_url)
    registry = get_field(changeset, :package_registry)
    identifier = get_field(changeset, :package_identifier)

    changeset
    |> add_error_if(
      transport in ["streamable-http", "sse"] and is_nil(remote_url),
      :remote_url,
      "is required for remote transports"
    )
    |> add_error_if(
      transport == "stdio" and is_nil(registry),
      :package_registry,
      "is required for stdio servers"
    )
    |> add_error_if(
      transport == "stdio" and is_nil(identifier),
      :package_identifier,
      "is required for stdio servers"
    )
    |> add_error_if(
      is_nil(registry) and not is_nil(identifier),
      :package_registry,
      "is required when a package identifier is given"
    )
    |> add_error_if(
      not is_nil(registry) and is_nil(identifier),
      :package_identifier,
      "is required when a package registry is given"
    )
  end

  defp add_error_if(changeset, true, field, message) do
    if Keyword.has_key?(changeset.errors, field),
      do: changeset,
      else: add_error(changeset, field, message)
  end

  defp add_error_if(changeset, false, _field, _message), do: changeset
end
