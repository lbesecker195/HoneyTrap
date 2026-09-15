defmodule McpRegistry.RateLimiter do
  @moduledoc """
  Fixed-window counters kept in ETS. The registry runs as a single node, so a
  local table is enough; counts reset when the app restarts.
  """
  use GenServer

  @table :mcp_registry_rate_limits
  @sweep_every :timer.minutes(5)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Records one hit for `key` in the current window. Returns `:ok` while the
  count is within `limit`, otherwise `{:error, seconds_until_the_window_resets}`.
  """
  def hit(key, limit, window_seconds) when limit > 0 and window_seconds > 0 do
    now = System.system_time(:second)
    window = div(now, window_seconds)
    resets_at = (window + 1) * window_seconds
    entry_key = {key, window_seconds, window}
    count = :ets.update_counter(@table, entry_key, {2, 1}, {entry_key, 0, resets_at})

    if count <= limit, do: :ok, else: {:error, max(resets_at - now, 1)}
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    schedule_sweep()
    {:ok, nil}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.system_time(:second)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_every)
end
