defmodule McpRegistry.OfficialRegistry do
  @moduledoc """
  Keeps this registry in step with the official MCP Registry at
  https://registry.modelcontextprotocol.io, whose design docs ask downstream
  registries to copy its catalogue this way.

  A full sync reads the latest version of every server. An incremental sync
  reads only what changed since the last successful run, deletions included.
  Both page through the API with retries on transient errors.

  Merge rules, by the origin of the listing already here:

    * No listing yet: the server is added and goes live.
    * `official` or `seed`: install details, description and version follow
      upstream. Tags, tool names and license are kept when upstream has none,
      because the official format does not carry them. Seed listings stay
      marked `seed`, so they keep their place at the top of the catalogue and
      are never removed by upstream deletions.
    * `local` and pending review: upstream wins. Its publisher proved control
      of the namespace to the official registry.
    * `local` and active: left alone. A maintainer approved it here.

  Upstream deletions remove `official` listings. After a successful full sync,
  `official` listings that no longer appear upstream are removed as well,
  unless the run saw suspiciously few servers.
  """
  import Ecto.Query
  require Logger

  alias McpRegistry.Analytics
  alias McpRegistry.OfficialRegistry.SyncRun
  alias McpRegistry.Registry.{Manifest, Server}
  alias McpRegistry.Repo

  @meta_key "io.modelcontextprotocol.registry/official"
  @lock_key 7_311_042_026

  @counters ~w(inserted updated unchanged deleted removed_missing kept_local replaced_pending
               not_installable invalid duplicate ignored_deleted failed)a

  # Outcomes that leave an existing listing as it was. Their sync time is
  # bumped so a full sync's sweep keeps the last good version.
  @keep_outcomes [:unchanged, :invalid]

  def config, do: Application.get_env(:mcp_registry, :official_registry, [])

  @doc "The official registry's API URL for a server's latest version."
  def server_url(name) do
    config()[:base_url] <> "/v0.1/servers/" <> URI.encode_www_form(name) <> "/versions/latest"
  end

  @doc "The most recent run with the given status, or any status when nil."
  def last_run(status \\ nil) do
    SyncRun
    |> then(fn q -> if status, do: where(q, [r], r.status == ^status), else: q end)
    |> order_by([r], desc: r.started_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Runs one sync. `mode:` is `:auto` (the default: incremental after a recent
  full sync, otherwise full), `:full` or `:incremental`.

  Returns `{:ok, stats}`, `{:error, reason, stats}` or `{:error, :already_running}`.
  """
  def sync(opts \\ []) do
    Repo.checkout(
      fn ->
        if locked?() do
          try do
            run(resolve_mode(Keyword.get(opts, :mode, :auto)))
          after
            Repo.query!("SELECT pg_advisory_unlock($1)", [@lock_key])
          end
        else
          {:error, :already_running}
        end
      end,
      timeout: :infinity
    )
  end

  defp locked? do
    %{rows: [[locked]]} = Repo.query!("SELECT pg_try_advisory_lock($1)", [@lock_key])
    locked
  end

  defp resolve_mode(:auto) do
    full_every = config()[:full_sync_every_ms]

    case {last_run("ok"), last_full_ok()} do
      {%SyncRun{}, %SyncRun{started_at: at}} ->
        if DateTime.diff(DateTime.utc_now(), at, :millisecond) < full_every,
          do: :incremental,
          else: :full

      _ ->
        :full
    end
  end

  defp resolve_mode(mode) when mode in [:full, :incremental], do: mode

  defp last_full_ok do
    SyncRun
    |> where([r], r.status == "ok" and r.mode == "full")
    |> order_by([r], desc: r.started_at)
    |> limit(1)
    |> Repo.one()
  end

  defp run(mode) do
    started_at = DateTime.utc_now()

    # We hold the lock, so any run still marked running was interrupted.
    SyncRun
    |> where([r], r.status == "running")
    |> Repo.update_all(set: [status: "error", error: "interrupted", finished_at: started_at])

    params =
      case {mode, last_run("ok")} do
        {:incremental, %SyncRun{started_at: at}} ->
          # Overlap the previous run a little so nothing slips between them.
          %{version: "latest", updated_since: at |> DateTime.add(-600) |> DateTime.to_iso8601()}

        _ ->
          %{version: "latest"}
      end

    mode = if Map.has_key?(params, :updated_since), do: :incremental, else: :full

    run =
      Repo.insert!(%SyncRun{mode: to_string(mode), status: "running", started_at: started_at})

    Logger.info("Official registry sync started (#{mode})")

    outcome =
      try do
        pages(nil, params, %{
          run_at: started_at,
          stats: Map.new(@counters, &{&1, 0}),
          seen: MapSet.new()
        })
      rescue
        exception ->
          {:error, Exception.message(exception), %{stats: Map.new(@counters, &{&1, 0})}}
      end

    {status, error, stats} =
      case outcome do
        {:ok, state} ->
          stats = if mode == :full, do: sweep(state), else: state.stats
          {"ok", nil, stats}

        {:error, reason, state} ->
          {"error", to_string(reason), state.stats}
      end

    Repo.update!(
      Ecto.Changeset.change(run,
        status: status,
        error: error,
        stats: stats,
        finished_at: DateTime.utc_now()
      )
    )

    Analytics.track(:registry_synced, Map.merge(%{mode: mode, outcome: status}, stats))
    Logger.info("Official registry sync #{status} (#{mode}): #{inspect(stats)}")

    if status == "ok", do: {:ok, stats}, else: {:error, error, stats}
  end

  defp pages(cursor, params, state) do
    case fetch_page(params, cursor) do
      {:ok, servers, next_cursor} ->
        state = apply_page(servers, state)

        if next_cursor in [nil, ""] or servers == [] do
          {:ok, state}
        else
          if (delay = config()[:page_delay_ms]) > 0, do: Process.sleep(delay)
          pages(next_cursor, params, state)
        end

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp fetch_page(params, cursor) do
    query =
      params
      |> Map.put(:limit, config()[:page_size])
      |> then(fn q -> if cursor, do: Map.put(q, :cursor, cursor), else: q end)

    request =
      Req.new(
        [
          base_url: config()[:base_url],
          url: "/v0.1/servers",
          params: query,
          retry: :transient,
          max_retries: 4,
          receive_timeout: 60_000,
          headers: [{"user-agent", user_agent()}]
        ] ++ config()[:req_options]
      )

    case Req.get(request) do
      {:ok, %Req.Response{status: 200, body: %{"servers" => servers} = body}}
      when is_list(servers) ->
        {:ok, servers, get_in(body, ["metadata", "nextCursor"])}

      {:ok, %Req.Response{status: status}} ->
        {:error, "official registry returned HTTP #{status}"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  defp user_agent do
    "mcp-registry/#{Application.spec(:mcp_registry, :vsn)} (+#{McpRegistryWeb.Endpoint.url()})"
  end

  # Entries are written one by one, outside a shared transaction, so a bad
  # entry can only fail itself.
  defp apply_page(servers, state) do
    {state, unchanged} =
      Enum.reduce(servers, {state, []}, fn entry, {state, unchanged} ->
        {outcome, name} =
          try do
            apply_entry(entry, state)
          rescue
            exception ->
              Logger.warning(
                "Official registry entry #{inspect(get_in(entry, ["server", "name"]))} failed: " <>
                  Exception.message(exception)
              )

              {:failed, nil}
          end

        state = update_in(state.stats[outcome], &(&1 + 1))
        state = if name, do: update_in(state.seen, &MapSet.put(&1, name)), else: state
        {state, if(outcome in @keep_outcomes and name, do: [name | unchanged], else: unchanged)}
      end)

    # Listings left as they were only need their sync time bumped, in one statement.
    if unchanged != [] do
      Server
      |> where([s], s.name in ^unchanged and s.origin in ["official", "seed"])
      |> Repo.update_all(set: [synced_at: state.run_at])
    end

    state
  end

  defp apply_entry(%{"server" => %{"name" => name} = json} = entry, state) when is_binary(name) do
    name = name |> String.trim() |> String.downcase()
    meta = get_in(entry, ["_meta", @meta_key]) || %{}
    upstream_status = meta["status"] || "active"
    updated_at = parse_datetime(meta["updatedAt"])

    if MapSet.member?(state.seen, name) do
      {:duplicate, nil}
    else
      existing = Repo.get_by(Server, name: name)
      {decide(existing, json, upstream_status, updated_at, state.run_at), name}
    end
  end

  defp apply_entry(_entry, _state), do: {:invalid, nil}

  defp decide(%Server{origin: "official"} = server, _json, "deleted", _updated_at, _run_at) do
    Repo.delete!(server)
    :deleted
  end

  defp decide(_existing, _json, "deleted", _updated_at, _run_at), do: :ignored_deleted

  defp decide(%Server{origin: "local", status: "active"}, _json, _status, _updated_at, _run_at),
    do: :kept_local

  defp decide(%Server{origin: origin, source_updated_at: same}, _json, status, same, _run_at)
       when origin in ["official", "seed"] and not is_nil(same) and
              status in ["active", "deprecated"],
       do: :unchanged

  defp decide(existing, json, upstream_status, updated_at, run_at) do
    attrs =
      json
      |> Manifest.from_map()
      |> keep_curated_fields(existing, json)
      |> Map.put("status", if(upstream_status == "deprecated", do: "deprecated", else: "active"))

    if is_nil(attrs["transport"]) do
      :not_installable
    else
      changeset =
        (existing || %Server{})
        |> Server.changeset(attrs, imported: true)
        |> Ecto.Changeset.put_change(
          :origin,
          if(match?(%Server{origin: "seed"}, existing), do: "seed", else: "official")
        )
        |> Ecto.Changeset.put_change(:source_updated_at, updated_at)
        |> Ecto.Changeset.put_change(:synced_at, run_at)

      case {existing, Repo.insert_or_update(changeset)} do
        {_, {:error, _changeset}} -> :invalid
        {nil, {:ok, _}} -> :inserted
        {%Server{origin: "local"}, {:ok, _}} -> :replaced_pending
        {_, {:ok, _}} -> :updated
      end
    end
  end

  # The official format has no tags, tool names or license, and its title is
  # optional. Keep what we already have rather than blanking or guessing.
  defp keep_curated_fields(attrs, nil, _json), do: attrs

  defp keep_curated_fields(attrs, %Server{}, json) do
    attrs
    |> then(fn a -> if a["tags"] in [nil, []], do: Map.delete(a, "tags"), else: a end)
    |> then(fn a -> if a["tools"] in [nil, []], do: Map.delete(a, "tools"), else: a end)
    |> then(fn a -> if is_nil(a["license"]), do: Map.delete(a, "license"), else: a end)
    |> then(fn a -> if blank?(json["title"]), do: Map.delete(a, "title"), else: a end)
  end

  defp blank?(value), do: not is_binary(value) or String.trim(value) == ""

  # After a full sync, official listings not seen upstream are gone. Skip the
  # sweep if the run saw far fewer servers than we hold, which would point to
  # an upstream problem rather than mass deletion.
  defp sweep(%{stats: stats, seen: seen, run_at: run_at}) do
    held = Server |> where([s], s.origin == "official") |> Repo.aggregate(:count)

    if MapSet.size(seen) * 2 >= held do
      {removed, _} =
        Server
        |> where([s], s.origin == "official")
        |> where([s], is_nil(s.synced_at) or s.synced_at < ^run_at)
        |> Repo.delete_all()

      Map.put(stats, :removed_missing, removed)
    else
      Logger.warning(
        "Official registry sync saw #{MapSet.size(seen)} servers but holds #{held}; skipping sweep"
      )

      Map.put(stats, :sweep_skipped, true)
    end
  end

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      # Upstream timestamps vary in precision; store and compare at microseconds.
      {:ok, datetime, _offset} -> %{datetime | microsecond: {elem(datetime.microsecond, 0), 6}}
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
