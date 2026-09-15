defmodule McpRegistryWeb.Plugs.ClientIP do
  @moduledoc """
  Sets `conn.remote_ip` from nginx's `X-Real-IP` header, so rate limits apply
  per real client. The header is trusted only when the request itself came
  from loopback: in production the app listens on 127.0.0.1 behind nginx, so
  nobody else can reach it to forge the header.
  """
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{remote_ip: peer} = conn, _opts) do
    with true <- loopback?(peer),
         [value | _] <- Plug.Conn.get_req_header(conn, "x-real-ip"),
         {:ok, ip} <- value |> String.trim() |> String.to_charlist() |> :inet.parse_address() do
      %{conn | remote_ip: ip}
    else
      _ -> conn
    end
  end

  defp loopback?({127, _, _, _}), do: true
  defp loopback?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp loopback?({0, 0, 0, 0, 0, 0xFFFF, high, _}) when high in 0x7F00..0x7FFF, do: true
  defp loopback?(_), do: false
end
