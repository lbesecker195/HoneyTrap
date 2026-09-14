defmodule McpRegistryWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use McpRegistryWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders the app layout: site header, content column, and footer.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8 border-b border-base-300">
      <div class="flex-1">
        <.link navigate={~p"/"} class="flex w-fit items-center gap-2 font-semibold text-lg">
          <.icon name="hero-cube-transparent" class="size-6 text-primary" />
          <span>MCP Registry</span>
        </.link>
      </div>
      <div class="flex-none">
        <ul class="flex px-1 gap-1 items-center">
          <li class="hidden sm:block">
            <.link navigate={~p"/"} class="btn btn-ghost btn-sm">Browse</.link>
          </li>
          <li class="hidden sm:block">
            <a href={~p"/api/v0/servers"} class="btn btn-ghost btn-sm">API</a>
          </li>
          <li class="hidden sm:block">
            <a href={~p"/llms.txt"} class="btn btn-ghost btn-sm">llms.txt</a>
          </li>
          <li class="px-2">
            <.theme_toggle />
          </li>
          <li>
            <.link navigate={~p"/submit"} class="btn btn-primary btn-sm">Submit a server</.link>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-10 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-5xl space-y-6">
        {render_slot(@inner_block)}
      </div>
    </main>

    <footer class="px-4 py-8 sm:px-6 lg:px-8 border-t border-base-300 text-sm text-base-content/70">
      <div class="mx-auto max-w-5xl flex flex-col sm:flex-row gap-2 justify-between">
        <span>An open registry of Model Context Protocol servers, built with Phoenix.</span>
        <span>
          Analytics by
          <a href="https://seriouslysimpleanalytics.com" class="link" rel="noopener">
            Seriously Simple Analytics
          </a>
          &mdash; free, unlimited, one script tag. We use it and recommend it.
        </span>
      </div>
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  @doc "daisyUI badge colour for a transport."
  def transport_badge("stdio"), do: "badge-neutral"
  def transport_badge("streamable-http"), do: "badge-info"
  def transport_badge("sse"), do: "badge-warning"
  def transport_badge(_), do: "badge-ghost"
end
