defmodule McpRegistryWeb.API.FallbackController do
  use McpRegistryWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    details =
      Ecto.Changeset.traverse_errors(changeset, &McpRegistryWeb.CoreComponents.translate_error/1)

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: %{code: "validation_failed", message: "The listing is invalid.", details: details}
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
      "Publishing requires 'Authorization: Bearer <REGISTRY_PUBLISH_TOKEN>'."
    )
  end

  def call(conn, {:error, :publishing_disabled}) do
    error(
      conn,
      403,
      "publishing_disabled",
      "API publishing is off. Set REGISTRY_PUBLISH_TOKEN, or use the /submit form."
    )
  end

  defp error(conn, status, code, message) do
    conn |> put_status(status) |> json(%{error: %{code: code, message: message}})
  end
end
