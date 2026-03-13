defmodule JobBoard.Jobs.Job do
  use Ecto.Schema
  import Ecto.Changeset

  schema "jobs" do
    field :title, :string
    field :description, :string
    field :location, :string
    field :salary, :integer
    field :status, :string, default: "draft"

    belongs_to :user, JobBoard.Accounts.User
    has_many :applications, JobBoard.Applications.Application

    timestamps()
  end

  @valid_statuses ["draft", "published", "closed"]

  def changeset(job, attrs) do
    job
    |> cast(attrs, [:title, :description, :location, :salary, :status])
    |> validate_required([:title, :description])
    |> validate_length(:title, min: 5, max: 200)
    |> validate_number(:salary, greater_than: 0)
    |> validate_inclusion(:status, @valid_statuses)
  end
end
