defmodule JobBoard.Repo.Migrations.CreateApplications do
  use Ecto.Migration

  def change do
    create table(:applications) do
      add :job_id, references(:jobs, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :cover_letter, :text
      # "pending" | "reviewed" | "rejected" | "accepted"
      add :status, :string, null: false, default: "pending"

      timestamps()
    end

    create index(:applications, [:job_id])
    create index(:applications, [:user_id])
    # Prevents a seeker from applying to the same job twice
    create unique_index(:applications, [:job_id, :user_id])
  end
end
