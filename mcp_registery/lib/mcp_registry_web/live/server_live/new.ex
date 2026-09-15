defmodule McpRegistryWeb.ServerLive.New do
  use McpRegistryWeb, :live_view

  alias McpRegistry.Registry
  alias McpRegistry.Registry.Server

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Submit a server",
       form: to_form(Registry.change_server(%Server{})),
       transports: Server.transports(),
       registries: Server.registries()
     )}
  end

  @impl true
  def handle_event("validate", %{"server" => params}, socket) do
    changeset = Registry.change_server(%Server{}, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"server" => params}, socket) do
    case Registry.create_server(params, status: "pending", source: "web") do
      {:ok, server} ->
        {:noreply,
         socket
         |> put_flash(:info, "Thanks! #{server.name} is submitted and pending review.")
         |> push_navigate(to: server_path(server))}

      {:error, :queue_full} ->
        {:noreply,
         put_flash(socket, :error, "The review queue is full right now. Please try again later.")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Submit an MCP server
        <:subtitle>
          Listings appear in search after a quick review. AI agents can submit on their own through
          the MCP endpoint at <code>/mcp</code>
          or <code>POST /api/v0/servers</code>; see <a href={~p"/llms.txt"} class="link">llms.txt</a>.
        </:subtitle>
      </.header>

      <.form for={@form} id="server-form" phx-change="validate" phx-submit="save" class="space-y-4">
        <div class="grid sm:grid-cols-2 gap-4">
          <.input field={@form[:name]} label="Name" placeholder="io.github.acme/weather" />
          <.input field={@form[:title]} label="Title" placeholder="Weather" />
        </div>
        <.input
          field={@form[:description]}
          type="textarea"
          label="Description"
          placeholder="What the server does and what it needs to run."
        />
        <div class="grid sm:grid-cols-2 gap-4">
          <.input field={@form[:version]} label="Version" />
          <.input field={@form[:transport]} type="select" label="Transport" options={@transports} />
        </div>
        <.input
          field={@form[:remote_url]}
          label="Remote URL (streamable-http / sse servers)"
          placeholder="https://mcp.example.com/mcp"
        />
        <div class="grid sm:grid-cols-2 gap-4">
          <.input
            field={@form[:package_registry]}
            type="select"
            label="Package registry (stdio servers)"
            prompt="none"
            options={@registries}
          />
          <.input
            field={@form[:package_identifier]}
            label="Package identifier"
            placeholder="@acme/weather-mcp"
          />
        </div>
        <.input
          name="server[env_vars]"
          value={list_value(@form[:env_vars])}
          errors={list_errors(@form[:env_vars])}
          label="Environment variables the server needs (comma-separated)"
          placeholder="WEATHER_API_KEY"
        />
        <.input
          name="server[tools]"
          value={list_value(@form[:tools])}
          errors={list_errors(@form[:tools])}
          label="Tool names it exposes (comma-separated)"
          placeholder="get_forecast, get_alerts"
        />
        <.input
          name="server[tags]"
          value={list_value(@form[:tags])}
          errors={list_errors(@form[:tags])}
          label="Tags (comma-separated, up to 12)"
          placeholder="weather, data"
        />
        <div class="grid sm:grid-cols-3 gap-4">
          <.input field={@form[:repository_url]} label="Repository URL" />
          <.input field={@form[:website_url]} label="Website URL" />
          <.input field={@form[:license]} label="License" placeholder="MIT" />
        </div>
        <.button variant="primary" phx-disable-with="Submitting…">Submit for review</.button>
      </.form>
    </Layouts.app>
    """
  end

  # List fields are edited as comma-separated text but stored as arrays.
  defp list_value(%Phoenix.HTML.FormField{value: value}) do
    value |> List.wrap() |> Enum.join(", ")
  end

  defp list_errors(%Phoenix.HTML.FormField{} = field) do
    if used_input?(field), do: Enum.map(field.errors, &translate_error/1), else: []
  end
end
