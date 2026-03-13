defmodule JobBoardWeb.AuthPlug do
  @moduledoc """
  Phoenix plug that authenticates requests using a JWT token.

  Reads the `Authorization: Bearer <token>` header, verifies the token,
  loads the user from the database, and assigns them to `conn.assigns.current_user`.

  If the token is missing or invalid, it halts the connection and returns 401.

  ## Usage in router.ex

      pipeline :authenticated do
        plug JobBoardWeb.AuthPlug
      end

  Any route inside an `authenticated` pipeline will require a valid token.
  Controllers access the user via `conn.assigns.current_user`.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias JobBoard.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user_id} <- Accounts.verify_token(token),
         user when not is_nil(user) <- Accounts.get_user(user_id) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "missing or invalid token"})
        |> halt()
    end
  end
end
