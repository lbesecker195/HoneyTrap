defmodule McpRegistryWeb.ServerLive.Index do
  use McpRegistryWeb, :live_view

  alias McpRegistry.Analytics
  alias McpRegistry.Registry
  alias McpRegistry.Registry.Server

  @per_page 48

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Browse MCP servers")
     |> assign(:tags, Registry.top_tags(14))
     |> assign(:stats, Registry.stats())
     |> assign(:transports, Server.transports())
     |> assign(:mcp_url, McpRegistryWeb.Endpoint.url() <> "/mcp")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    q = String.trim(params["q"] || "")
    transport = blank_to_nil(params["transport"])
    tag = blank_to_nil(params["tag"])
    filters = [q: q, transport: transport, tag: tag]

    total = Registry.count_servers(filters)
    last_page = max(div(total + @per_page - 1, @per_page), 1)
    page = params["page"] |> parse_page() |> min(last_page)

    servers =
      Registry.list_servers(filters ++ [limit: @per_page, offset: (page - 1) * @per_page])

    if connected?(socket) and q != "" and page == 1 do
      Analytics.track(:search, %{results: total, path: "/"})
    end

    {:noreply,
     assign(socket,
       q: q,
       transport: transport,
       tag: tag,
       servers: servers,
       page: page,
       last_page: last_page,
       total: total,
       first_shown: if(total == 0, do: 0, else: (page - 1) * @per_page + 1),
       last_shown: min(page * @per_page, total)
     )}
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
          <b>{format_number(@stats.servers)}</b>
          Model Context Protocol servers, {format_number(@stats.remote)} of them hosted remotely.
          <span :if={@stats.official > 0}>
            Includes the whole <a
              href="https://registry.modelcontextprotocol.io"
              class="link"
              rel="noopener"
            >
              official MCP Registry
            </a>, kept in sync automatically.
          </span>
          Browse below, or <.link navigate={~p"/submit"} class="link">add one</.link>.
        </p>
      </section>

      <section id="for-agents" class="card bg-base-200">
        <div class="card-body p-4 gap-2">
          <h2 class="font-semibold">For AI agents</h2>
          <p class="text-sm text-base-content/70">
            This registry is an MCP server. Connect to it and your agent can search for servers and
            submit new ones itself, with no account. Details in <a href={~p"/llms.txt"} class="link">/llms.txt</a>.
          </p>
          <pre class="bg-base-300 rounded-box p-3 text-xs overflow-x-auto"><code>claude mcp add --transport http mcp-registry-search {@mcp_url}</code></pre>
        </div>
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

      <p :if={@total > 0} id="result-count" class="text-sm text-base-content/60">
        Showing {format_number(@first_shown)}–{format_number(@last_shown)} of {format_number(@total)} servers
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

      <nav :if={@last_page > 1} id="pagination" class="flex items-center justify-center gap-2">
        <.link
          :if={@page > 1}
          patch={index_path(@q, @transport, @tag, @page - 1)}
          class="btn btn-sm"
          rel="prev"
        >
          <.icon name="hero-arrow-left-micro" class="size-4" /> Previous
        </.link>
        <span class="text-sm text-base-content/60 px-2">
          Page {format_number(@page)} of {format_number(@last_page)}
        </span>
        <.link
          :if={@page < @last_page}
          patch={index_path(@q, @transport, @tag, @page + 1)}
          class="btn btn-sm"
          rel="next"
        >
          Next <.icon name="hero-arrow-right-micro" class="size-4" />
        </.link>
      </nav>
    </Layouts.app>
    """
  end

  defp index_path(q, transport, tag, page \\ 1) do
    params =
      [q: q, transport: transport, tag: tag, page: if(page > 1, do: page)]
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)

    ~p"/?#{params}"
  end

  defp parse_page(value) when is_binary(value) do
    case Integer.parse(value) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp format_number(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp transport_badge(transport), do: Layouts.transport_badge(transport)
end
