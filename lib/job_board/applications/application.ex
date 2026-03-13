defmodule JobBoard.Applications.Application do
  use Ecto.Schema
  import Ecto.Changeset

  schema "applications" do
    field :cover_letter, :string
    field :status, :string, default: "pending"

    belongs_to :job, JobBoard.Jobs.Job
    belongs_to :user, JobBoard.Accounts.User

    timestamps()
  end

  @valid_statuses ["pending", "reviewed", "rejected", "accepted"]

  def changeset(application, attrs) do
    application
    |> cast(attrs, [:cover_letter, :status])
    |> validate_inclusion(:status, @valid_statuses)
    # This maps to the unique_index(:applications, [:job_id, :user_id]) in the migration.
    # When a duplicate insert hits the DB constraint, Ecto returns a readable error
    # instead of crashing.
    |> unique_constraint([:job_id, :user_id],
      message: "you have already applied for this job"
    )
  end
end
