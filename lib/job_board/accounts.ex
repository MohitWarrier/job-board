defmodule JobBoard.Accounts do
  @moduledoc """
  The Accounts context handles everything related to users:
  registration, login, and looking up users.

  This module is the only public interface for user data.
  Controllers and other contexts call functions here —
  they never touch the User schema directly.
  """

  alias JobBoard.Repo
  alias JobBoard.Accounts.User

  @doc """
  Registers a new user.

  ## Examples

      iex> register_user(%{email: "a@b.com", password: "secret123", role: "seeker", name: "Alice"})
      {:ok, %User{}}

      iex> register_user(%{email: "bad"})
      {:error, %Ecto.Changeset{}}
  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Logs in a user with email and password.

  Returns `{:ok, token}` on success, `{:error, :invalid_credentials}` otherwise.
  The token is a signed JWT the client must include in the Authorization header.
  """
  def login(email, password) do
    user = Repo.get_by(User, email: email)

    cond do
      # Pbkdf2.verify_pass/2 checks the plain password against the stored hash.
      # We always call verify_pass (even if user is nil, using a dummy hash)
      # to prevent timing attacks that could reveal whether an email exists.
      user && Pbkdf2.verify_pass(password, user.password_hash) ->
        {:ok, generate_token(user)}

      user ->
        {:error, :invalid_credentials}

      true ->
        # No user found — still run a dummy hash check to keep timing consistent
        Pbkdf2.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Looks up a user by ID. Returns nil if not found.
  Used by the AuthPlug after verifying a JWT token.
  """
  def get_user(id), do: Repo.get(User, id)

  # --- JWT helpers ---

  # The secret key used to sign tokens. In production this must be an
  # environment variable (long random string), not hardcoded.
  @jwt_secret Application.compile_env(:job_board, :jwt_secret, "dev_secret_change_in_prod")

  @doc """
  Generates a signed JWT token containing the user's ID.
  The token expires after 24 hours.
  """
  def generate_token(user) do
    claims = %{
      "sub" => to_string(user.id),
      "exp" => DateTime.to_unix(DateTime.utc_now()) + 86_400
    }

    signer = Joken.Signer.create("HS256", @jwt_secret)
    {:ok, token, _} = Joken.encode_and_sign(claims, signer)
    token
  end

  @doc """
  Verifies a JWT token and returns the user ID if valid.

  Returns `{:ok, user_id}` or `{:error, reason}`.
  """
  def verify_token(token) do
    signer = Joken.Signer.create("HS256", @jwt_secret)

    case Joken.verify_and_validate(%{}, token, signer) do
      {:ok, %{"sub" => user_id, "exp" => exp}} ->
        if DateTime.to_unix(DateTime.utc_now()) < exp do
          {:ok, String.to_integer(user_id)}
        else
          {:error, :token_expired}
        end

      _ ->
        {:error, :invalid_token}
    end
  end
end
