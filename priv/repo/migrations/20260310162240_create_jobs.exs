defmodule JobBoard.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :text, null: false
      add :location, :string
      add :salary, :integer
      # "draft" | "published" | "closed"
      add :status, :string, null: false, default: "draft"

      timestamps()
    end

    create index(:jobs, [:user_id])
    create index(:jobs, [:status])
  end
end
