defmodule McpRegistryWeb.LlmsController do
  @moduledoc "Serves /llms.txt: how an agent finds, installs and publishes servers here."
  use McpRegistryWeb, :controller

  def show(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, McpRegistryWeb.Llms.render(McpRegistryWeb.Endpoint.url()))
  end
end
