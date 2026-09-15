defmodule McpRegistry.Registry.Install do
  @moduledoc "Turns a listing into copy-pasteable install snippets for common clients."
  alias McpRegistry.Registry.Server

  @doc "The local command that runs a packaged server, or nil for remote-only listings."
  def command(%Server{package_registry: "npm", package_identifier: id}), do: {"npx", ["-y", id]}
  def command(%Server{package_registry: "pypi", package_identifier: id}), do: {"uvx", [id]}

  def command(%Server{package_registry: "oci", package_identifier: id}),
    do: {"docker", ["run", "-i", "--rm", id]}

  def command(%Server{package_registry: "nuget", package_identifier: id}),
    do: {"dnx", [id, "--yes"]}

  def command(_), do: nil

  @doc "A list of `%{label, lang, code}` snippets for the server."
  def snippets(%Server{} = server) do
    short = Server.short_name(server)
    Enum.reject([claude_code(server, short), mcp_servers_json(server, short)], &is_nil/1)
  end

  defp claude_code(%Server{transport: transport, remote_url: url}, short)
       when transport in ["streamable-http", "sse"] do
    kind = if transport == "sse", do: "sse", else: "http"

    %{
      label: "Claude Code",
      lang: "bash",
      code: "claude mcp add --transport #{kind} #{short} #{url}"
    }
  end

  defp claude_code(server, short) do
    case command(server) do
      {cmd, args} ->
        %{
          label: "Claude Code",
          lang: "bash",
          code: "claude mcp add #{short}#{env_flags(server)} -- #{cmd} #{Enum.join(args, " ")}"
        }

      nil ->
        nil
    end
  end

  defp env_flags(%Server{env_vars: vars}), do: Enum.map_join(vars, "", &" -e #{&1}=<#{&1}>")

  defp mcp_servers_json(server, short) do
    entry =
      cond do
        Server.remote?(server) ->
          Jason.OrderedObject.new([
            {"type", if(server.transport == "sse", do: "sse", else: "http")},
            {"url", server.remote_url}
          ])

        true ->
          case command(server) do
            {cmd, args} ->
              [{"command", cmd}, {"args", args}]
              |> maybe_env(server)
              |> Jason.OrderedObject.new()

            nil ->
              nil
          end
      end

    if entry do
      %{
        label: "mcpServers JSON (Claude Desktop, Cursor, Windsurf, VS Code)",
        lang: "json",
        code: Jason.encode!(%{"mcpServers" => %{short => entry}}, pretty: true)
      }
    end
  end

  defp maybe_env(pairs, %Server{env_vars: []}), do: pairs

  defp maybe_env(pairs, %Server{env_vars: vars}) do
    pairs ++ [{"env", Map.new(vars, &{&1, "<#{&1}>"})}]
  end
end
