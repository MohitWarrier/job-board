defmodule JobBoard.Applications do
  @moduledoc """
  The Applications context.

  Handles applying for jobs and listing applications.
  Phase 5 adds Oban job enqueueing after a successful application.
  """

  import Ecto.Query
  alias JobBoard.Repo
  alias JobBoard.Applications.Application
  alias JobBoard.Jobs

  # ---------------------------------------------------------------------------
  # Phase 3 — Apply and List
  # ---------------------------------------------------------------------------

  @doc """
  Creates an application for a job by the given user.

  Prevents duplicate applications using the unique DB constraint on
  (job_id, user_id). If the seeker has already applied, the changeset
  will return a readable error.

  TODO Phase 5: enqueue EmailWorker after successful insert.
  """
  def apply(user, job_id, attrs \\ %{}) do
    job = Jobs.get_job!(job_id)

    %Application{job_id: job.id, user_id: user.id}
    |> Application.changeset(attrs)
    |> Repo.insert()

    # TODO Phase 5: after {:ok, application}, enqueue email:
    # |> tap(fn
    #   {:ok, application} -> enqueue_confirmation_email(application)
    #   _ -> :ok
    # end)
  end

  @doc "Returns all applications submitted by the given user, with jobs preloaded."
  def list_my_applications(user) do
    Repo.all(
      from a in Application,
        where: a.user_id == ^user.id,
        preload: [:job],
        order_by: [desc: a.inserted_at]
    )
  end

  @doc "Returns all applications for a given job (employer view), with users preloaded."
  def list_for_job(job) do
    Repo.all(
      from a in Application,
        where: a.job_id == ^job.id,
        preload: [:user],
        order_by: [desc: a.inserted_at]
    )
  end

  # ---------------------------------------------------------------------------
  # Phase 5 — Background email (TODO)
  # ---------------------------------------------------------------------------

  # TODO Phase 5: implement this function
  # defp enqueue_confirmation_email(application) do
  #   %{user_id: application.user_id, job_id: application.job_id, type: "application_confirmation"}
  #   |> JobBoard.Workers.EmailWorker.new()
  #   |> Oban.insert()
  # end
end
