defmodule McpRegistryWeb.API.FallbackController do
  use McpRegistryWeb, :controller

  alias McpRegistryWeb.Submissions

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: %{
        code: "validation_failed",
        message: "The listing is invalid. Fix the fields in details and submit again.",
        details: Submissions.error_details(changeset)
      }
    })
  end

  def call(conn, {:error, :not_found}) do
    error(conn, 404, "not_found", "No server with that name.")
  end

  def call(conn, {:error, :unauthorized}) do
    error(
      conn,
      401,
      "unauthorized",
      "This needs 'Authorization: Bearer <REGISTRY_PUBLISH_TOKEN>'. To submit a server for review, send the request without an Authorization header."
    )
  end

  def call(conn, {:error, {:rate_limited, retry_after}}) do
    conn
    |> put_resp_header("retry-after", Integer.to_string(retry_after))
    |> error(
      429,
      "rate_limited",
      "Too many submissions from this client. Retry after #{retry_after} seconds."
    )
  end

  def call(conn, {:error, :queue_full}) do
    conn
    |> put_resp_header("retry-after", "3600")
    |> error(503, "queue_full", "The review queue is full. Try again later.")
  end

  def call(conn, {:error, :not_pending}) do
    error(conn, 409, "not_pending", "Only pending listings can be rejected.")
  end

  def call(conn, {:error, :bad_review}) do
    error(
      conn,
      400,
      "bad_request",
      ~s(Send {"name": "<server name>", "decision": "approve" | "reject"}.)
    )
  end

  def call(conn, {:error, :bad_status}) do
    error(conn, 400, "bad_request", "status must be active, pending or deprecated.")
  end

  defp error(conn, status, code, message) do
    conn |> put_status(status) |> json(%{error: %{code: code, message: message}})
  end
end
