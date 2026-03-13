defmodule JobBoard.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password_hash, :string
    # Virtual field — accepted on input, never persisted directly.
    # We hash it and store it in password_hash.
    field :password, :string, virtual: true
    field :role, :string
    field :name, :string

    has_many :jobs, JobBoard.Jobs.Job
    has_many :applications, JobBoard.Applications.Application

    timestamps()
  end

  @doc """
  Changeset used when registering a new user.
  Validates required fields and hashes the password.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :role, :name])
    |> validate_required([:email, :password, :role, :name])
    |> validate_format(:email, ~r/@/, message: "must include @")
    |> validate_length(:password, min: 8, message: "must be at least 8 characters")
    |> validate_inclusion(:role, ["employer", "seeker"])
    |> unique_constraint(:email)
    |> hash_password()
  end

  # Takes the plain-text :password from the changeset, hashes it with PBKDF2,
  # stores the hash in :password_hash, then clears the plain-text field.
  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        changeset
        |> put_change(:password_hash, Pbkdf2.hash_pwd_salt(password))
        |> delete_change(:password)
    end
  end
end
