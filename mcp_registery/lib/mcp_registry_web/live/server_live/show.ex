defmodule McpRegistryWeb.ServerLive.Show do
  use McpRegistryWeb, :live_view

  alias McpRegistry.Registry
  alias McpRegistry.Registry.{Install, Manifest, Server}

  @impl true
  def mount(%{"name" => segments}, _session, socket) do
    server = Registry.get_server!(Enum.join(segments, "/"))

    {:ok,
     assign(socket,
       page_title: server.title,
       server: server,
       short_name: Server.short_name(server),
       snippets: Install.snippets(server),
       manifest: Jason.encode!(Manifest.to_map(server), pretty: true)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="breadcrumbs text-sm">
        <ul>
          <li><.link navigate={~p"/"}>Servers</.link></li>
          <li class="font-mono">{@server.name}</li>
        </ul>
      </div>

      <div :if={@server.status != "active"} class="alert alert-warning">
        <.icon name="hero-clock" class="size-5" />
        <span>
          This listing is <b>{@server.status}</b>
          and is not shown in search results{if @server.status ==
                                                  "pending",
                                                do: " until a maintainer approves it"}.
        </span>
      </div>

      <.header>
        {@server.title}
        <:subtitle>
          <span class="font-mono">{@server.name}</span> &middot; v{@server.version}
        </:subtitle>
        <:actions>
          <span class={["badge", Layouts.transport_badge(@server.transport)]}>{@server.transport}</span>
        </:actions>
      </.header>

      <p class="text-base leading-relaxed">{@server.description}</p>

      <div :if={@server.tags != []} class="flex flex-wrap gap-2">
        <.link :for={tag <- @server.tags} navigate={~p"/?tag=#{tag}"} class="badge badge-ghost">
          {tag}
        </.link>
      </div>

      <section class="grid gap-8 md:grid-cols-[3fr_2fr]">
        <div class="space-y-6">
          <div :for={snippet <- @snippets} class="space-y-2">
            <h3 class="font-semibold">{snippet.label}</h3>
            <pre class="bg-base-300 rounded-box p-4 text-xs overflow-x-auto"><code>{snippet.code}</code></pre>
          </div>

          <div :if={@server.tools != []} class="space-y-2">
            <h3 class="font-semibold">Tools ({length(@server.tools)})</h3>
            <div class="flex flex-wrap gap-1">
              <code :for={tool <- @server.tools} class="badge badge-outline font-mono">{tool}</code>
            </div>
          </div>

          <details class="collapse collapse-arrow bg-base-200">
            <summary class="collapse-title font-semibold">server.json manifest</summary>
            <div class="collapse-content">
              <pre class="text-xs overflow-x-auto"><code>{@manifest}</code></pre>
            </div>
          </details>
        </div>

        <aside>
          <.list>
            <:item title="Transport">{@server.transport}</:item>
            <:item :if={@server.remote_url} title="Endpoint">
              <a href={@server.remote_url} class="link break-all" rel="noopener">{@server.remote_url}</a>
            </:item>
            <:item :if={@server.package_identifier} title="Package">
              {@server.package_registry}: <code>{@server.package_identifier}</code>
            </:item>
            <:item :if={@server.env_vars != []} title="Environment">
              <code :for={var <- @server.env_vars} class="block">{var}</code>
            </:item>
            <:item :if={@server.repository_url} title="Repository">
              <a href={@server.repository_url} class="link break-all" rel="noopener">
                {@server.repository_url}
              </a>
            </:item>
            <:item :if={@server.website_url} title="Website">
              <a href={@server.website_url} class="link break-all" rel="noopener">
                {@server.website_url}
              </a>
            </:item>
            <:item :if={@server.license} title="License">{@server.license}</:item>
            <:item title="API">
              <a href={api_server_path(@server)} class="link font-mono text-xs break-all">
                {api_server_path(@server)}
              </a>
            </:item>
          </.list>
        </aside>
      </section>
    </Layouts.app>
    """
  end
end
