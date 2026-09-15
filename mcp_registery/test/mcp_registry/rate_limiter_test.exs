defmodule McpRegistry.RateLimiterTest do
  use ExUnit.Case, async: true

  alias McpRegistry.RateLimiter

  test "allows up to the limit per window, then reports when to retry" do
    key = {:test, make_ref()}
    assert :ok = RateLimiter.hit(key, 2, 3600)
    assert :ok = RateLimiter.hit(key, 2, 3600)
    assert {:error, retry_after} = RateLimiter.hit(key, 2, 3600)
    assert retry_after in 1..3600
    assert :ok = RateLimiter.hit({:test, make_ref()}, 2, 3600)
  end
end
