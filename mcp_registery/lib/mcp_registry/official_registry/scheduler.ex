defmodule McpRegistry.OfficialRegistry.Scheduler do
  @moduledoc """
  Runs `McpRegistry.OfficialRegistry.sync/1` on a schedule when
  `sync_enabled` is set. Restarts and deploys don't cause extra syncs: the
  schedule is based on the last successful run recorded in the database.
  """
  use GenServer
  require Logger

  alias McpRegistry.OfficialRegistry

  # After a failed run, wait at least this long before trying again.
  @retry_after :timer.minutes(15)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    config = OfficialRegistry.config()

    if config[:sync_enabled] do
      Process.send_after(self(), :tick, config[:initial_delay_ms])
      {:ok, %{}}
    else
      :ignore
    end
  end

  @impl true
  def handle_info(:tick, state) do
    next =
      try do
        case wait_ms() do
          0 ->
            OfficialRegistry.sync()
            OfficialRegistry.config()[:sync_interval_ms]

          wait ->
            wait
        end
      rescue
        exception ->
          Logger.error("Official registry scheduler failed: #{Exception.message(exception)}")
          @retry_after
      end

    Process.send_after(self(), :tick, next)
    {:noreply, state}
  end

  defp wait_ms do
    interval = OfficialRegistry.config()[:sync_interval_ms]
    now = DateTime.utc_now()

    since_ok = since(OfficialRegistry.last_run("ok"), now)
    since_any = since(OfficialRegistry.last_run(), now)

    cond do
      since_ok != nil and since_ok < interval -> interval - since_ok
      since_any != nil and since_any < @retry_after -> @retry_after - since_any
      true -> 0
    end
  end

  defp since(nil, _now), do: nil
  defp since(run, now), do: DateTime.diff(now, run.started_at, :millisecond)
end
