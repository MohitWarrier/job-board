defmodule JobBoardWeb.AuthController do
  use JobBoardWeb, :controller

  require Logger

  alias JobBoard.Accounts

  @doc """
  POST /api/register

  Creates a new user account. Accepts JSON body:
    { "email", "password", "name", "role" }

  Returns 201 with user data on success.
  Returns 422 with validation errors on failure.
  """
  def register(conn, params) do

    case Accounts.register_user(params) do
      {:ok, user} ->
        Logger.info("[AUTH] Registration SUCCESS — email=#{user.email} role=#{user.role} id=#{user.id}")

        conn
        |> put_status(:created)
        |> json(%{
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role
        })

      {:error, changeset} ->
        errors = format_errors(changeset)
        Logger.warning("[AUTH] Registration FAILED — errors=#{inspect(errors)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors})
    end
  end

  @doc """
  POST /api/login

  Authenticates a user and returns a JWT token.
  Accepts JSON body: { "email", "password" }

  Returns 200 with { "token": "..." } on success.
  Returns 401 on invalid credentials.
  """
  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.login(email, password) do
      {:ok, token} ->
        Logger.info("[AUTH] Login SUCCESS — email=#{email}")
        json(conn, %{token: token})

      {:error, :invalid_credentials} ->
        Logger.warning("[AUTH] Login FAILED — email=#{email} reason=invalid_credentials")

        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid email or password"})
    end
  end

  def login(conn, _params) do
    Logger.warning("[AUTH] Login FAILED — reason=missing_email_or_password")

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "email and password are required"})
  end

  # Converts an Ecto changeset's errors into a plain map for JSON responses.
  # e.g. %{email: ["has already been taken"], password: ["is too short"]}
  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
