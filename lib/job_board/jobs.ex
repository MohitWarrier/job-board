defmodule JobBoard.Jobs do
  @moduledoc """
  The Jobs context.

  Handles creating, reading, updating, and deleting job listings,
  plus search and pagination (Phase 4).

  Controllers call functions here. They never query the database directly.
  """

  import Ecto.Query
  alias JobBoard.Repo
  alias JobBoard.Jobs.Job

  # ---------------------------------------------------------------------------
  # Phase 2 — CRUD
  # ---------------------------------------------------------------------------

  @doc "Returns all published jobs. TODO: add search/pagination in Phase 4."
  def list_jobs do
    # TODO Phase 4: accept a params map and filter by q, loc, min_salary, page
    Repo.all(from j in Job, where: j.status == "published", order_by: [desc: j.inserted_at])
  end

  @doc "Returns all jobs posted by the given user (employer's dashboard)."
  def list_my_jobs(user) do
    Repo.all(from j in Job, where: j.user_id == ^user.id, order_by: [desc: j.inserted_at])
  end

  @doc "Returns a single job by ID. Raises Ecto.NoResultsError if not found."
  def get_job!(id), do: Repo.get!(Job, id)

  @doc """
  Creates a new job listing owned by the given user.
  The user_id is set from the authenticated user — not from the request params.
  """
  def create_job(user, attrs) do
    %Job{user_id: user.id}
    |> Job.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates an existing job. Caller is responsible for checking ownership."
  def update_job(job, attrs) do
    job
    |> Job.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a job. Caller is responsible for checking ownership."
  def delete_job(job) do
    Repo.delete(job)
  end

  # ---------------------------------------------------------------------------
  # Phase 4 — Search and Pagination (TODO)
  # ---------------------------------------------------------------------------

  @doc """
  Searches published jobs with optional filters.

  ## Params (all optional)
  - `"q"` — keyword search on title (case-insensitive)
  - `"loc"` — filter by location (case-insensitive)
  - `"min_salary"` — minimum salary (integer)
  - `"page"` — page number, default 1 (20 results per page)

  TODO: implement this in Phase 4.
  """
  def search_jobs(_params) do
    # TODO Phase 4:
    # 1. Start with a base query: from j in Job, where: j.status == "published"
    # 2. Pipe through filter functions for each param
    # 3. Add limit(20) and offset((page - 1) * 20)
    list_jobs()
  end
end
