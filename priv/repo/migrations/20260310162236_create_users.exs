defmodule JobBoard.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :role, :string, null: false
      add :name, :string, null: false

      timestamps()
    end

    # Unique index on email — two users can't share the same email
    create unique_index(:users, [:email])
  end
end
