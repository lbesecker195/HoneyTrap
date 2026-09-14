defmodule McpRegistryWeb.ServerLive.Index do
  use McpRegistryWeb, :live_view

  alias McpRegistry.Analytics
  alias McpRegistry.Registry
  alias McpRegistry.Registry.Server

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Browse MCP servers")
     |> assign(:tags, Registry.top_tags(14))
     |> assign(:stats, Registry.stats())
     |> assign(:transports, Server.transports())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    q = String.trim(params["q"] || "")
    transport = blank_to_nil(params["transport"])
    tag = blank_to_nil(params["tag"])
    servers = Registry.list_servers(q: q, transport: transport, tag: tag, limit: 100)

    if connected?(socket) and q != "" do
      Analytics.track(:search, %{results: length(servers), path: "/"})
    end

    {:noreply, assign(socket, q: q, transport: transport, tag: tag, servers: servers)}
  end

  @impl true
  def handle_event("search", %{"q" => q} = params, socket) do
    transport = Map.get(params, "transport", socket.assigns.transport)
    {:noreply, push_patch(socket, to: index_path(q, transport, socket.assigns.tag))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="space-y-3">
        <h1 class="text-4xl font-bold tracking-tight">Find MCP servers your agent can use.</h1>
        <p class="text-base-content/70 max-w-2xl">
          <b>{@stats.servers}</b>
          Model Context Protocol servers exposing <b>{@stats.tools}</b>
          tools, {@stats.remote} of them hosted remotely.
          Browse below, or point an agent at <a href={~p"/llms.txt"} class="link">/llms.txt</a>.
        </p>
      </section>

      <form
        id="search-form"
        phx-change="search"
        phx-submit="search"
        class="flex flex-col sm:flex-row gap-2"
      >
        <label class="input input-bordered flex items-center gap-2 flex-1">
          <.icon name="hero-magnifying-glass" class="size-4 opacity-60" />
          <input
            type="search"
            name="q"
            value={@q}
            placeholder="Search by name, description, tag or tool name…"
            phx-debounce="250"
            class="grow"
            autocomplete="off"
          />
        </label>
        <select name="transport" class="select select-bordered">
          <option value="">Any transport</option>
          <option :for={t <- @transports} value={t} selected={t == @transport}>{t}</option>
        </select>
      </form>

      <div class="flex flex-wrap gap-2">
        <.link
          patch={index_path(@q, @transport, nil)}
          class={["badge", if(@tag == nil, do: "badge-primary", else: "badge-ghost")]}
        >
          all
        </.link>
        <.link
          :for={{tag, count} <- @tags}
          patch={index_path(@q, @transport, tag)}
          class={["badge", if(@tag == tag, do: "badge-primary", else: "badge-ghost")]}
        >
          {tag} <span class="opacity-60 ml-1">{count}</span>
        </.link>
      </div>

      <p :if={@servers == []} class="text-base-content/60 py-10 text-center">
        No servers match. <.link navigate={~p"/submit"} class="link">Submit one?</.link>
      </p>

      <ul class="grid gap-3 sm:grid-cols-2">
        <li :for={server <- @servers}>
          <.link
            navigate={server_path(server)}
            class="card bg-base-200 hover:bg-base-300 transition-colors h-full block"
          >
            <div class="card-body p-4 gap-2">
              <div class="flex items-start justify-between gap-2">
                <h2 class="card-title text-base">{server.title}</h2>
                <span class={["badge badge-sm shrink-0", transport_badge(server.transport)]}>
                  {server.transport}
                </span>
              </div>
              <p class="font-mono text-xs opacity-60 truncate">{server.name}</p>
              <p class="text-sm line-clamp-2">{server.description}</p>
              <div class="flex flex-wrap gap-1 mt-auto pt-1">
                <span :for={tag <- Enum.take(server.tags, 4)} class="badge badge-ghost badge-xs">
                  {tag}
                </span>
                <span :if={server.tools != []} class="badge badge-outline badge-xs">
                  {length(server.tools)} tools
                </span>
              </div>
            </div>
          </.link>
        </li>
      </ul>
    </Layouts.app>
    """
  end

  defp index_path(q, transport, tag) do
    params =
      [q: q, transport: transport, tag: tag]
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)

    ~p"/?#{params}"
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp transport_badge(transport), do: Layouts.transport_badge(transport)
end
