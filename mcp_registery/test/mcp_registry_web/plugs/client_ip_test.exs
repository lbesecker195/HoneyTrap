defmodule McpRegistryWeb.Plugs.ClientIPTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias McpRegistryWeb.Plugs.ClientIP

  defp run(peer, header) do
    conn = conn(:get, "/") |> Map.put(:remote_ip, peer)
    conn = if header, do: put_req_header(conn, "x-real-ip", header), else: conn
    ClientIP.call(conn, [])
  end

  test "trusts X-Real-IP only from loopback" do
    assert run({127, 0, 0, 1}, "203.0.113.9").remote_ip == {203, 0, 113, 9}

    assert run({0, 0, 0, 0, 0, 0, 0, 1}, "2001:db8::1").remote_ip ==
             {8193, 3512, 0, 0, 0, 0, 0, 1}

    assert run({198, 51, 100, 7}, "203.0.113.9").remote_ip == {198, 51, 100, 7}
    assert run({127, 0, 0, 1}, "not an ip").remote_ip == {127, 0, 0, 1}
    assert run({127, 0, 0, 1}, nil).remote_ip == {127, 0, 0, 1}
  end
end
